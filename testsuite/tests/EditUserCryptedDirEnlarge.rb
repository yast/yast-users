# encoding: utf-8

# File		: EditUserCryptedDir.ycp
# Module	: Users configurator
# Summary	: Test of Users::EditUser function
# Author	: Jiri Suchomel <jsuchome@suse.cz>
#
# $Id$
module Yast
  class EditUserCryptedDirEnlargeClient < Client
    def main
      # testedfiles: Users.pm UsersPasswd.pm UsersLDAP.pm UsersRoutines.pm

      Yast.import "Directory"
      Yast.import "Mode"
      Yast.import "Users"
      Yast.import "UsersPasswd"
      Yast.import "UsersRoutines"

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
        "target"  => { "stat" => {}, "size" => -1, "tmpdir" => "/tmp/YaST" },
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
        "anyxml"  => {
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
      @WRITE = {}
      @EXEC = {
        "passwd" => { "init" => true },
        "target" => { "bash" => 0, "bash_output" => {} }
      }
      @RW = {
        "target" => {
          "stat"   => { "isdir" => true },
          "size"   => -1,
          "tmpdir" => "/tmp/YaST"
        }
      }

      Yast.import "Testsuite"

      Testsuite.Dump(
        "=========================================================="
      )

      Mode.SetTest("test")

      Testsuite.Test(lambda { Users.Read }, [@READ, @WRITE, @EXEC], 0)

      # for home directory checks
      Ops.set(@READ, ["target", "stat", "isdir"], true)

      Testsuite.Test(lambda { Users.SelectUserByName("hh") }, [], 0)

      @changes = {
        "crypted_home_size"         => 200,
        "current_text_userpassword" => "password"
      } # needed for cryptconfig

      # img.file size
      Ops.set(@READ, ["target", "stat", "size"], 100 * 1024 * 1024)


      Testsuite.Test(lambda { Users.EditUser(@changes) }, [@READ, @WRITE, @EXEC], 0)

      Testsuite.Dump(
        Builtins.sformat("---- user 'hh':\n %1", Users.GetCurrentUser)
      )

      Testsuite.Dump("---- commit user:")
      Testsuite.Test(lambda { Users.CommitUser }, [@READ, @WRITE, @EXEC], 0)

      Testsuite.Test(lambda { Users.SetBaseDirectory("/etc") }, [], 0)
      Testsuite.Test(lambda { UsersPasswd.SetBaseDirectory("/etc") }, [], 0)

      Testsuite.Test(lambda { Directory.ResetTmpDir }, [@RW, @WRITE, @EXEC], 0)
      Testsuite.Test(lambda { Users.Write }, [@RW, @WRITE, @EXEC], 0)

      nil
    end
  end
end

Yast::EditUserCryptedDirEnlargeClient.new.main
