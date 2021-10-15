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
require "y2users/linux/action_writer"
require "y2users/linux/delete_group_action"
require "y2users/linux/create_group_action"
require "y2users/linux/edit_group_action"

module Y2Users
  module Linux
    # Writes groups to the system using standard Linux tools.
    #
    # @note: this is not meant to be used directly, but to be used by the general {Linux::Writer}
    class GroupsWriter < ActionWriter
      include Yast::I18n
      include Yast::Logger

      # Constructor
      #
      # @param target_config [Config] see #target_config
      # @param initial_config [Config] see #initial_config
      def initialize(target_config, initial_config)
        textdomain "users"

        @initial_config = initial_config
        @target_config = target_config
      end

    private

      # Initial state of the system (usually a Y2Users::Config.system in a running system) that will
      # be compared with {#target_config} to know what changes need to be performed.
      #
      # @return [Config]
      attr_reader :initial_config

      # Configuration containing the users and groups that should exist in the system after writing
      #
      # @return [Config]
      attr_reader :target_config

      # Performs the changes in the system in order to create, edit or delete groups according to
      # the configs.
      #
      # @see ActionWriter
      def actions
        delete_groups
        edit_groups
        add_groups
      end

      # Deletes groups
      def delete_groups
        deleted_groups.each { |g| delete_group(g) }
      end

      # Performs the action for deleting a group
      #
      # @param group [Group]
      # @return [Boolean] true on success
      def delete_group(group)
        action = DeleteGroupAction.new(group)

        perform_action(action)
      end

      # Creates the new groups
      def add_groups
        new_groups.each { |g| add_group(g) }
      end

      # Performs the action for creating a new group
      #
      # @param group [Group]
      # @return [Boolean] true on success
      def add_group(group)
        action = CreateGroupAction.new(group)

        perform_action(action)
      end

      # Edits the groups
      def edit_groups
        edited_groups.each do |group|
          initial_group = initial_config.groups.by_id(group.id)
          edit_group(initial_group, group)
        end
      end

      # Performs the action for editing a group
      #
      # @param initial_group [Group]
      # @param target_group [Group]
      #
      # @return [Boolean] true on success
      def edit_group(initial_group, target_group)
        action = EditGroupAction.new(initial_group, target_group)

        perform_action(action)
      end

      # Groups that should be deleted
      #
      # @return [Array<Group>]
      def deleted_groups
        initial_config.groups.without(target_config.groups.ids).all
      end

      # Groups that should be created
      #
      # @return [Array<Group>]
      def new_groups
        groups = target_config.groups.without(initial_config.groups.map(&:id))
        # empty string to process groups without gid the last
        groups.all.sort_by! { |g| g.gid || "" }.reverse
      end

      # Groups that should be edited
      #
      # @return [Array<Group>]
      def edited_groups
        target_config.groups.changed_from(initial_config.groups).all
      end
    end
  end
end
