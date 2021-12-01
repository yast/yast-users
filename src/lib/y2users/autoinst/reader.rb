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

require "date"
require "y2users/parsers/shadow"
require "y2users/collision_checker"
require "y2users/user"
require "y2users/home"
require "y2users/group"
require "y2users/password"
require "y2users/useradd_config"
require "y2users/login_config"
require "y2users/read_result"
require "y2users/autoinst_profile/users_section"
require "y2users/autoinst_profile/groups_section"
require "y2users/autoinst_profile/login_settings_section"
require "y2users/autoinst_profile/user_defaults_section"

module Y2Users
  module Autoinst
    # This reader builds a Y2Users::Config from an AutoYaST profile hash
    #
    # Reads the following sections of the profile: <users>, <groups>, <login_settings> and
    # <user_defaults>. Some attributes of the latter are ignored, since they only exist for
    # historical reasons. See {#read} for some background.
    class Reader
      include Yast::Logger
      include Yast::I18n

      # @param content [Hash] Hash containing AutoYaST data
      # @option content [Hash] "users" List of users
      # @option content [Hash] "groups" List of groups
      def initialize(content)
        textdomain "users"

        @users_section = Y2Users::AutoinstProfile::UsersSection.new_from_hashes(
          content["users"] || []
        )
        @groups_section = Y2Users::AutoinstProfile::GroupsSection.new_from_hashes(
          content["groups"] || []
        )
        @user_defaults_section = Y2Users::AutoinstProfile::UserDefaultsSection.new_from_hashes(
          content["user_defaults"] || {}
        )
        return unless content["login_settings"]

        @login_settings_section = Y2Users::AutoinstProfile::LoginSettingsSection.new_from_hashes(
          content["login_settings"]
        )
      end

      # Generates a new config with the information from the AutoYaST profile, that includes the
      # lists of users and groups and also the login settings and the useradd configuration.
      #
      # The configuration historically managed by YaST and exposed by the <user_defaults> section of
      # the profile goes beyond what is supported by the current configuration of useradd that is
      # represented by the UseraddConfig class. It was considered to create a UserDefaults class to
      # represent that extended configuration (see https://github.com/yast/yast-users/pull/298), but
      # the idea was discarded after testing the real behavior of AutoYaST regarding creation of
      # initial users in SLE-11-SPX, SLE-12-SPX and SLE-15-SPX.
      #
      # The "groups" and "no_groups" entries in the <user_defaults> section of the AutoYaST profile
      # were used to specify a list of secondary groups to which all new users should be added
      # during its creation. There is no counterpart in the useradd configuration because the
      # corresponding key GROUPS was dropped from the useradd configuration with no substitute when
      # the package "pwdutils" was dropped in favor of "shadow" (see more at bsc#1099153). Even if
      # the GROUPS key is present in /etc/default/useradd, its value will be completely ignored by
      # useradd and by YaST. Moreover, manual testing has proved that AutoYaST has ignored that list
      # at least since SLE-11. It used to write the list into /etc/default/useradd for later usage
      # (YaST used that list to pre-fill the corresponding field in the user interface) but it
      # didn't add the new users to the groups.
      #
      # The "skel" entry was used to specify a custom skeleton directory. But, for reasons explained
      # in the documentation of {UseraddConfig}, there is no setter in that class to write the value
      # of the "skel" option and make it persistent in the useradd configuration of the final
      # system. And specifying an alternative skel that would only be honored by AutoYaST during the
      # installation of the system is not much useful (it's very unlikely to have a custom skel at
      # that point). Thus, the entry in the AutoYaST profile is ignored.
      #
      # @return [Y2Users::ReadResult] Configuration and issues that were found
      def read
        issues = Y2Issues::List.new
        config = Config.new.tap do |cfg|
          read_elements(cfg, issues)
          read_login(cfg)
          read_user_defaults(cfg)
        end
        issues.concat(CollisionChecker.new(config).issues)
        Y2Users::ReadResult.new(config, issues)
      end

    private

      # Group password values that actually means "no password".
      #
      # Although YaST does not support group passwords anymore and ignores them when importing the
      # profile, the user receives a warning about it ONLY when found a `<group_password>` with none
      # of these values, which means *no password*.
      #
      # @see #check_group_password
      BLANK_GROUP_PASSWORD = ["", "x", "*", "!"].freeze
      private_constant :BLANK_GROUP_PASSWORD

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
      # @return [AutoinstProfile::LoginSettingsSection]
      attr_reader :login_settings_section

      # Profile section describing the default configuration for new users
      #
      # @return [AutoinstProfile::UserDefaultsSection]
      attr_reader :user_defaults_section

      # Reads users and groups from the AutoYaST profile
      #
      # @param config [Config]
      # @param issues [Y2Issues::List] Issues list
      def read_elements(config, issues)
        elements = read_users(issues) + read_groups(issues)

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

      def read_users(issues)
        users_section.users.each_with_object([]) do |user_section, users|
          next unless check_user(user_section, issues)

          res = User.new(user_section.username)
          res.gecos = [user_section.fullname]
          # TODO: handle forename/lastname
          res.gid = user_section.gid
          res.home = Home.new(user_section.home)
          res.home.btrfs_subvol = user_section.home_btrfs_subvolume
          res.shell = user_section.shell
          res.uid = user_section.uid
          res.password = create_password(user_section)
          res.authorized_keys = user_section.authorized_keys
          users << res
        end
      end

      def read_groups(issues)
        groups_section.groups.each_with_object([]) do |group_section, groups|
          next unless check_group(group_section, issues)

          check_group_password(group_section, issues)

          res = Group.new(group_section.groupname)
          res.gid = group_section.gid
          users_name = group_section.userlist.to_s.split(",")
          res.users_name = users_name
          res.source = :local
          groups << res
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

        last_change = shadow_date_field_value(password_settings.last_change)
        expire = shadow_date_field_value(password_settings.expire)

        password.aging = PasswordAging.new(last_change) if last_change
        password.minimum_age = password_settings.min
        password.maximum_age = password_settings.max
        password.warning_period = password_settings.warn
        password.inactivity_period = password_settings.inact
        password.account_expiration = AccountExpiration.new(expire) if expire
        password
      end

      # Validates the user and adds the problems found to the given issues list
      #
      # @param user_section [Y2Users::AutoinstProfile::UserSection] User section from the profile
      # @param issues [Y2Issues::List] Issues list
      # @return [Boolean] true if the user is valid; false otherwise.
      def check_user(user_section, issues)
        return true if user_section.username && !user_section.username.empty?

        issues << invalid_value_issue(user_section, :username)
        false
      end

      # Validates the group and adds the problems found to the given issues list
      #
      # @param group_section [Y2Users::AutoinstProfile::GroupSection] User section from the profile
      # @param issues [Y2Issues::List] Issues list
      # @return [Boolean] true if the group is valid; false otherwise.
      def check_group(group_section, issues)
        return true if group_section.groupname && !group_section.groupname.empty?

        issues << invalid_value_issue(group_section, :groupname)
        false
      end

      # Check if given group contains a group password for warning about ignoring it
      #
      # @param group_section [Installation::AutoinstProfile::GroupSection]
      # @param issues [Y2Issues::List] Issues list
      def check_group_password(group_section, issues)
        group_password = group_section.group_password.to_s

        return if BLANK_GROUP_PASSWORD.include?(group_password)

        issues << Y2Issues::Issue.new(
          _("Attribute no longer supported by YaST. Ignoring it."),
          location: "autoyast:#{group_section.section_path}:group_password"
        )
      end

      # Helper method that returns an InvalidValue issue for the given section and attribute
      #
      # @param section [Installation::AutoinstProfile::SectionWithAttributes]
      # @param attr [Symbol]
      # @return [Y2Issues::InvalidValue]
      def invalid_value_issue(section, attr)
        Y2Issues::InvalidValue.new(
          section.send(attr), location: "autoyast:#{section.section_path}:#{attr}"
        )
      end

      # Generates the correct value for a shadow field that can represent a date
      #
      # @param value [String, nil]
      # @return [Date, String, nil]
      def shadow_date_field_value(value)
        value.to_s.empty? ? value : Date.parse(value)
      end

      # Creates a {UseraddConfig} object based on the information in the profile
      #
      # @param config [Config]
      def read_user_defaults(config)
        config.useradd = UseraddConfig.new(
          group:             user_defaults_section.group,
          home:              user_defaults_section.home,
          expiration:        user_defaults_section.expire,
          inactivity_period: user_defaults_section.inactive,
          shell:             user_defaults_section.shell,
          umask:             user_defaults_section.umask
        )
      end
    end
  end
end
