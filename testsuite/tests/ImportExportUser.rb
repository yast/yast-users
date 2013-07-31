# encoding: utf-8

# File:
#  ImportExportUser.ycp
#
# Module:
#  Users configurator
#
# Summary:
#  converting user maps: autoyast -> users module -> autoyast
#
# Authors:
#  Jiri Suchomel <jsuchome@suse.cz>
#
module Yast
  class ImportExportUserClient < Client
    def main
      # testedfiles: Users.pm UsersCache.pm

      Yast.import "Users"
      Yast.import "UsersCache"
      Yast.import "Mode"
      Yast.import "Directory"
      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "Testsuite"

      Testsuite.Dump(
        "=========================================================="
      )

      Mode.SetTest("test")

      @importing = {
        "encrypted"         => true,
        "forename"          => "aa",
        "surname"           => "A",
        "uid"               => 500,
        "gid"               => 500,
        "home"              => "/home/aaa",
        "user_password"     => "5OkhN2nLxMfEY",
        "password_settings" => {
          "inact" => -1,
          "max"   => 99999,
          "min"   => 0,
          "warn"  => 7
        },
        "grouplist"         => "audio",
        "shell"             => "/bin/bash",
        "username"          => "aaa"
      }

      Testsuite.Dump(Builtins.sformat("importing:\n %1", @importing))

      Testsuite.Dump(
        "==== processing ImportUser... ============================"
      )

      @user = Convert.convert(
        Testsuite.Test(lambda { Users.ImportUser(@importing) }, [], 0),
        :from => "any",
        :to   => "map <string, any>"
      )

      Testsuite.Dump(
        "==== processing ExportUser... ============================"
      )

      Testsuite.Test(lambda { Users.ExportUser(@user) }, [], 0)

      nil
    end
  end
end

Yast::ImportExportUserClient.new.main
