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

require "y2issues/list"
require "y2users/linux/action_result"
require "abstract_method"

module Y2Users
  module Linux
    # Abstract base class for actions over the system (e.g., create a user, delete a group, etc)
    #
    # Derived classes must implement #run_action method.
    #
    # @example
    #   class ActionTest < Action
    #     def run_action
    #       print("test")
    #       true
    #     end
    #   end
    #
    #   action = ActionTest.new(user, commit_action)
    #   result = action.perform
    #   result.success?       #=> true
    #   result.issues.empty?  #=> true
    class Action
      # Constructor
      #
      # @param action_element [Object] object to perform the action (e.g., a user)
      # @param commit_config [UserCommitConfig, nil] optional configuration for the commit
      def initialize(action_element, commit_config = nil)
        @action_element = action_element
        @commit_config = commit_config
      end

      # Performs the action
      #
      # @return [ActionResult] result of performing the action
      def perform
        @issues = Y2Issues::List.new

        result(run_action)
      end

    private

      # @return [Object]
      attr_reader :action_element

      # @return [UserCommitConfig]
      attr_reader :commit_config

      # Issues generated while performing the action
      #
      # @return [Y2Issues::List]
      attr_reader :issues

      # Executes the needed actions
      #
      # This method is expected to generate issues if something goes wrong, see {#issues}.
      #
      # @return [Boolean] true on success
      abstract_method :run_action

      # Generates an action result, containing the issues generated while performing the action, see
      # {#issues}.
      #
      # @param success [Boolean] whether the result was successful
      # @return [ActionResult]
      def result(success)
        ActionResult.new(success, issues)
      end
    end
  end
end
