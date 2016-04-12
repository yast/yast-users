# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2016 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# ------------------------------------------------------------------------------

require "installation/finish_client"

module Yast
  class UsersFinishClient < ::Installation::FinishClient
    include Logger

    def initialize
      textdomain "users"

      Yast.import "Users"
      Yast.import "UsersSimple"
      # setup_all_users()
      Yast.include self, "users/routines.rb"
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

    # Write root password a new users during regular installation
    def write_install
      # write the root password
      UsersSimple.Write
      # write new users (if any)
      Users.Write if setup_all_users
    end
  end
end
