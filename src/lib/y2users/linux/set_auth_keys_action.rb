# Copyright (c) [2021-2023] SUSE LLC
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
require "yast/i18n"
require "y2issues/issue"
require "users/ssh_authorized_keyring"
require "y2users/linux/action"

module Y2Users
  module Linux
    # Action for setting the authorized keys of a user
    class SetAuthKeysAction < Action
      include Yast::I18n
      include Yast::Logger

      # Constructor
      #
      # @see Action
      # @param user [User] user to perform the action
      # @param previous_keys [Array<String>] optional collection holding previous SSH keys, if any
      def initialize(user, previous_keys = [])
        textdomain "users"

        super(user)
        @previous_keys = previous_keys || []
      end

    private

      # @return [Array<String>] collection holding previous SSH public keys for given user
      attr_reader :previous_keys

      alias_method :user, :action_element

      # @see Action#run_action
      #
      # Issues are generated when the authorized keys cannot be set.
      def run_action
        keyring = Yast::Users::SSHAuthorizedKeyring.new(user.home.path, previous_keys)
        keyring.add_keys(user.authorized_keys)
        keyring.write_keys
        true
      rescue Yast::Users::SSHAuthorizedKeyring::PathError => e
        issues << Y2Issues::Issue.new(
          # TRANSLATORS: %s is a placeholder for a username
          format(_("Error writing authorized keys for '%s'"), user.name)
        )
        log.error("Error writing authorized keys for '#{user.name}' - #{e.message}")
        false
      end
    end
  end
end
