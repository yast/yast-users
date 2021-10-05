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
require "y2issues/with_issues"
require "y2users/commit_config"
require "y2users/linux/create_user_action"
require "y2users/linux/edit_user_action"
require "y2users/linux/set_password_action"
require "y2users/linux/delete_password_action"
require "y2users/linux/remove_home_content_action"
require "y2users/linux/set_home_ownership_action"

Yast.import "MailAliases"

module Y2Users
  module Linux
    # Writes users to the system using Yast2::Execute and standard linux tools.
    #
    # @note: this is not meant to be used directly, but to be used by the general {Linux::Writer}
    class UsersWriter
      include Yast::Logger
      include Y2Issues::WithIssues

      # Constructor
      #
      # @param config [Config] see #config
      # @param initial_config [Config] see #initial_config
      # @param commit_configs [CommitConfigCollection]
      def initialize(target_config, initial_config, commit_configs)
        @initial_config = initial_config
        @target_config = target_config
        @commit_configs = commit_configs
        @root_aliases = []
      end

      # Performs the changes in the system in order to create, edit or delete users according to
      # the differences between the initial and the target configs. Commit actions can be addressed
      # with the commit configs, see {CommitConfig}.
      #
      # TODO: delete users
      #
      # @return [Y2Issues::List] the list of issues found while writing changes; empty when none
      def write
        with_issues do |issues|
          add_users(issues)
          edit_users(issues)
          # issues.concat(delete_users)
          # issues.concat(update_root_aliases)
        end
      end

      # Update root aliases
      #
      # @return [Y2Issues::List] a list holding an issue if Yast::MailAliases#SetRootAlias fails
      def update_root_aliases
        with_issues do |issues|
          result = Yast::MailAliases.SetRootAlias(root_aliases.join(", "))

          unless result
            issues << Y2Issues::Issue.new(_("Error setting root mail aliases"))
            log.error("Error root mail aliases")
          end
        end
      end

    private

      # Initial state of the system (usually a Y2Users::Config.system in a running system) that will
      # be compared with {#config} to know what changes need to be performed.
      #
      # @return [Config]
      attr_reader :initial_config

      # Configuration containing the users and groups that should exist in the system after writing
      #
      # @return [Config]
      attr_reader :target_config

      # Collection of commit configs to address the commit actions to perform for each user
      #
      # @return [CommitConfigCollection]
      attr_reader :commit_configs

      # Collection holding names of users set to receive system mail (i.e., to be aliases of root)
      #
      # @return [Array<User>]
      attr_accessor :root_aliases

      # Creates the new users
      #
      # @return [Y2Issues::List] the list of issues found while creating users; empty when none
      def add_users(issues)
        sorted_users.each { |u| add_user(u, issues) }
      end

      # Performs all needed actions in order to create and configure a new user (create user, set
      # password, etc).
      #
      # @param user [User] the user to be created on the system
      # @param issues [Y2Issues::List] a collection for adding an issue if something goes wrong
      def add_user(user, issues)
        reusing_home = exist_user_home?(user)

        return unless create_user(user, issues)

        commit_config = commit_config(user)
        remove_home_content(user, issues) if !reusing_home && commit_config.home_without_skel?
        set_home_ownership(user, issues) if commit_config.adapt_home_ownership?
        set_password(user, issues) if user.password
        set_auth_keys(user, issues)

        root_aliases << user.name if user.receive_system_mail?
      end

      # Applies changes for the edited users
      #
      # @return [Y2Issues::List] the list of issues found while editing users; empty when none
      def edit_users(issues)
        edited_users.each do |user|
          initial_user = initial_config.users.by_id(user.id)
          edit_user(initial_user, target_user, issues)
        end
      end

      # Edits the user
      #
      # @param new_user [User] User containing the updated information
      # @param old_user [User] Original user
      # @param issues [Y2Issues::List] a collection for adding an issue if something goes wrong
      def edit_user(initial_user, target_user, issues)
        return if target_user == initial_user

        return unless modify_user(initial_user, target_user, issues)

        commit_config = commit_config(target_user)
        set_home_ownership(target_user, issues) if commit_config.adapt_home_ownership?
        edit_password(target_user, issues) if initial_user.password != target_user.password

        return if initial_user.authorized_keys == target_user.authorized_keys
        set_auth_keys(target_user, issues)
      end

      def new_users
        new_users = target_config.users.without(initial_config.users.ids)
        # empty string to process users without uid the last
        sorted_users = new_users.all.sort_by { |u| u.uid || "" }.reverse
      end

      def edited_users
        target_config.users.changed_from(initial_config.users)
      end

      # Creates a new user
      #
      # Issues are generated when the user cannot be created.
      #
      # @see #add_user
      #
      # @param user [User] the user to be created on the system
      # @param issues [Y2Issues::List] a collection for adding an issue if something goes wrong
      def create_user(user, issues)
        action = CreateUserAction.new(user, commit_config(user))

        perform_action(action, issues)
      end

      def modify_user(initial_user, target_user, issues)
        action = EditUserAction.new(initial_user, target_user, commit_config(user))

        perform_action(action, issues)
      end

      # Edits the user's password
      #
      # @param user [User] User containing the updated information
      # @param issues [Y2Issues::List] a collection for adding an issue if something goes wrong
      def edit_password(user, issues)
        user.password ? set_password(user, issues) : delete_password(user, issues)
      end

      def set_password(user, issues)
        action = SetUserPasswordAction.new(user, commit_config(user))

        perform_action(action, issues)
      end

      def delete_password(user, issues)
        action = DeleteUserPasswordAction.new(user, commit_config(user))

        perform_action(action, issues)
      end

      # Clear the content of the home directory/subvolume for the given user
      #
      # Issues are generated when the home cannot be cleaned up.
      #
      # @param user [User]
      # @param issues [Y2Issues::List] new issues can be added
      def remove_home_content(user, issues)
        return true unless exist_user_home?(user)

        action = RemoveHomeContentAction.new(user, commit_config(user))

        perform_action(action, issues)
      end

      def set_home_ownership(user, issues)
        return true unless exist_user_home?(user)

        action = SetHomeOwnershipAction.new(user, commit_config(user))

        perform_action(action, issues)
      end

      def set_auth_keys(user, issues)
        return true unless user.home

        action = SetAuthKeysAction.new(user, commit_config(user))

        perform_action(action, issues)
      end

      def perform_action(action, issues)
        success = action.perform
        issues.concat(action.issues)

        success
      end

      # Commit actions for a specific user
      #
      # @param user [User] Note that the commit config of a user is found by the user name. Due to
      #   the user name can change, always use the user from the target config.
      # @return [CommitConfig] commit config for the given user or a new commit config if there is
      #   no config for that user.
      def commit_config(user)
        commit_configs.by_username(user.name) || CommitConfig.new
      end

      # Whether the home directory/subvolume of the given user exists on disk
      #
      # @param user [User]
      # @return [Boolean]
      def exist_user_home?(user)
        return false unless user.home&.path

        File.exist?(user.home.path)
      end
    end
  end
end
