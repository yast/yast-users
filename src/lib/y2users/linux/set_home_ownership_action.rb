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

module Y2Users
  module Linux
    class SetHomeOwnershipAction < UserAction
      include Yast::I18n
      include Yast::Logger

      # Constructor
      def initialize(user, commit_config = nil)
        textdomain "users"

        super
      end

    private

      # Command for changing ownership
      CHOWN = "/usr/bin/chown".freeze
      private_constant :CHOWN

      # Changes ownership of the home directory/subvolume for the given user
      #
      # Issues are generated when ownership cannot be changed.
      def run_action(issues)
        owner = user.name.dup
        owner << ":#{user.gid}" if user.gid

        Yast::Execute.on_target!(CHOWN, "-R", owner, user.home.path)
        true
      rescue Cheetah::ExecutionFailed => e
        issues << Y2Issues::Issue.new(
          format(_("Cannot change ownership of '%s'"), user.home.path)
        )
        log.error("Error changing ownership of '#{user.home.path}' - #{e.message}")
        false
      end
    end
  end
end
