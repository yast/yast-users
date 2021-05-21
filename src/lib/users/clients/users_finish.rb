# Copyright (c) [2016-2021] SUSE LLC
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
require "installation/finish_client"
require "y2users/config"
require "y2users/config_manager"
require "y2users/users_simple/reader"
require "y2users/linux/writer"

module Yast
  # This client takes care of setting up the users at the end of the installation
  class UsersFinishClient < ::Installation::FinishClient
    include Logger

    def initialize
      textdomain "users"

      Yast.import "Users"
      Yast.import "UsersSimple"
      Yast.import "Autologin"
      Yast.import "Report"
    end

    # Write users
    #
    # It relies in different methods depending if it's running
    # during autoinst or in a regular installation.
    #
    # @see write_autoinst
    # @see write_install
    def write
      if Mode.autoinst
        write_autoinst
      else
        write_install
      end
    end

  protected

    # @see Implements ::Installation::FinishClient#modes
    def modes
      [:installation, :live_installation, :autoinst]
    end

    # @see Implements ::Installation::FinishClient#title
    def title
      _("Writing Users Configuration...")
    end

    # Write imported users during autoinstallation
    #
    # During installation, some package could add a new user, so we
    # need to read them again before writing.
    #
    # On the other hand, during autoupgrade no changes are performed.
    def write_autoinst
      # 1. Export users imported in inst_autosetup (and store them)
      Users.SetExportAll(false)
      saved = Users.Export
      log.info("Users to import: #{saved}")

      # 2. Read users and settings from the installed system
      # (bsc#965852, bsc#973639, bsc#974220 and bsc#971804)
      Users.Read

      # 3. Merge users from the system with new users from
      #    AutoYaST profile (from step 1)
      Users.Import(saved)

      # 4. Write users
      Users.SetWriteOnly(true)
      @progress_orig = Progress.set(false)
      error = Users.Write
      log.error(error) unless error.empty?
      Progress.set(@progress_orig)
    end

    # Writes users during the installation
    #
    # The linux writer will process all the differences between the system and the target configs.
    # The target config is created from the system one, and then it adds the users configured during
    # the installation. As result, target and system configs should only differ on the new added
    # users and on the password for root.
    #
    # All the issues detected by the writer are reported to the user.
    def write_install
      configure_autologin

      writer = Y2Users::Linux::Writer.new(target_config, system_config)
      issues = writer.write

      report_issues(issues) if issues.any?
    end

  private

    # Configures auto-login
    def configure_autologin
      # resetting Autologin settings
      Autologin.Disable

      if UsersSimple.AutologinUsed
        Autologin.user = UsersSimple.GetAutologinUser
        Autologin.Use(true)
      end

      # The parameter received by Autologin#Write is obsolete and it has no effect.
      Autologin.Write(nil)
    end

    # System config, which contains all the current users on the system
    #
    # @return [Y2Users::Config]
    def system_config
      @system_config ||= Y2Users::ConfigManager.instance.system(force_read: true)
    end

    # Target config, which extends the system config with the new users that should be created
    # during the installation.
    #
    # @return [Y2Users::Config]
    def target_config
      @target_config ||= system_config.merge(users_simple_config)
    end

    # Config with users configured in the installation clients
    #
    # @return [Y2Users::Config]
    def users_simple_config
      @users_simple_config ||= Y2Users::UsersSimple::Reader.new.read
    end

    # Reports issues
    #
    # TODO: This is a temporary solution. Probably, warnings should not be shown.
    #
    # @param issues [Array<Y2Issues::Issue>]
    def report_issues(issues)
      message = issues.map(&:message).join("\n\n")

      Report.Error(message)
    end
  end
end
