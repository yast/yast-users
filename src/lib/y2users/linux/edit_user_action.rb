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
    class EditUserAction < UserAction
      include Yast::I18n
      include Yast::Logger

      # Constructor
      def initialize(initial_user, target_user, commit_config = nil)
        textdomain "users"

        super(target_user, commit_config)

        @initial_user = initial_user
      end

    private

      attr_reader :initial_user

      # Command for modifying users
      USERMOD = "/usr/sbin/usermod".freeze
      private_constant :USERMOD

      # Edits the user
      def run_action(issues)
        return true if user == initial_user

        edit_user(issues)
      end

      # Applies changes in the user by calling to usermod command
      #
      # @return [Boolean] true on success; false otherwise
      def edit_user(issues)
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

      # Command to modify the user
      #
      # @return [Array<String>] usermod options
      # rubocop:disable Metrics/CyclomaticComplexity
      # rubocop:disable Metrics/AbcSize
      # rubocop:disable Metrics/PerceivedComplexity
      def usermod_options
        args = []
        args << "--login" << user.name if user.name != initial_user.name && user.name
        args << "--uid" << user.uid if user.uid != initial_user.uid && user.uid
        args << "--gid" << user.gid if user.gid != initial_user.gid && user.gid
        args << "--comment" << user.gecos.join(",") if user.gecos != initial_user.gecos

        # With the --home option, the home path of the user is updated in the passwd file, but the
        # home is not created. The only ways to create a new home for an existing user is:
        #   * reusing an existing directory/subvolume
        #   * moving the current home to a new path (see --move-home option below)
        # Creating the home directory/subvolume of an existing user is not supported by the shadow
        # tools.
        if user.home&.path && user.home.path != initial_user.home&.path
          args << "--home" << user.home.path
        end

        # With the --move-home option, all the content from the previous home directory is moved to
        # the new location, and ownership is also adapted. But take into account that the new home
        # will be created only if the old home directory exists. Otherwise, the user will continue
        # without a home directory. Also note that if the new home already exists, then the content
        # of the old home is not moved neither.
        args << "--move-home" if commit_config&.move_home? && args.include?("--home")

        args << "--shell" << user.shell if user.shell != initial_user.shell && user.shell

        if different_groups?(user, initial_user)
          args << "--groups" << user.secondary_groups_name.join(",")
        end

        args
      end
      # rubocop:enable Metrics/CyclomaticComplexity
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/PerceivedComplexity

      # Whether the users have different groups
      #
      # @param user1 [User]
      # @param user2 [User]
      #
      # @return [Boolean]
      def different_groups?(user1, user2)
        sorted_groups(user1) != sorted_groups(user2)
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
