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
require "y2users/linux/root_path"

module Y2Users
  module Linux
    # Action for creating a new group
    class CreateGroupAction < Action
      include Yast::I18n
      include Yast::Logger
      include RootPath

      # Constructor
      #
      # @see Action
      def initialize(group, root_path: nil)
        textdomain "users"

        super(group)
        @root_path = root_path
      end

    private

      alias_method :group, :action_element

      # Command for creating new groups
      GROUPADD = "/usr/sbin/groupadd".freeze
      private_constant :GROUPADD

      # @see Action#run_action
      #
      # Issues are generated when the group cannot be created.
      def run_action
        Yast::Execute.on_target!(GROUPADD, *groupadd_options)
        true
      rescue Cheetah::ExecutionFailed => e
        issues << Y2Issues::Issue.new(
          # TRANSLATORS: %{group} is replaced by a group name.
          format(_("The group %{group} could not be created"), group: group.name)
        )
        log.error("Error creating group #{group.name}: #{e.stderr}")
        false
      end

      # Generates options for `groupadd` according to the group attributes
      #
      # @return [Array<String>]
      def groupadd_options
        opts = root_path_options
        opts += ["--non-unique", "--gid", group.gid] if group.gid
        opts << "--system" if group.system?
        opts << group.name

        opts
      end
    end
  end
end
