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
require "yast2/execute"
require "y2issues/issue"
require "y2users/linux/action"

module Y2Users
  module Linux
    # Action for deleting the user password
    class DeleteUserPasswordAction < Action
      include Yast::I18n
      include Yast::Logger

      # Constructor
      #
      # @see Action
      def initialize(user)
        textdomain "users"

        super
      end

    private

      alias_method :user, :action_element

      # Command for editing a password (i.e., used for deleting the password)
      PASSWD = "/usr/bin/passwd".freeze
      private_constant :PASSWD

      # @see Action#run_action
      #
      # Issues are generated when the password cannot be deleted
      def run_action
        Yast::Execute.on_target!(PASSWD, "--delete", user.name)
        true
      rescue Cheetah::ExecutionFailed => e
        issues << Y2Issues::Issue.new(
          # TRANSLATORS: %s is a placeholder for a username
          format(_("The password for '%s' cannot be deleted"), user.name)
        )
        log.error("Error deleting password for '#{user.name}' - #{e.message}")
        false
      end
    end
  end
end
