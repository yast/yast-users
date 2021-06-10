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
require "users/ssh_authorized_keyring"

module Y2Users
  module Linux
    # Writes users to the system using Yast2::Execute and standard linux tools.
    #
    # @note: this is not meant to be used directly, but to be used by the general {Linux::Writer}
    class UsersWriter
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

      # Creates the new users
      #
      # @param issues [Y2Issues::List] the list of issues found while writing changes
      def add_users(issues)
        new_users = config.users.without(initial_config.users.ids)

        new_users.each { |u| add_user(u, issues) }
      end

      # Applies changes for the edited users
      #
      # @param issues [Y2Issues::List] the list of issues found while writing changes
      def edit_users(issues)
        edited_users = config.users.changed_from(initial_config.users)

        edited_users.each do |user|
          initial_user = initial_config.users.by_id(user.id)
          edit_user(user, initial_user, issues)
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

      # Default values to use during user creation
      #
      # @return [UserDefaults]
      def defaults
        config.user_defaults
      end

      # Command for creating new users
      USERADD = "/usr/sbin/useradd".freeze
      private_constant :USERADD

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

      # Command for configuring the attributes in /etc/shadow
      CHAGE = "/usr/bin/chage".freeze
      private_constant :CHAGE

      # Executes the command for creating the user
      #
      # @param user [User] the user to be created on the system
      # @param issues [Y2Issues::List] a collection for adding an issue if something goes wrong
      def add_user(user, issues)
        Yast::Execute.on_target!(USERADD, *useradd_options(user))
        change_password(user, issues) if user.password
        write_auth_keys(user, issues)
      rescue Cheetah::ExecutionFailed => e
        issues << Y2Issues::Issue.new(
          format(_("The user '%{username}' could not be created"), username: user.name)
        )
        log.error("Error creating user '#{user.name}' - #{e.message}")
      end

      # Executes the commands for setting the password and all its associated
      # attributes for the given user
      #
      # @param user [User]
      # @param issues [Y2Issues::List] a collection for adding issues if something goes wrong
      def change_password(user, issues)
        set_password_value(user, issues)
        set_password_attributes(user, issues)
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

      # Attributes to modify using `usermod`
      USERMOD_ATTRS = [:gid, :home, :shell, :gecos].freeze

      # Edits the user
      #
      # @param new_user [User] User containing the updated information
      # @param old_user [User] Original user
      # @param issues [Y2Issues::List] a collection for adding an issue if something goes wrong
      def edit_user(new_user, old_user, issues)
        usermod_changes = USERMOD_ATTRS.any? do |attr|
          !new_user.public_send(attr).nil? &&
            (new_user.public_send(attr) != old_user.public_send(attr))
        end
        usermod_changes ||= different_groups?(new_user, old_user)

        Yast::Execute.on_target!(USERMOD, *usermod_options(new_user, old_user)) if usermod_changes
        change_password(new_user, issues) if old_user.password != new_user.password
        write_auth_keys(new_user, issues) if old_user.authorized_keys != new_user.authorized_keys
      rescue Cheetah::ExecutionFailed => e
        issues << Y2Issues::Issue.new(
          format(_("The user '%{username}' could not be modified"), username: new_user.name)
        )
        log.error("Error modifying user '#{new_user.name}' - #{e.message}")
      end

      # Generates and returns the options expected by `useradd` for given user
      #
      # @param user [User]
      # @return [Array<String>]
      def useradd_options(user)
        opts = {
          "--uid"      => user.uid,
          "--gid"      => user.gid,
          "--shell"    => user.shell,
          "--home-dir" => user.home,
          "--comment"  => user.gecos.join(","),
          "--groups"   => useradd_groups(user).join(",")
        }
        opts = opts.reject { |_, v| v.to_s.empty? }.flatten

        if user.system?
          opts << "--system"
        else
          opts.concat(create_home_options(user))
        end

        opts << user.name
        opts
      end

      # Name of the secondary groups for useradd
      #
      # @return [Array<String>]
      def useradd_groups(user)
        names = user.secondary_groups_name
        return names unless names.empty?

        defaults.secondary_groups
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
        args << "--gid" << new_user.gid if new_user.gid != old_user.gid && new_user.gid
        args << "--comment" << new_user.gecos.join(",") if new_user.gecos != old_user.gecos
        if new_user.home != old_user.home && new_user.home
          args << "--home" << new_user.home << "--move-home"
        end
        args << "--shell" << new_user.shell if new_user.shell != old_user.shell && new_user.shell
        if different_groups?(new_user, old_user)
          args << "--groups" << new_user.secondary_groups_name.join(",")
        end
        args << new_user.name
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
      # @param _user [User]
      # @return [Array<String>]
      def create_home_options(_user)
        # TODO: "--btrfs-subvolume-home" if needed
        opts = ["--create-home"]
        opts.concat(["--skel", defaults.skel]) if defaults.forced_skel?
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
          stdin:    [user.name, user.password&.value&.content].join(":"),
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
