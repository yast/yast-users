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
    class CreateUserAction < UserAction
      include Yast::I18n
      include Yast::Logger

      # Constructor
      def initialize(user, commit_config = nil)
        textdomain "users"

        super
      end

    private

      # Command for creating new users
      USERADD = "/usr/sbin/useradd".freeze
      private_constant :USERADD

      # Exit code returned by useradd when the operation is aborted because the home directory could
      # not be created
      USERADD_E_HOMEDIR = 12
      private_constant :USERADD_E_HOMEDIR

      # Performs all needed actions in order to create and configure a new user (create user, set
      # password, etc).
      #
      # @param issues [Y2Issues::List] a collection for adding an issue if something goes wrong
      def run_action(issues)
        create_user(issues)
        true
      rescue Cheetah::ExecutionFailed => e
        issues << Y2Issues::Issue.new(
          format(_("The user '%{username}' could not be created"), username: user.name)
        )
        log.error("Error creating user '#{user.name}' - #{e.message}")
        false
      end

      # Executes the command for creating the user, retrying in case of a recoverable error
      #
      # Issues are generated when the user cannot be created.
      #
      # @see #create_user
      def create_user(issues)
        Yast::Execute.on_target!(USERADD, *useradd_options)
      rescue Cheetah::ExecutionFailed => e
        raise(e) unless e.status.exitstatus == USERADD_E_HOMEDIR

        Yast::Execute.on_target!(USERADD, *useradd_options(skip_home: true))
        issues << Y2Issues::Issue.new(
          format(_("Failed to create home directory for user '%s'"), user.name)
        )
        log.warn("User '#{user.name}' created without home '#{user.home}'")
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
      def useradd_options(skip_home: false)
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
          opts.concat(create_home_options)
        end

        # user is already warned in advance
        opts << "--non-unique" if user.uid

        opts << user.name
        opts
      end

      # Options for `useradd` to create the home directory
      #
      # Note that useradd command will not try to create the home directory if it already exists, it
      # does not matter whether --create-home was passed.
      #
      # @param user [User]
      # @return [Array<String>]
      def create_home_options
        opts = ["--create-home"]
        opts << "--btrfs-subvolume-home" if user.home&.btrfs_subvol?
        opts << "--key" << "HOME_MODE=#{user.home.permissions}" if user.home&.permissions
        opts
      end
    end
  end
end
