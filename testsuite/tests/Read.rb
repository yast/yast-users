# encoding: utf-8

# File		: Read.ycp
# Module	: Users configurator
# Summary	: Test of Users::Read
# Authors	: Jiri Suchomel <jsuchome@suse.cz>
module Yast
  class ReadClient < Client
    def main
      # testedfiles: Users.pm UsersLDAP.pm

      Yast.import "Users"
      Yast.import "UsersCache"
      Yast.import "Mode"
      Yast.import "Directory"
      Yast.import "Progress"
      Yast.import "Report"

      @tmpdir = Directory.tmpdir
      Builtins.foreach(["passwd", "group", "shadow"]) do |file|
        SCR.Execute(
          path(".target.bash"),
          Builtins.sformat("/bin/cp ./%1 %2/", file, @tmpdir)
        )
        if file == "passwd"
          SCR.Execute(
            path(".target.bash"),
            Builtins.sformat(
              "echo \"hh2:x:500:100:HaHa2:/home/hh2:/bin/bash\" >> %1/passwd",
              @tmpdir
            )
          )
        end
      end
      Users.SetBaseDirectory(@tmpdir)
      Users.ReadLocal

      Yast.import "Testsuite"

      @READ = {
        "etc"       => { "fstab" => [], "cryptotab" => [] },
        "product"   => {
          "features" => {
            "USE_DESKTOP_SCHEDULER"           => "no",
            "IO_SCHEDULER"                    => "",
            "ENABLE_AUTOLOGIN"                => "false",
            "UI_MODE"                         => "simple",
            "EVMS_CONFIG"                     => "no",
            "INCOMPLETE_TRANSLATION_TRESHOLD" => "99"
          }
        },
        "target"    => { "stat" => {} },
        "sysconfig" => {
          "displaymanager" => {
            "DISPLAYMANAGER_AUTOLOGIN"           => "",
            "DISPLAYMANAGER_PASSWORD_LESS_LOGIN" => ""
          }
        }
      }
      @WRITE = {}
      @EXEC = {
        "passwd" => { "init" => true },
        "target" => { "bash" => -1, "bash_output" => {} }
      }

      Testsuite.Dump(
        "=========================================================="
      )

      Mode.SetTest("test")

      Testsuite.Test(lambda { Users.Read }, [@READ, @WRITE, @EXEC], 0)

      Testsuite.Test(lambda { Users.SelectUserByName("hh") }, [], 0)
      Testsuite.Dump(
        Builtins.sformat("---- user hh:\n %1", Users.GetCurrentUser)
      )

      Testsuite.Test(lambda { Users.SelectUserByName("hh2") }, [], 0)
      Testsuite.Dump(
        Builtins.sformat("---- user hh2:\n %1", Users.GetCurrentUser)
      )

      Testsuite.Dump(
        "=========================================================="
      )

      nil
    end
  end
end

Yast::ReadClient.new.main
