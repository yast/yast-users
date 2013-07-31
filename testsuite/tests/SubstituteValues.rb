# encoding: utf-8

# Test for UsersLDAP::SubstituteValues
# Author	: Jiri Suchomel <jsuchome@suse.cz>
# $Id$
module Yast
  class SubstituteValuesClient < Client
    def main
      # testedfiles: UsersLDAP.pm

      Yast.import "Testsuite"
      Yast.import "Mode"
      Yast.import "UsersLDAP"

      @user = { "homeDirectory" => "/home/%uid", "cn" => "%uid", "uid" => "hh" }

      Mode.SetTest("test")

      Testsuite.Dump(@user)

      Testsuite.Test(lambda { UsersLDAP.SubstituteValues("user", @user) }, [], 0)

      nil
    end
  end
end

Yast::SubstituteValuesClient.new.main
