# encoding: utf-8

# Test for UsersLDAP::ConvertMap
# Author:	Jiri Suchomel <jsuchome@suse.cz>
# $Id$
module Yast
  class ConvertMapClient < Client
    def main
      # testedfiles: Users.pm UsersLDAP.pm

      @READ = {
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
        "ldap"    => {
          "schema" => {
            "oc" => {
              "may" => [
                "gidNumber",
                "gecos",
                "objectClass",
                "uid",
                "uidNumber",
                "userPassword",
                "loginShell"
              ]
            }
          }
        },
        "target"  => { "stat" => {} }
      }
      @WRITE = {}
      @EXEC = {}

      Yast.import "Testsuite"

      Testsuite.Init([@READ, @WRITE, @EXEC], nil)

      Yast.import "Users"
      Yast.import "Mode"
      Yast.import "Directory"
      Yast.import "UsersLDAP"

      Testsuite.Dump(
        "=========================================================="
      )

      Mode.SetTest("test")

      @user = {
        "dn"            => "uid=test2,ou=people,dc=suse,dc=cz",
        "gidNumber"     => 100,
        "groupname"     => "users",
        "encrypted"     => true,
        "gecos"         => "test",
        "grouplist"     => { "audio" => 1 },
        "loginShell"    => "/bin/csh",
        "modified"      => "edited",
        "objectClass"   => [
          "inetOrgPerson",
          "posixAccount",
          "shadowAccount",
          "top"
        ],
        "org_uid"       => "test2",
        "org_uidnumber" => 11111,
        "plugins"       => ["UsersPluginLDAPAll"],
        "type"          => "ldap",
        "uid"           => "test2",
        "uidNumber"     => 11111,
        "userPassword"  => "{crypt}IVj2W92x/IuFs",
        "what"          => "edit_user",
        "org_user"      => {
          "dn"           => "uid=test2,ou=people,dc=suse,dc=cz",
          "gidNumber"    => 100,
          "groupname"    => "users",
          "gecos"        => "test",
          "loginShell"   => "/bin/bash",
          "grouplist"    => { "audio" => 1 },
          "objectClass"  => [
            "inetOrgPerson",
            "posixAccount",
            "shadowAccount",
            "top"
          ],
          "type"         => "ldap",
          "uid"          => "test2",
          "uidNumber"    => 11111,
          "userPassword" => "{crypt}IVj2W92x/IuFs"
        }
      }

      Testsuite.Dump(
        Builtins.sformat("--------- user (loginshell is changed):\n %1", @user)
      )

      @converted = Convert.convert(
        Testsuite.Test(lambda { UsersLDAP.ConvertMap(@user) }, [
          @READ,
          @WRITE,
          @EXEC
        ], 0),
        :from => "any",
        :to   => "map <string, any>"
      )

      Testsuite.Dump(Builtins.sformat("--------- converted :\n %1", @converted))

      Testsuite.Dump(
        "=========================================================="
      )

      Ops.set(@user, "userPassword", "qqqqq")

      Testsuite.Dump(
        Builtins.sformat("--------- user (new password):\n %1", @user)
      )

      @converted = Convert.convert(
        Testsuite.Test(lambda { UsersLDAP.ConvertMap(@user) }, [
          @READ,
          @WRITE,
          @EXEC
        ], 0),
        :from => "any",
        :to   => "map <string, any>"
      )

      Testsuite.Dump(Builtins.sformat("--------- converted :\n %1", @converted))

      Testsuite.Dump(
        "=========================================================="
      )

      Ops.set(
        @user,
        "objectClass",
        [
          "inetOrgPerson",
          "posixAccount",
          "shadowAccount",
          "top",
          "sambaSamAccount"
        ]
      )
      Ops.set(
        @user,
        "userPassword",
        Ops.get_string(@converted, "userPassword", "")
      )
      Ops.set(
        @user,
        ["org_user", "userPassword"],
        Ops.get_string(@converted, "userPassword", "")
      )

      Testsuite.Dump(
        Builtins.sformat("--------- user (new object class):\n %1", @user)
      )

      @converted = Convert.convert(
        Testsuite.Test(lambda { UsersLDAP.ConvertMap(@user) }, [
          @READ,
          @WRITE,
          @EXEC
        ], 0),
        :from => "any",
        :to   => "map <string, any>"
      )

      Testsuite.Dump(Builtins.sformat("--------- converted :\n %1", @converted))

      Testsuite.Dump(
        "=========================================================="
      )

      @user = Builtins.remove(@user, "org_user")

      Testsuite.Dump(
        Builtins.sformat(
          "--------- user (removed 'org_user' submap):\n %1",
          @user
        )
      )

      @converted = Convert.convert(
        Testsuite.Test(lambda { UsersLDAP.ConvertMap(@user) }, [
          @READ,
          @WRITE,
          @EXEC
        ], 0),
        :from => "any",
        :to   => "map <string, any>"
      )

      Testsuite.Dump(Builtins.sformat("--------- converted :\n %1", @converted))

      nil
    end
  end
end

Yast::ConvertMapClient.new.main
