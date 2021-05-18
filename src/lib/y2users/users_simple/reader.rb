# Copyright (c) [2021] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "y2users/config"
require "y2users/user"
require "y2users/password"
require "y2users/parsers/shadow"

Yast.import "UsersSimple"

module Y2Users
  module UsersSimple
    # Class for reading users configuration from old Yast::UsersSimple module
    class Reader
      # @see #{shadow_string}
      SORTED_SHADOW_ATTRS = [
        # NOTE: bear in mind that, in UsersSimple, "uid" actually refers to the username
        "uid", "userPassword", "shadowLastChange", "shadowMin", "shadowMax",
        "shadowWarning", "shadowInactive", "shadowExpire", "shadowFlag"
      ].freeze
      private_constant :SORTED_SHADOW_ATTRS

      # Generates a new config with the users from YaST::UsersSimple module
      #
      # @return [Config]
      def read
        elements = [root_user] + users

        Config.new.attach(elements)
      end

    private

      # Returns the list users
      #
      # @return [Array<User>] the collection of users
      def users
        Yast::UsersSimple.GetUsers.map { |u| user(u) }
      end

      # Creates a {User} object based on the data structure of an UsersSimple user
      #
      # @param user_attrs [Hash] a user representation in the format used by UsersSimple
      # @return [User]
      def user(user_attrs)
        user = User.new(user_attrs["uid"])

        user.uid   = attr_value(:uidNumber, user_attrs)
        user.gid   = attr_value(:gidNumber, user_attrs)
        user.shell = attr_value(:loginShell, user_attrs)
        user.home  = attr_value(:homeDirectory, user_attrs)
        user.gecos = [attr_value(:cn, user_attrs)].compact

        user.password = create_password(user_attrs)

        user
      end

      # Returns the root user
      #
      # @return [User] the root user
      def root_user
        user = User.new("root")
        user.gecos = ["root"]
        user.uid = "0"
        user.home = "/root"

        passwd_str = Yast::UsersSimple.GetRootPassword
        user.password = Password.create_plain(passwd_str) unless passwd_str.empty?

        user
      end

      # Value of the given field for the given UsersSimple user
      #
      # @param attr [#to_s] name of the attribute
      # @param user [Hash] a user representation in the format used by UsersSimple
      # @return [String, nil] nil if the value is missing or empty
      def attr_value(attr, user)
        value = user[attr.to_s]
        return nil if value == ""

        value
      end

      # Creates a {Password} object based on the data structure of an UsersSimple user
      #
      # @param user [Hash] a user representation in the format used by UsersSimple
      # @return [Password]
      def create_password(user)
        parser = Parsers::Shadow.new
        content = shadow_string(user)

        password = parser.parse(content).values.first
        password.value = PasswordPlainValue.new(user["userPassword"]) unless user["encrypted"]
        password
      end

      # Entry in /etc/shadow describing the password of the given user
      #
      # @param user [Hash] a user representation in the format used by UsersSimple
      # @return [String]
      def shadow_string(user)
        SORTED_SHADOW_ATTRS.map do |attr|
          user[attr] || ""
        end.join(":")
      end
    end
  end
end
