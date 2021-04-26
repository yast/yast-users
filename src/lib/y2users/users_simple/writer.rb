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
      def write
        users_simple = config.users.map { |u| to_user_simple(u) }
        Yast::UsersSimple.SetUsers(users_simple)
      end

    private

      # @return [Config]
      attr_reader :config

      # Converts an {User} object into an user hash as UsersSimple module expects
      #
      # @param user [User]
      # @return [Hash]
      def to_user_simple(user)
        {
          uid:           user.name,
          uidNumber:     user.uid,
          gidNumber:     user.gid,
          loginShell:    user.shell,
          homeDirectory: user.home,
          cn:            user.full_name,
          # TODO: Y2Users::Password class stores an encrypted password, but UsersSimple expects
          #   plain password.
          userPassword:  user.password.value
        }
      end
    end
  end
end
