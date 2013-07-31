# encoding: utf-8

# File:
#  DeleteUserCryptedDir.ycp
#
# Module:
#  Users configurator
#
# Summary:
#  Deleting user with encrypted directory
#
# Authors:
#  Jiri Suchomel <jsuchome@suse.cz>
#
module Yast
  class DeleteUserCryptedDirClient < Client
    def main
      # testedfiles: Users.pm UsersPasswd.pm UsersLDAP.pm UsersRoutines.pm

      Yast.import "Users"
      Yast.import "UsersPasswd"
      Yast.import "Mode"
      Yast.import "Directory"
      Yast.import "Progress"
      Yast.import "Report"

      @tmpdir = Directory.tmpdir
      Builtins.foreach(["passwd", "group", "shadow"]) do |file|
        cmd = Builtins.sformat("/bin/cp ./%1 %2/", file, @tmpdir)
        SCR.Execute(path(".target.bash_output"), cmd)
      end
      Users.SetBaseDirectory(@tmpdir)
      Users.ReadLocal

      @READ = {
        "etc"     => {
          "fstab"     => [],
          "cryptotab" => [],
          "default"   => {
            "useradd" => {
              "home"   => "/home",
              "groups" => "audio,video",
              "group"  => 100
            }
          }
        },
        "product" => {
          "features" => {
            "USE_DESKTOP_SCHEDULER"           => "no",
            "IO_SCHEDULER"                    => "",
            "ENABLE_AUTOLOGIN"                => "false",
            "UI_MODE"                         => "simple",
            "EVMS_CONFIG"                     => "no",
            "INCOMPLETE_TRANSLATION_TRESHOLD" => "99"
          }
        },
        "target"  => { "size" => -1, "stat" => {} }
      }

      @WRITE = {}
      @EXEC = {
        "passwd" => { "init" => true },
        "target" => { "bash" => 0, "bash_output" => { "exit" => 0 } }
      }
      @RW = {
        "target" => {
          "stat"   => { "isdir" => true },
          "size"   => -1,
          "tmpdir" => "/tmp/YaST"
        },
        "anyxml" => {
          "pam_mount" => [
            {
              "volume" => [
                {
                  "user"      => "hh",
                  "path"      => "/home/hh.img",
                  "fskeypath" => "/home/hh.key"
                }
              ]
            }
          ]
        }
      }

      Yast.import "Testsuite"

      Mode.SetTest("test")

      Testsuite.Test(lambda { Users.Read }, [@READ, @WRITE, @EXEC], 0)

      Testsuite.Test(lambda { Users.SelectUserByName("hh") }, [], 0)

      Testsuite.Dump(
        Builtins.sformat("---- user 'hh':\n %1", Users.GetCurrentUser)
      )

      Testsuite.Dump(
        "==================== running delete ======================"
      )

      Testsuite.Test(lambda { Users.DeleteUser(true) }, [@READ], 0)
      Testsuite.Test(lambda { Users.CommitUser }, [@READ], 0)

      Testsuite.Test(lambda { Users.SetBaseDirectory("/etc") }, [], 0)
      Testsuite.Test(lambda { UsersPasswd.SetBaseDirectory("/etc") }, [], 0)
      Testsuite.Test(lambda { Directory.ResetTmpDir }, [@RW, @WRITE, @EXEC], 0)

      Testsuite.Test(lambda { Users.Write }, [@RW, @WRITE, @EXEC], 0)

      nil
    end
  end
end

Yast::DeleteUserCryptedDirClient.new.main
