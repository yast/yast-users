# encoding: utf-8

# File		: YaPIGroupAdd.ycp
# Module	: Users configurator
# Summary	: Test of USERS::GroupAdd function
# Author	: Jiri Suchomel <jsuchome@suse.cz>
#
# $Id$
module Yast
  class YaPIGroupAddClient < Client
    def main
      # testedfiles: Users.pm UsersCache.pm USERS.pm UsersLDAP.pm UsersPasswd.pm


      Yast.import "Directory"
      Yast.import "Mode"
      Yast.import "Users"
      Yast.import "UsersPasswd"
      Yast.import "YaPI::USERS"

      @tmpdir = Directory.tmpdir
      Builtins.foreach(["passwd", "group", "shadow"]) do |file|
        SCR.Execute(
          path(".target.bash"),
          Builtins.sformat("/bin/cp ./%1 %2/", file, @tmpdir)
        )
      end
      Users.SetBaseDirectory(@tmpdir)
      Users.ReadLocal

      Yast.import "Testsuite"

      @R = {
        "etc"     => {
          "fstab"     => [],
          "cryptotab" => [],
          "default"   => {
            "useradd" => {
              "home"   => "/tmp/local/home",
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
            "ENABLE_AUTOLOGIN"                => "false",
            "IO_SCHEDULER"                    => "",
            "UI_MODE"                         => "simple",
            "EVMS_CONFIG"                     => "no",
            "INCOMPLETE_TRANSLATION_TRESHOLD" => "99"
          }
        }
      }
      @W = {}
      @E = {
        "passwd" => { "init" => true },
        "target" => { "mkdir" => true, "bash" => 0, "bash_output" => {} }
      }

      Testsuite.Dump(
        "=========================================================="
      )

      Mode.SetTest("test")

      Testsuite.Test(lambda { Users.SetBaseDirectory("/etc") }, [], 0)
      Testsuite.Test(lambda { UsersPasswd.SetBaseDirectory("/etc") }, [], 0)

      @config_map = {}
      @data_map = { "cn" => "gg" }
      Ops.set(@E, ["target", "bash_output", "stdout"], "gg")

      Testsuite.Dump(
        "============ add new group 'gg': =========================="
      )
      Testsuite.Test(lambda { YaPI::USERS.GroupAdd(@config_map, @data_map) }, [
        @R,
        @W,
        @E
      ], 0)
      Testsuite.Dump(
        "============ add new group 'gg' - done ===================="
      )


      Ops.set(@data_map, "userlist", ["hh"])
      Ops.set(@data_map, "cn", "gg2")
      Ops.set(@E, ["target", "bash_output", "stdout"], "gg2")

      Testsuite.Dump(
        "============ add new group 'gg2' with first userlist as list =="
      )
      Testsuite.Test(lambda { YaPI::USERS.GroupAdd(@config_map, @data_map) }, [
        @R,
        @W,
        @E
      ], 0)
      Testsuite.Dump(
        "============ add new group 'gg2' - done ===================="
      )

      Ops.set(@data_map, "userlist", { "hh" => 1, "ii" => 1 })
      Ops.set(@data_map, "cn", "gg3")
      Ops.set(@E, ["target", "bash_output", "stdout"], "gg3")

      Testsuite.Dump(
        "============ add new group 'gg3' with first userlist as map =="
      )
      Testsuite.Test(lambda { YaPI::USERS.GroupAdd(@config_map, @data_map) }, [
        @R,
        @W,
        @E
      ], 0)
      Testsuite.Dump(
        "============ add new group 'gg3' - done ===================="
      )

      Ops.set(@data_map, "userlist", { "hh2" => 1 })
      Ops.set(@data_map, "cn", "gg4")
      Ops.set(@E, ["target", "bash_output", "stdout"], "gg4")

      Testsuite.Dump(
        "============ add new group 'gg4' with non existent user =="
      )
      Testsuite.Test(lambda { YaPI::USERS.GroupAdd(@config_map, @data_map) }, [
        @R,
        @W,
        @E
      ], 0)
      Testsuite.Dump(
        "============ add new group 'gg4' - done ===================="
      )

      Testsuite.Dump(
        "============ add new group 'root' (groupname conflict): ======"
      )

      @data_map = { "cn" => "root" }
      Ops.set(@E, ["target", "bash_output", "stdout"], "root")

      @error = Convert.to_string(Testsuite.Test(lambda do
        YaPI::USERS.GroupAdd(@config_map, @data_map)
      end, [
        @R,
        @W,
        @E
      ], 0))
      Testsuite.Dump(
        Builtins.sformat("------------ GroupAdd return value:\n%1", @error)
      )

      Testsuite.Dump(
        "============ add new group 'root' - done ===================="
      )
      Testsuite.Dump(
        "=========================================================="
      )

      nil
    end
  end
end

Yast::YaPIGroupAddClient.new.main
