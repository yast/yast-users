# encoding: utf-8

# Author	: Jiri Suchomel <jsuchome@suse.cz>
# $Id$
#
# The "last UID" is used to form UID for new created users (via NextFreeUID); however
# it's value should be at least UID_MIN from /etc/login.defs, regardless the UID last
# used for creating user (see bug #119006)
module Yast
  class LastUIDClient < Client
    def main
      # testedfiles: Users.pm UsersCache.pm
      Yast.import "Testsuite"
      Yast.import "Users"
      Yast.import "UsersCache"

      @R = {}
      @W = {}
      @E = {}

      Testsuite.Test(lambda { UsersCache.GetLastUID("local") }, [@R, @W, @E], 0)

      @consts = { "UID_MIN" => "5000", "GID_MIN" => "6000" }
      # highest uid of current local users
      @last_uid = 2000

      # this should not happen
      Testsuite.Test(lambda { UsersCache.SetLastUID(@last_uid, "local") }, [
        @R,
        @W,
        @E
      ], 0)
      Testsuite.Test(lambda { UsersCache.GetLastUID("local") }, [@R, @W, @E], 0)
      Testsuite.Test(lambda { UsersCache.GetLastGID("local") }, [@R, @W, @E], 0)

      # InitConstants reads correct UID_MIN and is called before SetLastUID
      Testsuite.Test(lambda { UsersCache.InitConstants(@consts) }, [@R, @W, @E], 0)
      Testsuite.Test(lambda { UsersCache.SetLastUID(@last_uid, "local") }, [
        @R,
        @W,
        @E
      ], 0)
      Testsuite.Test(lambda { UsersCache.SetLastGID(@last_uid, "local") }, [
        @R,
        @W,
        @E
      ], 0)
      Testsuite.Test(lambda { UsersCache.GetLastUID("local") }, [@R, @W, @E], 0)
      Testsuite.Test(lambda { UsersCache.GetLastGID("local") }, [@R, @W, @E], 0)

      nil
    end
  end
end

Yast::LastUIDClient.new.main
