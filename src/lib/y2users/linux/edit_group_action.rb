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
require "y2users/linux/action"

module Y2Users
  module Linux
    # Action for editing an existing group
    class EditGroupAction < Action
      include Yast::I18n
      include Yast::Logger

      # Constructor
      #
      # @see Action
      def initialize(initial_group, target_group, commit_config = nil)
        textdomain "users"

        super(target_group, commit_config)

        @initial_group = initial_group
      end

    private

      alias_method :group, :action_element

      # Initial state of the group
      #
      # It is used to calculate the changes to apply over the group.
      #
      # @return [Group]
      attr_reader :initial_group

      # Command for modifying groups
      GROUPMOD = "/usr/sbin/groupmod".freeze
      private_constant :GROUPMOD

      # @see Action#run_action
      #
      # Issues are generated when the group cannot be edited.
      def run_action
        options = groupmod_options
        Yast::Execute.on_target!(GROUPMOD, *options, initial_group.name) if options.any?
        true
      rescue Cheetah::ExecutionFailed => e
        issues << Y2Issues::Issue.new(
          # TRANSLATORS: %{group} is replaced by a group name
          format(_("The group %{group} could not be modified"), group: initial_group.name)
        )
        log.error("Error modifying group #{initial_group.name}: #{e.stderr}")
        false
      end

      # Generates options for `groupmod` according to the changes in the group
      #
      # @return [Array<String>]
      def groupmod_options
        opts = []
        opts += ["--new-name", group.name] if group.name && group.name != initial_group.name
        opts += ["--gid", group.gid] if group.gid && group.gid != initial_group.gid

        opts
      end
    end
  end
end
