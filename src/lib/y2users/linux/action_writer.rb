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
require "abstract_method"

module Y2Users
  module Linux
    # Abstract base class for writers that performs actions.
    #
    # @see UsersWriter
    class ActionWriter
      # Writes changes into the system
      #
      # @return [Y2Issues::List] the list of issues generated while writing changes; empty when none
      def write
        @issues = Y2Issues::List.new

        actions

        issues
      end

    private

      # Performs actions
      #
      # Derived classes must define this method.
      abstract_method :actions

      # Issues generated during the process
      #
      # @return [Y2Issues::List]
      attr_reader :issues

      # Performs the given action
      #
      # Issues can be generated while performing the action, see {#issues}.
      #
      # @param action [Action]
      # @return [Boolean] true on success
      def perform_action(action)
        result = action.perform
        issues.concat(result.issues)

        result.success?
      end
    end
  end
end
