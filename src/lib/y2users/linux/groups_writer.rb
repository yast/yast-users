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
    # Writes groups to the system using Yast2::Execute and standard linux tools.
    #
    # @note: this is not meant to be used directly, but to be used by the general {Linux::Writer}
    class GroupsWriter
      include Yast::I18n
      include Yast::Logger

      # Constructor
      #
      # @param config [Config] see #config
      # @param initial_config [Config] see #initial_config
      def initialize(config, initial_config)
        textdomain "users"

        @config = config
        @initial_config = initial_config
      end

      # Creates the new groups
      #
      # @param issues [Y2Issues::List] the list of issues found while writing changes
      def add_groups(issues)
        new_groups = (config.groups.map(&:id) - initial_config.groups.map(&:id))
        new_groups.map! { |id| config.groups.find { |g| g.id == id } }
        # empty string to process groups without gid the last
        new_groups.sort_by! { |g| g.gid || "" }.reverse!
        new_groups.each { |g| add_group(g, issues) }
      end

    private

      # Configuration containing the users and groups that should exist in the system after writing
      #
      # @return [Config]
      attr_reader :config

      # Initial state of the system (usually a Y2Users::Config.system in a running system) that will
      # be compared with {#config} to know what changes need to be performed.
      #
      # @return [Config]
      attr_reader :initial_config

      # Command for creating new users
      GROUPADD = "/usr/sbin/groupadd".freeze
      private_constant :GROUPADD

      # Executes the command for creating the group
      #
      # @param group [Group] the group to be created on the system
      # @param issues [Y2Issues::List] a collection for adding an issue if something goes wrong
      def add_group(group, issues)
        args = []
        args << "--non-unique" << "--gid" << group.gid if group.gid
        args << group.name
        # TODO: system groups?
        Yast::Execute.on_target!(GROUPADD, *args)
      rescue Cheetah::ExecutionFailed => e
        issues << Y2Issues::Issue.new(
          format(_("The group '%{groupname}' could not be created"), groupname: group.name)
        )
        log.error("Error creating group '#{group.name}' - #{e.message}")
      end
    end
  end
end
