# encoding: utf-8

# File		: ReadLDAPAvailable.ycp
# Module	: Users configurator
# Summary	: Test of UsersLDAP::ReadAvailable
# Authors	: Jiri Suchomel <jsuchome@suse.cz>
module Yast
  class ReadLDAPAvailableClient < Client
    def main
      # testedfiles: UsersLDAP.pm

      @READ = { "etc" => { "nsswitch_conf" => { "passwd" => "ldap files" } } }

      Yast.import "Testsuite"
      Yast.import "UsersLDAP"

      Testsuite.Test(lambda { UsersLDAP.ReadAvailable }, [@READ, {}, {}], 0)

      Ops.set(@READ, ["etc", "nsswitch_conf", "passwd"], "files")

      Testsuite.Test(lambda { UsersLDAP.ReadAvailable }, [@READ, {}, {}], 0)

      Ops.set(@READ, ["etc", "nsswitch_conf", "passwd"], "sss")

      Testsuite.Test(lambda { UsersLDAP.ReadAvailable }, [@READ, {}, {}], 0)

      nil
    end
  end
end

Yast::ReadLDAPAvailableClient.new.main
