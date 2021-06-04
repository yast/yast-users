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
require "y2users/autoinst_profile/users_section"
require "y2users/autoinst_profile/groups_section"
require "y2users/read_result"

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
      end

      # Generates a new config with the users and groups from the system
      #
      # @return [Y2Users::ReadResult] Configuration and issues that were found
      def read
        issues = Y2Issues::List.new
        elements = read_users(issues) + read_groups(issues)
        Y2Users::ReadResult.new(Config.new.attach(elements), issues)
      end

    private

      attr_reader :users_section, :groups_section

      def read_users(issues)
        users_section.users.each_with_object([]) do |user_section, users|
          next unless valid_user?(user_section, issues)

          res = User.new(user_section.username)
          res.gecos = [user_section.fullname]
          # TODO: handle forename/lastname
          res.gid = user_section.gid
          res.home = user_section.home
          res.shell = user_section.shell
          res.uid = user_section.uid
          res.password = create_password(user_section)
          users << res
        end
      end

      def read_groups(issues)
        groups_section.groups.each_with_object([]) do |group_section, groups|
          next unless valid_group?(group_section, issues)

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
      # @param user [Hash] a user representation in the format used by Users.Export
      # @return [Password,nil]
      def create_password(user)
        return nil unless user.user_password

        create_meth = user.encrypted ? :create_encrypted : :create_plain
        password = Password.send(create_meth, user.user_password)
        password_settings = user.password_settings
        return password unless password_settings

        password.aging = PasswordAging.new(password_settings.last_change)
        password.minimum_age = password_settings.min
        password.maximum_age = password_settings.max
        password.warning_period = password_settings.warn
        password.inactivity_period = password_settings.inact
        password.account_expiration = AccountExpiration.new(password_settings.expire)
        password
      end

      # Validates the user and adds the problems found to the given issues list
      #
      # @param user_section [Y2Users::AutoinstProfile::UserSection] User section from the profile
      # @param issues [Y2Issues::List] Issues list
      # @return [Boolean] true if the user is valid; false otherwise.
      def valid_user?(user_section, issues)
        return true if user_section.username && !user_section.username.empty?

        issues << invalid_value_issue(user_section, :username)
        false
      end

      # Validates the group and adds the problems found to the given issues list
      #
      # @param group_section [Y2Users::AutoinstProfile::GroupSection] User section from the profile
      # @param issues [Y2Issues::List] Issues list
      # @return [Boolean] true if the group is valid; false otherwise.
      def valid_group?(group_section, issues)
        return true if group_section.groupname && !group_section.groupname.empty?

        issues << invalid_value_issue(group_section, :groupname)
        false
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
    end
  end
end
