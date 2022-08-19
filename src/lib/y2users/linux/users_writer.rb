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
require "y2issues/issue"
require "y2users/commit_config"
require "y2users/linux/action_writer"
require "y2users/linux/create_user_action"
require "y2users/linux/edit_user_action"
require "y2users/linux/set_user_password_action"
require "y2users/linux/delete_user_password_action"
require "y2users/linux/remove_home_content_action"
require "y2users/linux/set_home_ownership_action"
require "y2users/linux/set_auth_keys_action"
require "y2users/linux/delete_user_action"
require "y2users/linux/reader"

Yast.import "MailAliases"

module Y2Users
  module Linux
    # Writes users to the system using standard Linux tools.
    #
    # @note: this is not meant to be used directly, but to be used by the general {Linux::Writer}
    class UsersWriter < ActionWriter
      include Yast::I18n
      include Yast::Logger
      include Yast::I18n

      # Constructor
      #
      # @param target_config [Config] see #target_config
      # @param initial_config [Config] see #initial_config
      # @param commit_configs [CommitConfigCollection]
      def initialize(target_config, initial_config, commit_configs)
        textdomain "users"

        @initial_config = initial_config
        @target_config = target_config
        @commit_configs = commit_configs
        @users_to_write_ssh_keys = {}
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

      # Collection of commit configs to address the commit actions to perform for each user
      #
      # @return [CommitConfigCollection]
      attr_reader :commit_configs

      # Issues generated during the process
      #
      # @return [Y2Issues::List]
      attr_reader :issues

      # Performs the changes in the system in order to create, edit or delete users according to
      # the differences between the initial and the target configs. Commit actions can be addressed
      # with the commit configs, see {CommitConfig}. Root mail aliases are also updated.
      #
      # @see ActionWriter
      def actions
        delete_users
        edit_users
        add_users
        write_root_aliases
        write_ssh_auth_keys
      end

      # Deletes users
      def delete_users
        deleted_users.each do |user|
          success = delete_user(user)
          root_alias_candidates << user unless success
        end
      end

      # Creates the new users
      def add_users
        new_users.each { |u| add_user(u) }
      end

      def write_ssh_auth_keys
        # we need to re-read system users as for some newly created users
        # the default home can be used and it depends on useradd and login
        # defaults. So instead of mimic useradd behavior just read what
        # useradd creates. (bsc#1201185)
        system_users = Reader.new.read.users
        @users_to_write_ssh_keys.each_pair do |user, old_keys|
          system_user = system_users.by_name(user.name)
          if !system_user
            issues << Y2Issues::Issue.new(_("Failed to find user with name '#{user.name}'"))
            log.error("Failed to find user with name #{user.name}")
            next
          end

          system_user.authorized_keys = user.authorized_keys
          write_user_auth_keys(system_user, old_keys)
        end
      end

      # Performs all needed actions in order to create and configure a new user (create user, set
      # password, etc).
      #
      # @param user [User] the user to be created on the system
      def add_user(user)
        reusing_home = exist_user_home?(user)

        return unless create_user(user)

        root_alias_candidates << user

        commit_config = commit_config(user)
        remove_home_content(user) if !reusing_home && commit_config.home_without_skel?
        adapt_home_ownership(user) if commit_config.adapt_home_ownership?
        write_password(user) if user.password
        @users_to_write_ssh_keys[user] = []
      end

      # Edits users
      def edit_users
        edited_users.each do |user|
          initial_user = initial_config.users.by_id(user.id)
          edit_user(initial_user, user)
        end
      end

      # Performs all the actions for editing the given user
      #
      # @param initial_user [User] Initial state of the user
      # @param target_user [User] Target state of the user
      def edit_user(initial_user, target_user)
        if !modify_user(initial_user, target_user)
          root_alias_candidates << initial_user
          return
        end

        root_alias_candidates << target_user

        commit_config = commit_config(target_user)
        adapt_home_ownership(target_user) if commit_config.adapt_home_ownership?
        edit_password(target_user) if initial_user.password != target_user.password

        previous_keys = initial_user.authorized_keys || []
        return if previous_keys == target_user.authorized_keys

        @users_to_write_ssh_keys[target_user] = previous_keys
      end

      # Updates root aliases
      #
      # @see #root_alias_candidates
      #
      # Issues are generated if the root aliases cannot be set
      def write_root_aliases
        names = root_alias_candidates.select(&:receive_system_mail?).map(&:name).sort

        return if Yast::MailAliases.SetRootAlias(names.join(", "))

        issues << Y2Issues::Issue.new(_("Error setting root mail aliases"))
        log.error("Error setting root mail aliases")
      end

      # Candidate users to be included as root mail alias
      #
      # This list initially contains the users that have not been edited (initial and target users
      # are equal). The list is then filled up with more users while applying changes to the system.
      # During the process, the following users are added:
      #   * Successfully created users
      #   * Successfully edited users
      #   * Users that could not be edited (the initial user is added)
      #   * Users that could not be deleted
      #
      # @return [Array<User>]
      def root_alias_candidates
        return @root_alias_candidates if @root_alias_candidates

        exclude_ids = (new_users + edited_users).map(&:id)
        @root_alias_candidates = target_config.users.without(exclude_ids).all
      end

      # Users that should be deleted
      #
      # @return [Array<User>]
      def deleted_users
        @deleted_users ||= initial_config.users.without(target_config.users.ids).all
      end

      # Users that should be created
      #
      # @return [Array<User>]
      def new_users
        return @new_users if @new_users

        new_users = target_config.users.without(initial_config.users.ids)
        # empty string to process users without uid the last
        @new_users = new_users.all.sort_by { |u| u.uid || "" }.reverse
      end

      # Users that should be edited
      #
      # @return [Array<User>]
      def edited_users
        @edited_users ||= target_config.users.changed_from(initial_config.users).all
      end

      # Performs the action for creating the given user
      #
      # @param user [User]
      # @return [Boolean] true on success
      def create_user(user)
        action = CreateUserAction.new(user, commit_config(user))

        perform_action(action)
      end

      # Performs the action for editing the given user
      #
      # @param initial_user [User]
      # @param target_user [User]
      #
      # @return [Boolean] true on success
      def modify_user(initial_user, target_user)
        # If a new home was assigned to the user and that home already exists, then the content of
        # previous home cannot be moved to the new home. Note that "usermod --move-home" fails in
        # that scenario (exit status different to 0). To prevent such errors, the commit config is
        # forced to not move the home content in that case.
        commit_config = commit_config(target_user).dup
        commit_config.move_home = false if exist_user_home?(target_user)

        action = EditUserAction.new(initial_user, target_user, commit_config)

        perform_action(action)
      end

      # Performs the action for editing the password of the given user
      #
      # @param user [User]
      # @return [Boolean] true on success
      def edit_password(user)
        user.password ? write_password(user) : delete_password(user)
      end

      # Performs the action for setting the password of the given user
      #
      # @param user [User]
      # @return [Boolean] true on success
      def write_password(user)
        action = SetUserPasswordAction.new(user, commit_config(user))

        perform_action(action)
      end

      # Performs the action for deleting the password of the given user
      #
      # @param user [User]
      # @return [Boolean] true on success
      def delete_password(user)
        action = DeleteUserPasswordAction.new(user, commit_config(user))

        perform_action(action)
      end

      # Performs the action for removing the home content of the given user
      #
      # @param user [User]
      # @return [Boolean] true on success
      def remove_home_content(user)
        return true unless exist_user_home?(user)

        action = RemoveHomeContentAction.new(user, commit_config(user))

        perform_action(action)
      end

      # Performs the action for adapting the home ownership to the given user
      #
      # @param user [User]
      # @return [Boolean] true on success
      def adapt_home_ownership(user)
        return true unless exist_user_home?(user)

        action = SetHomeOwnershipAction.new(user, commit_config(user))

        perform_action(action)
      end

      # Performs the action for setting the authorized keys for the given user
      #
      # @param user [User]
      # @param previous_keys [Array<String>] previous auth keys for given user, if any
      # @return [Boolean] true on success
      def write_user_auth_keys(user, previous_keys = [])
        action = SetAuthKeysAction.new(user, commit_config(user), previous_keys)

        perform_action(action)
      end

      # Performs the action for deleting the given user
      #
      # @param user [User]
      # @return [Boolean] true on success
      def delete_user(user)
        action = DeleteUserAction.new(user, commit_config(user))

        perform_action(action)
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

        Yast::FileUtils.IsDirectory(user.home.path)
      end
    end
  end
end
