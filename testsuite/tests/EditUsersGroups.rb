# encoding: utf-8

# File:	EditUsersGroups.ycp
# Module:	Users configurator
# Summary:	Testing adding and removing user from groups (see bug #136267)
# Author:	Jiri Suchomel <jsuchome@suse.cz>
# $Id$
module Yast
  class EditUsersGroupsClient < Client
    def main
      # testedfiles: Users.pm UsersLDAP.pm UsersRoutines.pm UsersSimple.pm

      Yast.import "Directory"
      Yast.import "Mode"
      Yast.import "Users"

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
              "expire" => nil,
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
        "target" => { "bash" => 0, "bash_output" => { "stdout" => "" } }
      }

      Yast.import "Testsuite"

      Mode.SetTest("test")

      Testsuite.Test(lambda { Users.Read }, [@READ, @WRITE, @EXEC], 0)

      @group = {
        "gidNumber" => 555,
        "cn"        => "ggl",
        "userlist"  => { "hh" => 1 },
        "password"  => "x",
        "type"      => "local",
        "what"      => "add_group"
      }

      Testsuite.Test(lambda { Users.AddGroup(@group) }, [@READ, @WRITE, @EXEC], 0)

      Ops.set(@EXEC, ["target", "bash_output", "stdout"], "ggl")

      Testsuite.Test(lambda { Users.CheckGroup({}) }, [@READ, @WRITE, @EXEC], 0)

      Testsuite.Test(lambda { Users.CommitGroup }, [@READ, @WRITE, @EXEC], 0)

      # for home directory checks
      Ops.set(@READ, ["target", "stat", "isdir"], true)

      Users.SelectUserByName("hh")

      @changes = { "grouplist" => { "audio" => 1 } }

      Testsuite.Test(lambda { Users.EditUser(@changes) }, [@READ, @WRITE, @EXEC], 0)

      Ops.set(@EXEC, ["target", "bash_output", "stdout"], "hh")

      @error = Convert.to_string(
        Testsuite.Test(lambda { Users.CheckUser({}) }, [@READ, @WRITE, @EXEC], 0)
      )

      Testsuite.Dump(
        Builtins.sformat(
          "---- unchanged group 'ggl':\n %1",
          Users.GetGroupByName("ggl", "")
        )
      )

      Testsuite.Dump(
        Builtins.sformat(
          "---- unchanged group 'audio':\n %1",
          Users.GetGroupByName("audio", "")
        )
      )

      Testsuite.Test(lambda { Users.CommitUser }, [@READ, @WRITE, @EXEC], 0)

      Testsuite.Dump(
        Builtins.sformat(
          "---- changed group 'ggl':\n %1",
          Users.GetGroupByName("ggl", "")
        )
      )

      Testsuite.Dump(
        Builtins.sformat(
          "---- changed group 'audio':\n %1",
          Users.GetGroupByName("audio", "")
        )
      )

      nil
    end
  end
end

Yast::EditUsersGroupsClient.new.main
