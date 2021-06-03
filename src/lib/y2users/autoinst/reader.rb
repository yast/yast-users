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

require "y2users/parsers/shadow"
require "y2users/user"
require "y2users/group"
require "y2users/password"
require "y2users/login_config"
require "y2users/autoinst_profile/users_section"
require "y2users/autoinst_profile/groups_section"
require "y2users/autoinst_profile/login_settings_section"

module Y2Users
  module Autoinst
    # This reader builds a Y2Users::Config from an AutoYaST profile hash
    class Reader
      include Yast::Logger

      # @param content [Hash] Hash containing AutoYaST data
      # @option content [Hash] "users" List of users
      # @option content [Hash] "groups" List of groups
      def initialize(content)
        @users_section = Y2Users::AutoinstProfile::UsersSection.new_from_hashes(
          content["users"] || []
        )
        @groups_section = Y2Users::AutoinstProfile::GroupsSection.new_from_hashes(
          content["groups"] || []
        )

        return unless content["login_settings"]

        @login_settings_section = Y2Users::AutoinstProfile::LoginSettingsSection.new_from_hashes(
          content["login_settings"]
        )
      end

      # Generates a new config with the information from the AutoYaST profile
      #
      # @return [Config]
      def read
        Config.new.tap do |config|
          read_elements(config)
          read_login(config)
        end
      end

    private

      # Profile section describing the users
      #
      # @return [AutoinstProfile::UsersSection]
      attr_reader :users_section

      # Profile section describing the groups
      #
      # @return [AutoinstProfile::GroupsSection]
      attr_reader :groups_section

      # Profile section describing the login settings
      #
      # @return [AutoinstProfile::LoginSettingsSections]
      attr_reader :login_settings_section

      # Reads users and groups from the AutoYaST profile
      #
      # @param config [Config]
      def read_elements(config)
        elements = read_users + read_groups

        config.attach(elements)
      end

      # Reads the login settings from the AutoYaST profile
      #
      # @param config [Config]
      def read_login(config)
        return unless login_settings_section

        login = LoginConfig.new
        login.autologin_user = config.users.by_name(login_settings_section.autologin_user)
        login.passwordless = login_settings_section.password_less_login || false

        config.login = login
      end

      def read_users
        users_section.entries.map do |e_user|
          res = User.new(e_user.username)
          res.gecos = [e_user.fullname]
          # TODO: handle forename/lastname
          res.gid = e_user.gid
          res.home = e_user.home
          res.shell = e_user.shell
          res.uid = e_user.uid
          res.password = create_password(e_user)
          res
        end
      end

      def read_groups
        groups_section.entries.map do |e_group|
          res = Group.new(e_group.groupname)
          res.gid = e_group.gid
          users_name = e_group.userlist.to_s.split(",")
          res.users_name = users_name
          res.source = :local
          res
        end
      end

      # Creates a {Password} object based on the data structure of a user
      #
      # @param user [AutoinstProfile::UsersSection] a user representation in the format used by
      #   Users.Export
      # @return [Password,nil]
      def create_password(user)
        return nil unless user.user_password

        create_meth = user.encrypted ? :create_encrypted : :create_plain
        password = Password.send(create_meth, user.user_password)
        password_settings = user.password_settings
        return password unless password_settings

        last_change = password_settings.last_change
        expire = password_settings.expire

        password.aging = PasswordAging.new(last_change) if last_change
        password.minimum_age = password_settings.min
        password.maximum_age = password_settings.max
        password.warning_period = password_settings.warn
        password.inactivity_period = password_settings.inact
        password.account_expiration = AccountExpiration.new(expire) if expire
        password
      end
    end
  end
end
