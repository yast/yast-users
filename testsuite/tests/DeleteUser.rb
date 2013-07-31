# encoding: utf-8

# File:
#  DeleteUser.ycp
#
# Module:
#  Users configurator
#
# Summary:
#  Saving user tests.
#
# Authors:
#  Jiri Suchomel <jsuchome@suse.cz>
#
module Yast
  class DeleteUserClient < Client
    def main
      # testedfiles: Users.pm UsersCache.pm UsersLDAP.pm

      Yast.import "Users"
      Yast.import "UsersCache"
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
      @EXEC = { "passwd" => { "init" => true }, "target" => { "bash" => 0 } }

      Yast.import "Testsuite"

      Mode.SetTest("test")

      Testsuite.Test(lambda { Users.Read }, [@READ, @WRITE, @EXEC], 0)

      Testsuite.Dump(
        Builtins.sformat("local users:\n %1", Users.GetUsers("uid", "local"))
      )

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
      Users.SelectUserByName("ii")

      Testsuite.Dump(
        Builtins.sformat("---- user 'ii':\n %1", Users.GetCurrentUser)
      )

      Users.SelectGroupByName("audio")

      Testsuite.Dump(
        Builtins.sformat("---- group 'audio':\n %1", Users.GetCurrentGroup)
      )

      Users.SelectGroupByName("users")

      Testsuite.Dump(
        Builtins.sformat("---- group 'users':\n %1", Users.GetCurrentGroup)
      )

      Testsuite.Dump(
        "==================== running delete ======================"
      )

      Testsuite.Test(lambda { Users.DeleteUser(true) }, [@READ], 0)
      Testsuite.Test(lambda { Users.CommitUser }, [@READ], 0)

      Testsuite.Dump(
        Builtins.sformat(
          "local user names:\n %1",
          UsersCache.GetUsernames("local")
        )
      )
      Testsuite.Dump(
        Builtins.sformat("local users:\n %1", Users.GetUsers("uid", "local"))
      )

      Users.SelectGroupByName("audio")

      Testsuite.Dump(
        Builtins.sformat("---- group 'audio':\n %1", Users.GetCurrentGroup)
      )

      Users.SelectGroupByName("users")

      Testsuite.Dump(
        Builtins.sformat("---- group 'users':\n %1", Users.GetCurrentGroup)
      )

      nil
    end
  end
end

Yast::DeleteUserClient.new.main
