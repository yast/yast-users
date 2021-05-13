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
require "y2users/shadow_date_helper"

Yast.import "UsersSimple"

module Y2Users
  module UsersSimple
    # Class for writing users configuration into the old UsersSimple Yast Module
    class Writer
      include ShadowDateHelper

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

        root_password = root.password&.value
        return unless root_password

        Yast::UsersSimple.SetRootPassword(root_password&.content)
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
          cn:            user.full_name
        }.merge(user_simple_password(user.password))
      end

      # Password-related fields for a user hash in the UsersSimple format
      #
      # @param password [Password]
      # @return [Hash]
      def user_simple_password(password)
        return {} if password.nil?

        {
          shadowMin:        password.minimum_age,
          shadowMax:        password.maximum_age,
          shadowWarning:    password.warning_period,
          shadowInactive:   password.inactivity_period,
          shadowLastChange: date_string(password.last_change),
          shadowExpire:     date_string(password.account_expiration)
        }.merge(password_value_attrs(password))
      end

      # @see #user_simple_password
      #
      # @param password [Password]
      # @return [Hash]
      def password_value_attrs(password)
        return {} unless password.value

        if password.value.plain?
          { userPassword: password.value.content }
        else
          {
            userPassword: password.value.content,
            encrypted:    true
          }
        end
      end

      # Converts dates to the string format used by UsersSimple
      #
      # @param date [Date]
      # @return [String]
      def date_string(date)
        return nil unless date

        # UsersSimple uses the same format than the shadow file
        date_to_shadow_string(date)
      end
    end
  end
end
