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
    # Action for editing an existing user
    class EditUserAction < Action
      include Yast::I18n
      include Yast::Logger

      # Constructor
      #
      # @see Action
      def initialize(initial_user, target_user, commit_config = nil)
        textdomain "users"

        super(target_user, commit_config)

        @initial_user = initial_user
      end

    private

      alias_method :user, :action_element

      # Initial state of the user
      #
      # It is used to calculate the changes to apply over the user.
      #
      # @return [User]
      attr_reader :initial_user

      # Command for modifying users
      USERMOD = "/usr/sbin/usermod".freeze
      private_constant :USERMOD

      # @see Action#run_action
      #
      # Issues are generated when the user cannot be edited.
      def run_action
        options = usermod_options
        Yast::Execute.on_target!(USERMOD, *options, initial_user.name) if options.any?
        true
      rescue Cheetah::ExecutionFailed => e
        issues << Y2Issues::Issue.new(
          format(_("The user '%{username}' could not be modified"), username: initial_user.name)
        )
        log.error("Error modifying user '#{initial_user.name}' - #{e.message}")
        false
      end

      # Generates options for `usermod` according to the changes in the user
      #
      # @return [Array<String>]
      def usermod_options
        user_options + home_options
      end

      # Options from the user attributes
      #
      # @return [Array<String>]
      def user_options
        opts = {
          name:  ["--login", user.name],
          uid:   ["--uid", user.uid],
          gid:   ["--gid", user.gid],
          shell: ["--shell", user.shell],
          gecos: ["--comment", user.gecos.join(",")]
        }

        opts = opts.select { |k, _| new_value_for?(k) }.values.flatten

        opts += ["--groups", user.secondary_groups_name.join(",")] if different_groups?

        opts
      end

      # Options to deal with home
      #
      # @return [Array<String>]
      def home_options
        opts = []

        # With the --home option, the home path of the user is updated in the passwd file, but the
        # home is not created. The only ways to create a new home for an existing user is:
        #   * reusing an existing directory/subvolume
        #   * moving the current home to a new path (see --move-home option below)
        # Creating the home directory/subvolume of an existing user is not supported by the shadow
        # tools.
        if user.home&.path && user.home.path != initial_user.home&.path
          opts << "--home" << user.home.path
        end

        # With the --move-home option, all the content from the previous home directory is moved to
        # the new location, and ownership is also adapted. But take into account that the new home
        # will be created only if the old home directory exists. Otherwise, the user will continue
        # without a home directory. Also note that if the new home already exists, then the content
        # of the old home is not moved neither.
        opts << "--move-home" if commit_config&.move_home? && opts.include?("--home")

        opts
      end

      # Whether there is a new value for the given user attribute
      #
      # @param attr [Symbol]
      # @return [Boolean]
      def new_value_for?(attr)
        return false unless user.public_send(attr)

        user.public_send(attr) != initial_user.public_send(attr)
      end

      # Whether the users have different groups
      #
      # @return [Boolean]
      def different_groups?
        sorted_groups(user) != sorted_groups(initial_user)
      end

      # Groups of a user, sorted by id
      #
      # @param user [User]
      # @return [Array<Group>]
      def sorted_groups(user)
        user.groups(with_primary: false).sort_by(&:id)
      end
    end
  end
end
