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

Yast.import "UsersSimple"

module Y2Users
  module UsersSimple
    # Class for writing users configuration into the old UsersSimple Yast Module
    class Writer
      # Constructor
      #
      # @param config [Config]
      def initialize(config)
        @config = config
      end

      # Stores all users from {#config} into the UsersSimple module
      #
      # UsersSimple module is not expected to contain the root user in its list of users. It
      # provides separate attributes in order to store the root user info (e.g., root_password or
      # root_public_key).
      def write
        users_simple = config.users.reject(&:root?).map { |u| to_user_simple(u) }
        Yast::UsersSimple.SetUsers(users_simple)

        root = config.users.find(&:root?)
        return unless root

        Yast::UsersSimple.SetRootPassword(root.password.value.content) if root.password&.value&.plain?
      end

    private

      # @return [Config]
      attr_reader :config

      # Converts an {User} object into an user hash as UsersSimple module expects
      #
      # @param user [User]
      # @return [Hash]
      def to_user_simple(user)
        # TODO: users simple allows encrypted, but then it needs to specify _encrypted => true
        password = user.password&.value&.content if user.password&.value&.plain?
        {
          uid:           user.name,
          uidNumber:     user.uid,
          gidNumber:     user.gid,
          loginShell:    user.shell,
          homeDirectory: user.home,
          cn:            user.full_name,
          userPassword:  user.password&.value&.content
        }
      end
    end
  end
end
