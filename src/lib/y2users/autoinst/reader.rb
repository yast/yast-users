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
      # @return [Config]
      def read
        elements = read_users + read_groups
        Config.new.attach(elements)
      end

    private

      attr_reader :users_section, :groups_section

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

      # shadow attrs without password and username which is done manually
      SORTED_SHADOW_ATTRS = [
        # Looks like shadow last change is not part of User.Export TODO: verify
        "last_change", "min", "max", "warn", "inact", "expire", "flag"
      ].freeze

      # Creates a {Password} object based on the data structure of a user
      #
      # @param user [Hash] a user representation in the format used by Users.Export
      # @return [Password]
      def create_password(user)
        parser = Parsers::Shadow.new
        content = shadow_string(user)

        password = parser.parse(content).values.first
        password.value = PasswordPlainValue.new(user.user_password) unless user.encrypted
        password
      end

      # Entry in /etc/shadow describing the password of the given user
      #
      # @param user [Hash] a user representation in the format used by UsersSimple
      # @return [String]
      def shadow_string(user)
        other_attrs = if user.password_settings
          SORTED_SHADOW_ATTRS.map { |a| user.password_settings.send(a) || "" }
        else
          []
        end

        [user.username, user.user_password, *other_attrs].join(":")
      end
    end
  end
end
