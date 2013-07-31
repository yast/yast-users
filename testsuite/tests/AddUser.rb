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
  class AddUserClient < Client
    def main
      # testedfiles: Users.pm UsersLDAP.pm UsersCache.pm UsersSimple.pm

      Yast.import "Directory"
      Yast.import "Users"
      Yast.import "UsersCache"
      Yast.import "UsersLDAP"
      Yast.import "Mode"
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
              "home"     => "/home",
              "groups"   => "audio,video",
              "inactive" => nil,
              "expire"   => nil,
              "shell"    => nil,
              "group"    => 100
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
        }
      }
      @WRITE = {}
      @EXEC = {
        "passwd" => { "init" => true },
        "target" => { "bash" => 0, "bash_output" => {} }
      }

      Yast.import "Testsuite"

      Testsuite.Dump(
        "=========================================================="
      )
      Mode.SetTest("test")

      Testsuite.Test(lambda { Users.Read }, [@READ, @WRITE, @EXEC], 0)

      Testsuite.Dump(
        Builtins.sformat("---- current user:\n %1", Users.GetCurrentUser)
      )
      Testsuite.Test(lambda { Users.AddUser({}) }, [@READ, @WRITE, @EXEC], 0)

      Testsuite.Dump(
        Builtins.sformat(
          "---- current user (empty add):\n %1",
          Users.GetCurrentUser
        )
      )
      @user = {
        "uidNumber"     => 501,
        "uid"           => "aaa",
        "gidNumber"     => 100,
        "groupname"     => "users",
        "grouplist"     => { "audio" => 1 },
        "homeDirectory" => "/local/home/aaa",
        "userPassword"  => "qqqqq",
        "type"          => "local"
      }

      Testsuite.Test(lambda { Users.AddUser(@user) }, [@READ, @WRITE, @EXEC], 0)

      Testsuite.Dump(
        Builtins.sformat(
          "---- current user (after rich add):\n %1",
          Users.GetCurrentUser
        )
      )

      Ops.set(@EXEC, ["target", "bash_output", "stdout"], "aaa")

      @error = Convert.to_string(
        Testsuite.Test(lambda { Users.CheckUser({}) }, [@READ, @WRITE, @EXEC], 0)
      )

      Users.SelectGroup(100)
      Testsuite.Dump(
        Builtins.sformat(
          "---- current group (before user commit):\n %1",
          Users.GetCurrentGroup
        )
      )

      Testsuite.Dump(
        Builtins.sformat("---- check user after add:\n %1", @error)
      )

      Testsuite.Dump("---- commit user:")

      Testsuite.Test(lambda { Users.CommitUser }, [@READ, @WRITE, @EXEC], 0)

      Users.SelectGroup(100)
      Testsuite.Dump(
        Builtins.sformat(
          "---- current group (afer user commit):\n %1",
          Users.GetCurrentGroup
        )
      )

      Testsuite.Dump(
        "=================== no password =========================="
      )

      Testsuite.Test(lambda { Users.AddUser({}) }, [@READ, @WRITE, @EXEC], 0)
      Testsuite.Test(lambda { Users.AddUser({ "uid" => "hhh" }) }, [
        @READ,
        @WRITE,
        @EXEC
      ], 0)

      Testsuite.Dump(
        Builtins.sformat(
          "---- current user (minimal add, used default values):\n %1",
          Users.GetCurrentUser
        )
      )

      Ops.set(@EXEC, ["target", "bash_output", "stdout"], "hhh")

      @error = Convert.to_string(
        Testsuite.Test(lambda { Users.CheckUser({}) }, [@READ, @WRITE, @EXEC], 0)
      )

      Testsuite.Dump(
        Builtins.sformat("---- check user after add:\n %1", @error)
      )

      Testsuite.Dump(
        "==================== username conflict ========================"
      )

      Testsuite.Test(lambda { Users.AddUser({}) }, [@READ, @WRITE, @EXEC], 0)
      Testsuite.Test(lambda do
        Users.AddUser({ "uid" => "root", "userPassword" => "qqqqq" })
      end, [
        @READ,
        @WRITE,
        @EXEC
      ], 0)

      Testsuite.Dump(
        Builtins.sformat(
          "---- current user (just added):\n %1",
          Users.GetCurrentUser
        )
      )
      Ops.set(@EXEC, ["target", "bash_output", "stdout"], "root")

      @error = Convert.to_string(
        Testsuite.Test(lambda { Users.CheckUser({}) }, [@READ, @WRITE, @EXEC], 0)
      )

      Testsuite.Dump(
        Builtins.sformat("---- check user after add:\n %1", @error)
      )

      Testsuite.Dump(
        "==================== uidNumber problems ==================="
      )

      Testsuite.Test(lambda { Users.AddUser({}) }, [@READ, @WRITE, @EXEC], 0)
      Testsuite.Test(lambda do
        Users.AddUser(
          {
            "uid"          => "rrr",
            "uidNumber"    => 5,
            "type"         => "local",
            "userPassword" => "qqqqq"
          }
        )
      end, [
        @READ,
        @WRITE,
        @EXEC
      ], 0)

      Testsuite.Dump(
        Builtins.sformat(
          "---- current user (just added):\n %1",
          Users.GetCurrentUser
        )
      )
      Ops.set(@EXEC, ["target", "bash_output", "stdout"], "rrr")

      @error = Convert.to_string(
        Testsuite.Test(lambda { Users.CheckUser({}) }, [@READ, @WRITE, @EXEC], 0)
      )

      Testsuite.Dump(
        Builtins.sformat("---- check user after add:\n %1", @error)
      )

      Testsuite.Dump(
        "==================== uid content problems ==================="
      )

      Testsuite.Test(lambda { UsersLDAP.SetUserBase("dc=suse,dc=cz") }, [], 0)
      Testsuite.Test(lambda { Users.AddUser({}) }, [@READ, @WRITE, @EXEC], 0)
      Testsuite.Test(lambda do
        Users.AddUser(
          { "uid" => "iii$", "type" => "local", "userPassword" => "qqqqq" }
        )
      end, [
        @READ,
        @WRITE,
        @EXEC
      ], 0)

      Testsuite.Dump(
        Builtins.sformat(
          "---- current user (just added):\n %1",
          Users.GetCurrentUser
        )
      )
      Ops.set(@EXEC, ["target", "bash_output", "stdout"], "")

      @error = Convert.to_string(
        Testsuite.Test(lambda { Users.CheckUser({}) }, [@READ, @WRITE, @EXEC], 0)
      )

      Testsuite.Dump(
        Builtins.sformat("---- check user after add:\n %1", @error)
      )

      Testsuite.Dump(
        "==================== uid for LDAP may contain '$' =============="
      )

      Testsuite.Test(lambda { Users.AddUser({}) }, [@READ, @WRITE, @EXEC], 0)
      Testsuite.Test(lambda do
        Users.AddUser(
          {
            "uid"           => "iii$",
            "type"          => "ldap",
            "homeDirectory" => "/home/ldap/iii",
            "userPassword"  => "qqqqq"
          }
        )
      end, [
        @READ,
        @WRITE,
        @EXEC
      ], 0)

      Testsuite.Dump(
        Builtins.sformat(
          "---- current user (just added):\n %1",
          Users.GetCurrentUser
        )
      )
      Ops.set(@EXEC, ["target", "bash_output", "stdout"], "iii")

      @error = Convert.to_string(
        Testsuite.Test(lambda { Users.CheckUser({}) }, [@READ, @WRITE, @EXEC], 0)
      )

      Testsuite.Dump(
        Builtins.sformat("---- check user after add:\n %1", @error)
      )

      Testsuite.Dump(
        "=========================================================="
      )

      Testsuite.Dump(
        "============== duplicated UID number ====================="
      )

      Testsuite.Test(lambda { Users.AddUser({}) }, [@READ, @WRITE, @EXEC], 0)
      Testsuite.Test(lambda do
        Users.AddUser(
          {
            "uid"          => "admin",
            "uidNumber"    => 0,
            "userPassword" => "qqqqq",
            "type"         => "system"
          }
        )
      end, [
        @READ,
        @WRITE,
        @EXEC
      ], 0)

      Ops.set(@EXEC, ["target", "bash_output", "stdout"], "admin")

      @error = Convert.to_string(
        Testsuite.Test(lambda { Users.CheckUser({}) }, [@READ, @WRITE, @EXEC], 0)
      )

      nil
    end
  end
end

Yast::AddUserClient.new.main
