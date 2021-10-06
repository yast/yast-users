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
require "yast/i18n"
require "yast2/execute"
require "y2issues/issue"

module Y2Users
  module Linux
    class DeleteUserAction < UserAction
      include Yast::I18n
      include Yast::Logger

      # Constructor
      def initialize(user, commit_config = nil)
        textdomain "users"

        super
      end

    private

      # Command for deleting a user
      USERDEL = "/usr/sbin/userdel".freeze
      private_constant :USERDEL

      # Executes the command for deleting the given user
      def run_action
        Yast::Execute.on_target!(USERDEL, *userdel_options, user.name)
        result(true)
      rescue Cheetah::ExecutionFailed => e
        issues << Y2Issues::Issue.new(
          # TRANSLATORS: %s is a placeholder for a username
          format(_("The user '%s' cannot be deleted"), user.name)
        )
        log.error("Error deleting user '#{user.name}' - #{e.message}")
        result(false)
      end

      def userdel_options
        options = []
        options << "--remove" if commit_config&.remove_home?

        options
      end
    end
  end
end
