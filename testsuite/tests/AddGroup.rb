# encoding: utf-8

# File:
#  AddGroup.ycp
#
# Module:
#  Users configurator
#
# Summary:
#  Saving group tests.
#
# Authors:
#  Jiri Suchomel <jsuchome@suse.cz>
#
module Yast
  class AddGroupClient < Client
    def main
      # testedfiles: Users.pm UsersLDAP.pm

      Yast.import "Directory"
      Yast.import "Users"
      Yast.import "UsersCache"
      Yast.import "Mode"
      Yast.import "Progress"
      Yast.import "Report"

      # we need to read the real data from the system, not given in map for
      # dummy agent
      @tmpdir = Directory.tmpdir
      Builtins.foreach(["passwd", "group", "shadow"]) do |file|
        cmd = Builtins.sformat("/bin/cp ./%1 %2/", file, @tmpdir)
        SCR.Execute(path(".target.bash_output"), cmd)
      end
      Users.SetBaseDirectory(@tmpdir)
      Users.ReadLocal
      # passwd etc. read, now we can switch to the test mode

      @READ =
        # To simulate NIS server, use target.size = 0 and this:
        # "sysconfig": $[
        #     "ypserv" : $[
        # 	"YPPWD_SRCDIR"	: "/etc"
        #     ]
        # ],
        {
          "product" => {
            "features" => {
              "USE_DESKTOP_SCHEDULER"           => "no",
              "ENABLE_AUTOLOGIN"                => "false",
              "IO_SCHEDULER"                    => "",
              "EVMS_CONFIG"                     => "no",
              "UI_MODE"                         => "simple",
              "INCOMPLETE_TRANSLATION_TRESHOLD" => "99"
            }
          },
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
          "target"  => { "size" => -1, "stat" => {} }
        }

      @WRITE = {}
      @EXEC = {
        "passwd" => { "init" => true },
        "target" => { "bash" => 0, "bash_output" => { "stdout" => "" } }
      }

      Mode.SetTest("test")

      Yast.import "Testsuite"

      Testsuite.Dump(
        "=========================================================="
      )
      Testsuite.Test(lambda { Users.Read }, [@READ, @WRITE, @EXEC], 0)

      Testsuite.Dump(
        Builtins.sformat(
          "local user names:\n %1",
          UsersCache.GetUsernames("local")
        )
      )
      Testsuite.Dump(
        Builtins.sformat(
          "local group names:\n %1",
          UsersCache.GetGroupnames("local")
        )
      )
      Testsuite.Dump(
        Builtins.sformat("---- current group:\n %1", Users.GetCurrentGroup)
      )

      Testsuite.Test(lambda { Users.AddGroup({}) }, [@READ, @WRITE, @EXEC], 0)

      Testsuite.Dump(
        Builtins.sformat(
          "---- current group (empty add, to get default values):\n %1",
          Users.GetCurrentGroup
        )
      )

      @group = {
        "gidNumber" => 555,
        "cn"        => "testgrp",
        "userlist"  => { "hh" => 1 },
        "password"  => "x",
        "type"      => "local",
        "what"      => "add_group"
      }

      Testsuite.Test(lambda { Users.AddGroup(@group) }, [@READ, @WRITE, @EXEC], 0)

      Testsuite.Dump(
        Builtins.sformat(
          "---- current group (after rich add):\n %1",
          Users.GetCurrentGroup
        )
      )

      Ops.set(@EXEC, ["target", "bash_output", "stdout"], "testgrp")

      @error = Convert.to_string(
        Testsuite.Test(lambda { Users.CheckGroup({}) }, [@READ, @WRITE, @EXEC], 0)
      )

      Testsuite.Dump(
        Builtins.sformat("---- check group after add:\n %1", @error)
      )

      Users.SelectUserByName("hh")

      Testsuite.Dump(
        Builtins.sformat("---- user 'hh':\n %1", Users.GetCurrentUser)
      )

      Testsuite.Test(lambda { Users.CommitGroup }, [@READ, @WRITE, @EXEC], 0)

      Users.SelectUserByName("hh")

      Testsuite.Dump(
        Builtins.sformat("---- user 'hh':\n %1", Users.GetCurrentUser)
      )

      Testsuite.Dump(
        "=========================================================="
      )

      Testsuite.Dump(
        Builtins.sformat(
          "local group names:\n %1",
          UsersCache.GetGroupnames("local")
        )
      )

      Testsuite.Dump(
        "================= gid conflict (not fatal any more) ======"
      )

      Ops.set(@EXEC, ["target", "bash_output", "stdout"], "new")

      Testsuite.Test(lambda { Users.AddGroup({}) }, [@READ, @WRITE, @EXEC], 0)
      Testsuite.Test(lambda do
        Users.AddGroup({ "cn" => "new", "gidNumber" => 0, "type" => "system" })
      end, [
        @READ,
        @WRITE,
        @EXEC
      ], 0)

      Testsuite.Dump(
        Builtins.sformat(
          "---- current group after add:\n %1",
          Users.GetCurrentGroup
        )
      )

      @error = Convert.to_string(
        Testsuite.Test(lambda { Users.CheckGroup({}) }, [@READ, @WRITE, @EXEC], 0)
      )

      Testsuite.Dump(
        Builtins.sformat("---- check group after add:\n %1", @error)
      )

      Testsuite.Dump(
        "================= name conflict =========================="
      )

      Ops.set(@EXEC, ["target", "bash_output", "stdout"], "testgrp")

      Testsuite.Test(lambda { Users.AddGroup({}) }, [@READ, @WRITE, @EXEC], 0)
      Testsuite.Test(lambda { Users.AddGroup({ "cn" => "testgrp" }) }, [], 0)

      Testsuite.Dump(
        Builtins.sformat(
          "---- current group after add):\n %1",
          Users.GetCurrentGroup
        )
      )

      @error = Convert.to_string(
        Testsuite.Test(lambda { Users.CheckGroup({}) }, [@READ, @WRITE, @EXEC], 0)
      )

      Testsuite.Dump(
        Builtins.sformat("---- check group after add:\n %1", @error)
      )

      Testsuite.Dump(
        "================= name too short ========================="
      )

      Testsuite.Test(lambda { Users.AddGroup({}) }, [@READ, @WRITE, @EXEC], 0)
      Testsuite.Test(lambda { Users.AddGroup({ "cn" => "t" }) }, [], 0)

      Testsuite.Dump(
        Builtins.sformat(
          "---- current group after add:\n %1",
          Users.GetCurrentGroup
        )
      )

      @error = Convert.to_string(
        Testsuite.Test(lambda { Users.CheckGroup({}) }, [@READ, @WRITE, @EXEC], 0)
      )

      Testsuite.Dump(
        Builtins.sformat("---- check group after add:\n %1", @error)
      )

      nil
    end
  end
end

Yast::AddGroupClient.new.main
