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
require "y2users/group"
require "y2users/password"
require "y2users/login_config"
require "y2users/useradd_config"

Yast.import "Users"
Yast.import "Autologin"

module Y2Users
  module UsersModule
    # Class for reading the configuration from Yast::Users module
    class Reader
      # Generates a new config with the information from YaST::Users module
      #
      # @return [Config]
      def read
        Config.new.tap do |config|
          read_elements(config)
          read_autologin(config)
          read_useradd_defaults(config)
        end
      end

    private

      # Reads the useradd defaults from Users module
      #
      # @param config [Config]
      # @return [UseraddConfig]
      def read_useradd_defaults(config)
        users_map = Yast::Users.GetLoginDefaults
        # notes: groups are deprecated and usrskel and create_mail_spool is not in users
        y2users_map = {
          group:             users_map["group"],
          home:              users_map["home"],
          umask:             users_map["umask"],
          expiration:        users_map["expire"],
          inactivity_period: users_map["inactive"]&.to_i,
          shell:             users_map["shell"],
          skel:              users_map["skel"]
        }

        config.useradd = UseraddConfig.new(y2users_map)
      end

      # Reads the Autologin config from Autologin module
      #
      # @note Users reads and sets autologin directly and does not expose it
      #   so it is easier to read it directly
      #
      # @param config [Config]
      # @return [LoginConfig]
      def read_autologin(config)
        res = LoginConfig.new
        res.autologin_user = Yast::Autologin.user.empty? ? nil : Yast::Autologin.user
        res.passwordless = Yast::Autologin.pw_less

        config.login = res
      end

      # Reads the users and groups
      #
      # @param config [Config]
      def read_elements(config)
        config.attach(groups)
        config.attach(users(config))
      end

      # Returns the list of users
      #
      # @param config [Config]
      # @return [Array<User>] the collection of users
      def users(config)
        all_local = Yast::Users.GetUsers("uid", "local").values +
          Yast::Users.GetUsers("uid", "system").values
        all_local.map { |u| user(u, config) }
      end

      def groups
        all_local = Yast::Users.GetGroups("cn", "local").values +
          Yast::Users.GetGroups("cn", "system").values
        all_local.map { |u| group(u) }
      end

      # Creates a {User} object based on the data structure of a Users user
      #
      # @param user_attrs [Hash] a user representation in the format used by Users
      # @param config [Config]
      # @return [User]
      def user(user_attrs, config)
        user = User.new(user_attrs["uid"])

        user.uid   = attr_value(:uidNumber, user_attrs)&.to_s
        user.gid   = attr_value(:gidNumber, user_attrs)&.to_s
        user.gid ||= config.groups.by_name(attr_value["groupname"])&.gid

        user.shell = attr_value(:loginShell, user_attrs)
        user.home  = attr_value(:homeDirectory, user_attrs)
        user.gecos = [attr_value(:cn, user_attrs), *user_attrs["addit_data"].split(",")].compact
        user.system = true if !user.uid && user_attrs["type"] == "system"

        # set password only if specified, nil means not touch it
        user.password = create_password(user_attrs) if user_attrs["userPassword"]

        # set authorized keys only if set in users module
        user.authorized_keys = user_attrs["authorized_keys"] if user_attrs["authorized_keys"]

        user
      end

      # Creates a {Group} object based on the data structure of a Users group
      #
      # @param group_attrs [Hash] a group representation in the format used by Users
      # @return [Group]
      def group(group_attrs)
        group = Group.new(group_attrs["cn"])

        group.gid = attr_value(:gidNumber, group_attrs)&.to_s
        group.users_name = group_attrs["userlist"].keys

        # TODO: no system support for groups
        # if !group.gid && group_attrs["type"] == "system"
        #  group.system = true
        # end

        # set password only if specified, nil means not touch it
        # TODO: group passwords not supported
        # group.password = create_password(group_attrs) if group_attrs["userPassword"]

        group
      end

      # Value of the given field for the given Users user
      #
      # @param attr [#to_s] name of the attribute
      # @param user [Hash] a user or group representation in the format used by Users
      # @return [String, nil] nil if the value is missing or empty
      def attr_value(attr, user)
        value = user[attr.to_s]
        return nil if value == ""

        value
      end

      # Creates a {Password} object based on the data structure of a Users user
      #
      # @param user [Hash] a user representation in the format used by Users
      # @return [Password]
      def create_password(user)
        create_method = user["encrypted"] ? :create_encrypted : :create_plain

        Password.public_send(create_method, user["userPassword"]).tap do |password|
          last_change = user["shadowLastChange"]
          expiration = user["shadowExpire"]

          password.aging = PasswordAging.new(last_change) if last_change
          password.minimum_age = user["shadowMin"]&.to_s
          password.maximum_age = user["shadowMax"]&.to_s
          password.warning_period = user["shadowWarning"]&.to_s
          password.inactivity_period = user["shadowInactive"]&.to_s
          password.account_expiration = AccountExpiration.new(expiration) if expiration
        end
      end
    end
  end
end