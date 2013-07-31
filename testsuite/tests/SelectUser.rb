# encoding: utf-8

module Yast
  class SelectUserClient < Client
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
      end
      Users.SetBaseDirectory(@tmpdir)
      Users.ReadLocal

      Yast.import "Testsuite"

      @READ = {
        "etc"       => {
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
        "target"    => { "stat" => {}, "size" => 0 },
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

      Testsuite.Test(lambda { Users.SelectUser(500) }, [], 0)

      Testsuite.Dump(
        Builtins.sformat(
          "selected user with id 500:\n %1",
          Users.GetCurrentUser
        )
      )

      Testsuite.Dump(
        "=========================================================="
      )

      Testsuite.Test(lambda { Users.SelectUser(25) }, [], 0)

      Testsuite.Dump(
        Builtins.sformat("selected user with id 25:\n %1", Users.GetCurrentUser)
      )

      Testsuite.Dump(
        "=========================================================="
      )

      Testsuite.Test(lambda { Users.SelectUser(5001) }, [], 0)

      Testsuite.Dump(
        Builtins.sformat(
          "selected user with id 5001:\n %1",
          Users.GetCurrentUser
        )
      )

      nil
    end
  end
end

Yast::SelectUserClient.new.main
