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

require "yast2/execute"
require "y2users/linux/base_reader"
require "y2users/login_config"
require "y2users/linux/useradd_config_reader"
require "users/ssh_authorized_keyring"

Yast.import "Autologin"
Yast.import "MailAliases"

module Y2Users
  module Linux
    # Reads users configuration from the system using `getent` command.
    class Reader < BaseReader
      # @see BaseReader#read
      # @note some of these #read_* methods could be moved to the
      #   {BaseReader#read} once they allow reading from a specific location
      #   (i.e., compatible with {LocalReader} too)
      def read
        config = super

        read_root_aliases(config)
        read_home_permissions(config)
        read_authorized_keys(config)
        read_useradd_config(config)
        read_login(config)

        config
      end

    private

      # Set root aliases (i.e., users receiving system mails)
      #
      # @see Yast::MailAliases#GetRootAlias
      #
      # @param config [Config]
      def read_root_aliases(config)
        Yast::MailAliases.GetRootAlias.split(", ").each do |name|
          user = config.users.by_name(name)
          user.receive_system_mail = true if user
        end
      end

      # Command for reading home directory permissions
      STAT = "/usr/bin/stat".freeze
      private_constant :STAT

      # Reads home permissions
      #
      # @return [Array<Y2Users::User>]
      def read_home_permissions(config)
        config.users.reject(&:system?).each do |user|
          next unless user.home && Dir.exist?(user.home.path)

          user.home.permissions = Yast::Execute.on_target!(
            STAT, "--printf", "%a", user.home.path,
            stdout: :capture
          ).prepend("0")
        end
      end

      # Reads users authorized keys
      #
      # @see Yast::Users::SSHAuthorizedKeyring#read_keys
      # @return [Array<Y2Users::User>]
      def read_authorized_keys(config)
        config.users.each do |user|
          next unless user.home

          user.authorized_keys = Yast::Users::SSHAuthorizedKeyring.new(user.home.path).read_keys
        end
      end

      # Reads the configuration for useradd
      #
      # @param config [Config]
      def read_useradd_config(config)
        config.useradd = UseraddConfigReader.new.read
      end

      # Reads the login information
      #
      # @param config [Config]
      def read_login(config)
        Yast::Autologin.Read

        return unless Yast::Autologin.used

        login = LoginConfig.new
        login.autologin_user = config.users.by_name(Yast::Autologin.user)
        login.passwordless = Yast::Autologin.pw_less

        config.login = login
      end

      # Loads entries from `passwd` database
      #
      # @see #getent
      # @return [String]
      def load_users
        getent("passwd")
      end

      # Loads entries from `group` database
      #
      # @see #getent
      # @return [String]
      def load_groups
        getent("group")
      end

      # Loads entries from `shadow` database
      #
      # @see #getent
      # @return [String]
      def load_passwords
        getent("shadow")
      end

      # Executes the `getent` command for getting entries for given Name Service Switch database
      #
      # @see https://www.man7.org/linux/man-pages/man1/getent.1.html
      #
      # @param database [String] a database supported by the Name Service Switch libraries
      # @return [String] the getent command output
      def getent(database)
        Yast::Execute.on_target!("/usr/bin/getent", database, stdout: :capture)
      end
    end
  end
end
