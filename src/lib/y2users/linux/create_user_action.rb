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

module Y2Users
  module Linux
    # Action for creating a new user
    class CreateUserAction < Action
      include Yast::I18n
      include Yast::Logger

      # Constructor
      #
      # @see Action
      def initialize(user)
        textdomain "users"

        super
      end

    private

      alias_method :user, :action_element

      # Command for creating new users
      USERADD = "/usr/sbin/useradd".freeze
      private_constant :USERADD

      # Exit code returned by `useradd` when the operation is aborted because the home directory
      # could not be created
      USERADD_E_HOMEDIR = 12
      private_constant :USERADD_E_HOMEDIR

      # @see Action#run_action
      #
      # Issues are generated when the user cannot be created.
      def run_action
        create_user
        true
      rescue Cheetah::ExecutionFailed => e
        issues << Y2Issues::Issue.new(
          format(_("The user '%{username}' could not be created"), username: user.name)
        )
        log.error("Error creating user '#{user.name}' - #{e.message}")
        false
      end

      # Executes the command for creating the user, retrying in case of a recoverable error
      def create_user
        Yast::Execute.on_target!(USERADD, *useradd_options)
      rescue Cheetah::ExecutionFailed => e
        raise(e) unless e.status.exitstatus == USERADD_E_HOMEDIR

        Yast::Execute.on_target!(USERADD, *useradd_options(skip_home: true))
        issues << Y2Issues::Issue.new(
          format(_("Failed to create home directory for user '%s'"), user.name)
        )
        log.warn("User '#{user.name}' created without home '#{user.home}'")
      end

      # Generates options for `useradd` according to the user
      #
      # @param skip_home [Boolean] whether the home creation should be explicitly skip
      # @return [Array<String>]
      def useradd_options(skip_home: false)
        user_options + home_options(skip_home: skip_home) + [user.name]
      end

      # Options from user attributes
      #
      # @return [Array<String>]
      def user_options
        opts = {
          "--uid"     => user.uid,
          "--gid"     => user.gid,
          "--shell"   => user.shell,
          "--comment" => user.gecos.join(","),
          "--groups"  => user.secondary_groups_name.join(",")
        }

        opts = opts.reject { |_, v| v.to_s.empty? }.flatten

        # user is already warned in advance
        opts << "--non-unique" if user.uid

        opts << "--system" if user.system?

        opts
      end

      # Generates options for `useradd` about how to deal with home
      #
      # The home is created in the given home path. If the home path is unknown, then the home is
      # created in the default path indicated by the useradd defaults configuration.
      #
      # The home is not created if explicitly requested with `:skip_hope` param.
      #
      # Note that `useradd` will not try to create the home if the given path already exists, it
      # does not matter whether --create-home is passed.
      #
      # @param skip_home [Boolean]
      # @return [Array<String>]
      def home_options(skip_home: false)
        # If a home is configured for a system user (e.g., with AutoYaST), then its home should be
        # created (bsc#1202974).
        return [] if user.system? && !user.home&.path?

        return ["--no-create-home"] if skip_home

        create_home_options
      end

      # Options when the home has to be created
      #
      # @return [Array<String>]
      def create_home_options
        opts = ["--create-home"]
        opts += ["--home-dir", user.home.path] if user.home&.path && !user.home.path.empty?
        opts += ["--btrfs-subvolume-home"] if user.home&.btrfs_subvol?
        opts += ["--key", "HOME_MODE=#{user.home.permissions}"] if user.home&.permissions
        opts
      end
    end
  end
end
