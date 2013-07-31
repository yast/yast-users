# encoding: utf-8

# Author	: Jiri Suchomel <jsuchome@suse.cz>
# $Id$
# Testing what is allowed for password (see bug #106714)
module Yast
  class CheckPasswordClient < Client
    def main
      # testedfiles: Users.pm UsersSimple.pm
      Yast.import "Testsuite"
      Yast.import "Users"
      Yast.import "UsersSimple"

      @R = {}
      @W = {}
      @E = { "crack" => "" }

      test_ui("hh", "qqqqq")
      test_ui("hh", "QQQQQ")
      test_ui("hh", "12hh5")
      test_ui("hh", "12345")
      test_ui("hh", "aaaQQaaa")
      test_ui("hh", "1a")
      Testsuite.Test(lambda { Users.SetEncryptionMethod("des") }, [], 0)
      test_ui("hh", "1aaaaaaaaaaaaaaaaa")
      test_contents("`!@\#$%^&*()-=_+|")
      test_contents("[];',./{}:\"<>")
      test_contents("\\")
      test_contents("")
      test_contents(nil)
      test_contents("\u0159\u0161\u010D")

      nil
    end

    def test_ui(username, pw)
      Testsuite.Test(lambda do
        UsersSimple.CheckPasswordUI(
          { "uid" => username, "userPassword" => pw, "type" => "local" }
        )
      end, [
        @R,
        @W,
        @E
      ], 0)

      nil
    end

    def test_contents(pw)
      Testsuite.Dump(Builtins.sformat("-------- password: %1", pw))
      err = Convert.to_string(Testsuite.Test(lambda do
        UsersSimple.CheckPassword(pw, "local")
      end, [
        @R,
        @W,
        @E
      ], 0))
      Testsuite.Dump(Builtins.sformat("-------- error: %1", err)) if err != ""

      nil
    end
  end
end

Yast::CheckPasswordClient.new.main
