require "yast"
module Yast
  # This exists because it is hard to use RSpec mocks for code
  # that goes through Perl (like UsersLdap.pm)
  class LdapClass < Module
    Builtins.y2milestone("Using a mock Ldap module")
  end
  Ldap = LdapClass.new
end
