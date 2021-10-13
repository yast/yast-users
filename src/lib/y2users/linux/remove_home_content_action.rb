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
require "y2users/linux/user_action"

module Y2Users
  module Linux
    # Action for removing the content of the user home
    #
    # Note that this action is not intended to remove the home itself, but only its content.
    # Basically, this action exists to supply the use case of creating a home without skel files,
    # which is not currently supported by the shadow tools.
    class RemoveHomeContentAction < UserAction
      include Yast::I18n
      include Yast::Logger

      # Constructor
      #
      # @see UserAction
      def initialize(user, commit_config = nil)
        textdomain "users"

        super
      end

    private

      # Command for finding files
      FIND = "/usr/bin/find".freeze
      private_constant :FIND

      # @see UserAction#run_action
      #
      # Removes the content of the user home, even the hidden files.
      #
      # Issues are generated when the home cannot be cleaned up.
      def run_action
        Yast::Execute.on_target!(FIND, user.home.path, "-mindepth", "1", "-delete")
        true
      rescue Cheetah::ExecutionFailed => e
        issues << Y2Issues::Issue.new(
          format(_("Cannot clean up '%s'"), user.home.path)
        )
        log.error("Error cleaning up '#{user.home.path}' - #{e.message}")
        false
      end
    end
  end
end
