# Copyright (c) [2020] SUSE LLC
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
require "installation/auto_client"
require "y2users"
require "y2users/autoinst/reader"
require "y2issues"

Yast.import "Users"
Yast.import "Linuxrc"
Yast.import "Mode"
Yast.import "Progress"
Yast.import "Report"
Yast.import "Stage"
Yast.import "Wizard"

module Y2Users
  module Clients
    # AutoYaST users client
    class Auto < ::Installation::AutoClient
      def initialize
        textdomain "users"

        Yast.include self, "users/wizards.rb"
      end

    protected

      def import(param)
        # Use the old API when using the AutoYaST UI
        if Yast::Mode.config
          check_users(param["users"] || [])
          Yast::Users.Import(param)

        # and the new one for autoinstallation (and autoconfiguration)
        else
          reader = Y2Users::Autoinst::Reader.new(param)
          result = reader.read
          read_linuxrc_root_pwd(result.config)

          if result.issues?
            return false unless Y2Issues.report(result.issues)
          end

          Y2Users::ConfigManager.instance.target = result.config

          true
        end
      end

      def summary
        Yast::Users.Summary
      end

      def change
        Yast::Wizard.CreateDialog
        Yast::Wizard.SetDesktopIcon("org.opensuse.yast.Users")
        ret = AutoSequence("summary")
        Yast::Wizard.CloseDialog
        ret
      end

      def export(target:)
        Yast::Users.Export(target.to_s)
      end

      def read
        Yast::Users.SetExportAll(true)
        progress_orig = Yast::Progress.set(false)
        ret = Yast::Users.Read == ""

        Yast::Progress.set(progress_orig)
        ret
      end

      # @note This code is not executed during autoinstallation (instead, the
      # users_finish is used). However, it is used when running ayast_setup and
      # the AutoYaST UI.
      #
      # @return [Boolean] true if configuration was changed; false otherwise.
      def write
        if Yast::Mode.normal # Use the old API for AutoYaST UI
          Yast::Users.SetWriteOnly(true)
          progress_orig = Yast::Progress.set(false)
          ret = Yast::Users.Write == ""
          Yast::Progress.set(progress_orig)
          ret
        else
          Yast::WFM.CallFunction("users_finish", ["Write"])
          true
        end
      end

      def modified?
        Yast::Users.Modified
      end

      def modified
        Yast::Users.SetModified(true)
        true
      end

      def reset
        import({})
      end

    private

      # Checking double user entries
      # (double username or UID)
      # @param [Array] users to check
      def check_users(users)
        if users.size > users.uniq { |u| u["username"] }.size
          Yast::Report.Error(_("Found users in profile with equal <username>."))
        end
        # Do not check users without defined UID. (bnc#996823)
        check_users = users.dup
        check_users.select! { |u| u.key?("uid") }
        report = check_users.size > check_users.uniq { |u| u["uid"] }.size

        Yast::Report.Error(_("Found users in profile with equal <uid>.")) if report
      end

      def read_linuxrc_root_pwd(config)
        root_user = config.users.root
        # use param only if profile does not contain it yet.
        return if root_user&.password

        # root user not defined
        if !root_user
          root_user = Y2Users::User.new("root")
          root_user.uid = "0"
          config.attach(root_user)
        end

        root_user.password = Y2Users::Password.create_plain(
          Yast::Linuxrc.InstallInf("RootPassword")
        )

        root_user
      end
    end
  end
end
