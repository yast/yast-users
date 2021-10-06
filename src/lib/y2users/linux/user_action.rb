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

require "y2issues/list"
require "y2users/linux/action_result"
require "abstract_method"

module Y2Users
  module Linux
    class UserAction
      # Constructor
      def initialize(user, commit_config = nil)
        @user = user
        @commit_config = commit_config
      end

      # Executes the commands to perform the action
      #
      # @return [Boolean] true on success
      def perform
        @issues = Y2Issues::List.new

        run_action
      end

    private

      attr_reader :user

      attr_reader :commit_config

      attr_reader :issues

      abstract_method :run_action

      def result(success)
        ActionResult.new(success, issues)
      end
    end
  end
end
