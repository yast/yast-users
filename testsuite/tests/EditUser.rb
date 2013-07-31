# encoding: utf-8

# File		: EditUser.ycp
# Module	: Users configurator
# Summary	: Test of Users::EditUser function
# Author	: Jiri Suchomel <jsuchome@suse.cz>
#
# $Id$
module Yast
  class EditUserClient < Client
    def main
      # testedfiles: Users.pm UsersPasswd.pm UsersLDAP.pm UsersRoutines.pm UsersSimple.pm

      Yast.import "Directory"
      Yast.import "Mode"
      Yast.import "Users"
      Yast.import "UsersPasswd"

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
        "anyxml"  => nil
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

      Testsuite.Dump(
        Builtins.sformat("---- user 'hh':\n %1", Users.GetCurrentUser)
      )

      @changes = { "uidNumber" => 501 }

      Testsuite.Test(lambda { Users.EditUser(@changes) }, [@READ, @WRITE, @EXEC], 0)

      Testsuite.Dump(
        Builtins.sformat("---- user 'hh':\n %1", Users.GetCurrentUser)
      )

      Ops.set(@EXEC, ["target", "bash_output", "stdout"], "hh")

      @error = Convert.to_string(
        Testsuite.Test(lambda { Users.CheckUser({}) }, [@READ, @WRITE, @EXEC], 0)
      )
      Testsuite.Dump(
        Builtins.sformat("---- check user after edit:\n %1", @error)
      )

      Testsuite.Dump("---- commit user:")
      Testsuite.Test(lambda { Users.CommitUser }, [@READ, @WRITE, @EXEC], 0)

      Testsuite.Test(lambda { Users.SetBaseDirectory("/etc") }, [], 0)
      Testsuite.Test(lambda { UsersPasswd.SetBaseDirectory("/etc") }, [], 0)

      # home changed its owner because of uid change
      Testsuite.Test(lambda { Users.Write }, [@RW, @WRITE, @EXEC], 0)

      Testsuite.Test(lambda { Users.SelectUser(500) }, [], 0)
      Testsuite.Dump(
        Builtins.sformat("---- user 500:\n %1", Users.GetCurrentUser)
      )

      Testsuite.Test(lambda { Users.SelectUser(501) }, [], 0)
      Testsuite.Dump(
        Builtins.sformat("---- user 501:\n %1", Users.GetCurrentUser)
      )

      @changes = { "homeDirectory" => "/new/home/hh" }

      Testsuite.Test(lambda { Users.EditUser(@changes) }, [@READ, @WRITE, @EXEC], 0)

      Testsuite.Dump(
        Builtins.sformat("---- user 'hh':\n %1", Users.GetCurrentUser)
      )

      @error = Convert.to_string(
        Testsuite.Test(lambda { Users.CheckUser({}) }, [@READ, @WRITE, @EXEC], 0)
      )
      Testsuite.Dump(
        Builtins.sformat("---- check user after edit:\n %1", @error)
      )

      Testsuite.Dump("---- commit user:")
      Testsuite.Test(lambda { Users.CommitUser }, [@READ, @WRITE, @EXEC], 0)

      # home directory was changed -> move it
      Ops.set(@READ, ["target", "stat"], {})

      Testsuite.Test(lambda { Users.Write }, [@READ, @WRITE, @EXEC], 0)

      Testsuite.Dump(
        "=========================================================="
      )

      nil
    end
  end
end

Yast::EditUserClient.new.main
