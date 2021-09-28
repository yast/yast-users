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
require "yast/i18n"
require "yast2/execute"
require "users/ssh_authorized_keyring"
require "y2users/commit_config"

Yast.import "MailAliases"

module Y2Users
  module Linux
    # Writes users to the system using Yast2::Execute and standard linux tools.
    #
    # @note: this is not meant to be used directly, but to be used by the general {Linux::Writer}
    #
    # FIXME: This class is too big. Consider refactoring it, for example, by splitting it in actions
    #   for creating, editing and deleting users.
    class UsersWriter # rubocop:disable Metrics/ClassLength
      include Yast::I18n
      include Yast::Logger
      include Y2Issues::WithIssues

      # Constructor
      #
      # @param config [Config] see #config
      # @param initial_config [Config] see #initial_config
      # @param commit_configs [CommitConfigCollection]
      def initialize(config, initial_config, commit_configs)
        textdomain "users"

        @config = config
        @initial_config = initial_config
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
          issues.concat(add_users)
          issues.concat(edit_users)
          issues.concat(update_root_aliases)
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

      # Creates the new users
      #
      # @return [Y2Issues::List] the list of issues found while creating users; empty when none
      def add_users
        new_users = config.users.without(initial_config.users.ids)
        # empty string to process users without uid the last
        sorted_users = new_users.all.sort_by { |u| u.uid || "" }.reverse

        with_issues do |issues|
          sorted_users.each { |u| add_user(u, issues) }
        end
      end

      # Applies changes for the edited users
      #
      # @return [Y2Issues::List] the list of issues found while editing users; empty when none
      def edit_users
        edited_users = config.users.changed_from(initial_config.users)

        with_issues do |issues|
          edited_users.each do |user|
            initial_user = initial_config.users.by_id(user.id)
            edit_user(user, initial_user, issues)
          end
        end
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

      # Collection holding names of users set to receive system mail (i.e., to be aliases of root)
      #
      # @return [Array<User>]
      attr_accessor :root_aliases

      # Collection of commit configs to address the commit actions to perform for each user
      #
      # @return [CommitConfigCollection]
      attr_reader :commit_configs

      # Command for creating new users
      USERADD = "/usr/sbin/useradd".freeze
      private_constant :USERADD

      # Exit code returned by useradd when the operation is aborted because the home directory could
      # not be created
      USERADD_E_HOMEDIR = 12
      private_constant :USERADD_E_HOMEDIR

      # Command for modifying users
      USERMOD = "/usr/sbin/usermod".freeze
      private_constant :USERMOD

      # Command for setting a user password
      #
      # This command is "preferred" over
      #   * the `passwd` command because the password at this point is already
      #   encrypted (see Y2Users::Password#value). Additionally, this command
      #   requires to enter the password twice, which it's not possible using
      #   the Cheetah stdin argument.
      #
      #   * the `--password` useradd option because the encrypted
      #   password is visible as part of the process name
      CHPASSWD = "/usr/sbin/chpasswd".freeze
      private_constant :CHPASSWD

      # Command for editing a password (i.e., used for deleting the password)
      PASSWD = "/usr/bin/passwd".freeze
      private_constant :PASSWD

      # Command for configuring the attributes in /etc/shadow
      CHAGE = "/usr/bin/chage".freeze
      private_constant :CHAGE

      # Command for changing ownership
      CHOWN = "/usr/bin/chown".freeze
      private_constant :CHOWN

      # Command for finding files
      FIND = "/usr/bin/find".freeze
      private_constant :FIND

      # Commit actions for a specific user
      #
      # @param user [User] Note that the commit config of a user is found by the user name. Due to
      #   the user name can change, always use the user from the target config.
      # @return [CommitConfig] commit config for the given user or a new commit config if there is
      #   no config for that user.
      def commit_config(user)
        commit_configs.by_username(user.name) || CommitConfig.new
      end

      # Performs all needed actions in order to create and configure a new user (create user, set
      # password, etc).
      #
      # @param user [User] the user to be created on the system
      # @param issues [Y2Issues::List] a collection for adding an issue if something goes wrong
      def add_user(user, issues)
        create_user(user, issues)
        change_password(user, issues) if user.password
        write_auth_keys(user, issues)
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
        try_create_user(user, issues)
        root_aliases << user.name if user.receive_system_mail?
      rescue Cheetah::ExecutionFailed => e
        issues << Y2Issues::Issue.new(
          format(_("The user '%{username}' could not be created"), username: user.name)
        )
        log.error("Error creating user '#{user.name}' - #{e.message}")
      end

      # Executes the command for creating the user, retrying in case of a recoverable error
      #
      # Issues are generated when the user cannot be created.
      #
      # @see #create_user
      #
      # @param user [User] the user to be created on the system
      # @param issues [Y2Issues::List] a collection for adding an issue if something goes wrong
      def try_create_user(user, issues)
        reusing_home = exist_user_home?(user)
        Yast::Execute.on_target!(USERADD, *useradd_options(user))
        clear_home(user, issues) if !reusing_home && commit_config(user).home_without_skel?
        chown_home(user, issues) if commit_config(user).adapt_home_ownership?
      rescue Cheetah::ExecutionFailed => e
        raise(e) unless e.status.exitstatus == USERADD_E_HOMEDIR

        Yast::Execute.on_target!(USERADD, *useradd_options(user, skip_home: true))
        issues << Y2Issues::Issue.new(
          format(_("Failed to create home directory for user '%s'"), user.name)
        )
        log.warn("User '#{user.name}' created without home '#{user.home}'")
      end

      # Clear the content of the home directory/subvolume for the given user
      #
      # Issues are generated when the home cannot be cleaned up.
      #
      # @param user [User]
      # @param issues [Y2Issues::List] new issues can be added
      def clear_home(user, issues)
        return unless exist_user_home?(user)

        Yast::Execute.on_target!(FIND, user.home.path, "-mindepth", "1", "-delete")
      rescue Cheetah::ExecutionFailed => e
        issues << Y2Issues::Issue.new(
          format(_("Cannot clean up '%s'"), user.home.path)
        )
        log.error("Error cleaning up '#{user.home.path}' - #{e.message}")
      end

      # Changes ownership of the home directory/subvolume for the given user
      #
      # Issues are generated when ownership cannot be changed.
      #
      # @param user [User]
      # @param issues [Y2Issues::List] new issues can be added
      def chown_home(user, issues)
        return unless exist_user_home?(user)

        owner = user.name.dup
        owner << ":#{user.gid}" if user.gid

        Yast::Execute.on_target!(CHOWN, "-R", owner, user.home.path)
      rescue Cheetah::ExecutionFailed => e
        issues << Y2Issues::Issue.new(
          format(_("Cannot change ownership of '%s'"), user.home.path)
        )
        log.error("Error changing ownership of '#{user.home.path}' - #{e.message}")
      end

      # Whether the home directory/subvolume of the given user exists on disk
      #
      # @param user [User]
      # @return [Boolean]
      def exist_user_home?(user)
        return false unless user.home&.path

        File.exist?(user.home.path)
      end

      # Executes the commands for setting the password and all its associated
      # attributes for the given user
      #
      # @param user [User]
      # @param issues [Y2Issues::List] a collection for adding issues if something goes wrong
      def change_password(user, issues)
        set_password_value(user, issues)
        set_password_attributes(user, issues)
      rescue Cheetah::ExecutionFailed => e
        issues << Y2Issues::Issue.new(
          format(_("Error setting the password for user '%s'"), user.name)
        )
        log.error("Error setting password for '#{user.name}' - #{e.message}")
      end

      # Executes the command for deleting the password of the given user
      #
      # @param user [User]
      # @param issues [Y2Issues::List] a collection for adding an issue if something goes wrong
      def delete_password(user, issues)
        Yast::Execute.on_target!(PASSWD, "--delete", user.name)
      rescue Cheetah::ExecutionFailed => e
        issues << Y2Issues::Issue.new(
          # TRANSLATORS: %s is a placeholder for a username
          format(_("The password for '%s' cannot be deleted"), user.name)
        )
        log.error("Error deleting password for '#{user.name}' - #{e.message}")
      end

      # Writes authorized keys for given user
      #
      # @see Yast::Users::SSHAuthorizedKeyring#write_keys
      #
      # @param user [User]
      # @param issues [Y2Issues::List] a collection for adding issues if something goes wrong
      def write_auth_keys(user, issues)
        return unless user.home

        Yast::Users::SSHAuthorizedKeyring.new(user.home, user.authorized_keys).write_keys
      rescue Yast::Users::SSHAuthorizedKeyring::PathError => e
        issues << Y2Issues::Issue.new(
          # TRANSLATORS: %s is a placeholder for a username
          format(_("Error writing authorized keys for '%s'"), user.name)
        )
        log.error("Error writing authorized keys for '#{user.name}' - #{e.message}")
      end

      # Executes the command for setting the password of given user
      #
      # @param user [User]
      # @param issues [Y2Issues::List] a collection for adding an issue if something goes wrong
      def set_password_value(user, issues)
        return unless user.password&.value

        Yast::Execute.on_target!(CHPASSWD, *chpasswd_options(user))
      rescue Cheetah::ExecutionFailed => e
        issues << Y2Issues::Issue.new(
          # TRANSLATORS: %s is a placeholder for a username
          format(_("The password for '%s' could not be set"), user.name)
        )
        log.error("Error setting password for '#{user.name}' - #{e.message}")
      end

      # Executes the command for setting the dates and limits in /etc/shadow
      #
      # @param user [User]
      # @param issues [Y2Issues::List] a collection for adding an issue if something goes wrong
      def set_password_attributes(user, issues)
        return unless user.password

        options = chage_options(user)

        return if options.empty?

        Yast::Execute.on_target!(CHAGE, *options, user.name)
      rescue Cheetah::ExecutionFailed => e
        issues << Y2Issues::Issue.new(
          # TRANSLATORS: %s is a placeholder for a username
          format(_("Error setting the properties of the password for '%s'"), user.name)
        )
        log.error("Error setting password attributes for '#{user.name}' - #{e.message}")
      end

      # Edits the user
      #
      # @param new_user [User] User containing the updated information
      # @param old_user [User] Original user
      # @param issues [Y2Issues::List] a collection for adding an issue if something goes wrong
      def edit_user(new_user, old_user, issues)
        return if new_user == old_user

        return unless modify_user(new_user, old_user, issues)

        chown_home(new_user, issues) if commit_config(new_user).adapt_home_ownership?
        edit_password(new_user, issues) if old_user.password != new_user.password
        write_auth_keys(new_user, issues) if old_user.authorized_keys != new_user.authorized_keys
      end

      # Applies changes in the user by calling to usermod command
      #
      # @param new_user [User] User containing the updated information
      # @param old_user [User] Original user
      # @param issues [Y2Issues::List] a collection for adding an issue if something goes wrong
      #
      # @return [Boolean] true on success; false otherwise
      def modify_user(new_user, old_user, issues)
        options = usermod_options(new_user, old_user)
        Yast::Execute.on_target!(USERMOD, *options, old_user.name) if options.any?

        root_aliases << new_user.name if new_user.receive_system_mail?

        true
      rescue Cheetah::ExecutionFailed => e
        root_aliases << old_user.name if old_user.receive_system_mail?
        issues << Y2Issues::Issue.new(
          format(_("The user '%{username}' could not be modified"), username: old_user.name)
        )
        log.error("Error modifying user '#{old_user.name}' - #{e.message}")

        false
      end

      # Edits the user's password
      #
      # @param new_user [User] User containing the updated information
      # @param issues [Y2Issues::List] a collection for adding an issue if something goes wrong
      def edit_password(new_user, issues)
        new_user.password ? change_password(new_user, issues) : delete_password(new_user, issues)
      end

      # Generates and returns the options expected by `useradd` for the given user
      #
      # Note that the home is not created if:
      #   * requested with skip_hope param
      #   * user has not a home path
      #   * the home path points to an existing home, see {#create_home_options}
      #
      # @param user [User]
      # @param skip_home [Boolean] whether the home creation should be explicitly avoided
      # @return [Array<String>]
      def useradd_options(user, skip_home: false)
        opts = {
          "--uid"      => user.uid,
          "--gid"      => user.gid,
          "--shell"    => user.shell,
          "--home-dir" => user.home&.path,
          "--comment"  => user.gecos.join(","),
          "--groups"   => user.secondary_groups_name.join(",")
        }
        opts = opts.reject { |_, v| v.to_s.empty? }.flatten

        if user.system?
          opts << "--system"
        elsif skip_home || !opts.include?("--home-dir")
          opts << "--no-create-home"
        else
          opts.concat(create_home_options(user))
        end

        # user is already warned in advance
        opts << "--non-unique" if user.uid

        opts << user.name
        opts
      end

      # Command to modify the user
      #
      # @param new_user [User] User containing the updated information
      # @param old_user [User] Original user
      # @return [Array<String>] usermod options
      # rubocop:disable Metrics/CyclomaticComplexity
      # rubocop:disable Metrics/AbcSize
      # rubocop:disable Metrics/PerceivedComplexity
      def usermod_options(new_user, old_user)
        args = []
        args << "--login" << new_user.name if new_user.name != old_user.name && new_user.name
        args << "--uid" << new_user.uid if new_user.uid != old_user.uid && new_user.uid
        args << "--gid" << new_user.gid if new_user.gid != old_user.gid && new_user.gid
        args << "--comment" << new_user.gecos.join(",") if new_user.gecos != old_user.gecos

        # With the --home option, the home path of the user is updated in the passwd file, but the
        # home is not created. The only ways to create a new home for an existing user is:
        #   * reusing an existing directory/subvolume
        #   * moving the current home to a new path (see --move-home option below)
        # Creating the home directory/subvolume of an existing user is not supported by the shadow
        # tools.
        if new_user.home&.path && new_user.home.path != old_user.home&.path
          args << "--home" << new_user.home.path
        end

        # With the --move-home option, all the content from the previous home directory is moved to
        # the new location, and ownership is also adapted. But take into account that the new home
        # will be created only if the old home directory exists. Otherwise, the user will continue
        # without a home directory. Also note that if the new home already exists, then the content
        # of the old home is not moved neither.
        args << "--move-home" if commit_config(new_user).move_home? && args.include?("--home")

        args << "--shell" << new_user.shell if new_user.shell != old_user.shell && new_user.shell

        if different_groups?(new_user, old_user)
          args << "--groups" << new_user.secondary_groups_name.join(",")
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

      # Options for `useradd` to create the home directory
      #
      # Note that useradd command will not try to create the home directory if it already exists, it
      # does not matter whether --create-home was passed.
      #
      # @param user [User]
      # @return [Array<String>]
      def create_home_options(user)
        opts = ["--create-home"]
        opts << "--btrfs-subvolume-home" if user.home&.btrfs_subvol?
        opts << "--key" << "HOME_MODE=#{user.home.permissions}" if user.home&.permissions
        opts
      end

      # Generates and returns the options expected by `chpasswd` for the given user
      #
      # @param user [User]
      # @return [Array<String, Hash>]
      def chpasswd_options(user)
        opts = []
        opts << "-e" if user.password&.value&.encrypted?
        opts << {
          stdin:    [user.name, user.password_content].join(":"),
          recorder: cheetah_recorder
        }
        opts
      end

      # Generates and returns the options expected by `chage` for the given user
      #
      # @param user [User]
      # @return [Array<String>]
      def chage_options(user)
        passwd = user.password

        opts = {
          "--mindays"    => chage_value(passwd.minimum_age),
          "--maxdays"    => chage_value(passwd.maximum_age),
          "--warndays"   => chage_value(passwd.warning_period),
          "--inactive"   => chage_value(passwd.inactivity_period),
          "--expiredate" => chage_value(passwd.account_expiration),
          "--lastday"    => chage_value(passwd.aging)
        }

        opts.reject { |_, v| v.nil? }.flatten
      end

      # Returns the right value for a given chage option value
      #
      # @see #chage_options
      #
      # @param value [String, Integer, Date, nil]
      # @return [String]
      def chage_value(value)
        return if value.nil?

        result = value.to_s
        result.empty? ? "-1" : result
      end

      # Custom Cheetah recorder to prevent leaking the password to the logs
      #
      # @return [Recorder]
      def cheetah_recorder
        @cheetah_recorder ||= Recorder.new(Yast::Y2Logger.instance)
      end

      # Class to prevent Yast::Execute from leaking to the logs passwords
      # provided via stdin
      class Recorder < Cheetah::DefaultRecorder
        # To prevent leaking stdin, just do nothing
        def record_stdin(_stdin); end
      end
    end
  end
end
