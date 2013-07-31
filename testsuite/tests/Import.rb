# encoding: utf-8

# File		: Import.ycp
# Module	: Users configurator
# Summary	: testing Import function
# Author	: Jiri Suchomel <jsuchome@suse.cz>
# $Id$
module Yast
  class ImportClient < Client
    def main
      # testedfiles: Users.pm UsersCache.pm UsersLDAP.pm UsersSimple.pm

      Yast.import "Users"
      Yast.import "UsersCache"
      Yast.import "Mode"
      Yast.import "Directory"
      Yast.import "Progress"

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
              "home"     => "/home",
              "groups"   => "audio,video",
              "inactive" => nil,
              "expire"   => nil,
              "shell"    => nil,
              "group"    => 100
            }
          }
        },
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
        "target"    => { "stat" => {}, "size" => -1, "string" => "" },
        "sysconfig" => { "displaymanager" => { "DISPLAYMANAGER" => "" } }
      }
      @WRITE = {}
      @EXEC = {
        "passwd" => { "init" => true },
        "target" => { "bash" => -1, "bash_output" => { "stdout" => "ggg" } }
      }

      Mode.SetTest("test")

      @importing = {
        "users" => [{ "username" => "ggg", "user_password" => "password" }]
      }

      Testsuite.Dump(
        Builtins.sformat(
          "local user names:\n %1",
          UsersCache.GetUsernames("local")
        )
      )

      Testsuite.Test(lambda { Users.Import(@importing) }, [@READ, @WRITE, @EXEC], 0)

      Testsuite.Dump(
        Builtins.sformat(
          "local user names:\n %1",
          UsersCache.GetUsernames("local")
        )
      )

      Testsuite.Test(lambda { Users.SelectUserByName("ggg") }, [], 0)

      Testsuite.Dump(
        Builtins.sformat("---- user 'ggg':\n %1", Users.GetCurrentUser)
      )

      nil
    end
  end
end

Yast::ImportClient.new.main
