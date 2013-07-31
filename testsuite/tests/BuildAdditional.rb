# encoding: utf-8

module Yast
  class BuildAdditionalClient < Client
    def main
      # testedfiles: Users.pm UserCache.pm UsersLDAP.pm

      Yast.import "Users"
      Yast.import "UsersCache"
      Yast.import "Mode"
      Yast.import "Directory"
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
        "target"  => { "stat" => {}, "size" => -1 }
      }

      @WRITE = {}
      @EXEC = { "passwd" => { "init" => true }, "target" => { "bash" => -1 } }

      Yast.import "Testsuite"

      Testsuite.Dump(
        "=========================================================="
      )
      Mode.SetTest("test")

      Testsuite.Test(lambda { Users.Read }, [@READ, @WRITE, @EXEC], 0)

      Users.SelectGroupByName("audio")

      @group = Users.GetCurrentGroup
      Testsuite.Dump(Builtins.sformat("---- current group:\n %1", @group))

      # only 'ii' is checked ('true' in the item)
      Testsuite.Dump("---- create additional users list:\n")

      @additional = Convert.to_list(Testsuite.Test(lambda do
        UsersCache.BuildAdditional(@group)
      end, [
        @READ,
        @WRITE
      ], 0))

      nil
    end
  end
end

Yast::BuildAdditionalClient.new.main
