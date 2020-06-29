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

Yast.import "Users"
Yast.import "UsersSimple"
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
        check_users(param["users"] || [])
        Yast::Users.Import(param)
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
        if Yast::Stage.initial
          # Importing all users/groups from the UI if we are
          # in the installation workflow
          Yast::Users.SetExportAll(true)
          setup_all_users
        end

        ret = Yast::Users.Export(target.to_s)

        if Yast::Stage.initial
          # Setting root password in the return value. We are in the inst_sys.
          # The root password has not been written but is only available in
          # UserSimple model. We have to set it manually.
          root = ret["users"].find { |u| u["uid"] == "0" }
          if root
            root["user_password"] = Yast::Users.CryptPassword(
              Yast::UsersSimple.GetRootPassword, "system"
            )
          end
        end
        Yast::Users.SetExportAll(false)
        ret
      end

      def read
        Yast::Users.SetExportAll(true)
        progress_orig = Yast::Progress.set(false)
        ret = Yast::Users.Read == ""
        Yast::Progress.set(progress_orig)
        ret
      end

      # @note This code is not executed during autoinstallation (instead, the
      # users_finish is used). However, it is used when running ayast_setup.
      def write
        Yast::Users.SetWriteOnly(true)
        progress_orig = Yast::Progress.set(false)
        ret = Yast::Users.Write == ""
        Yast::Progress.set(progress_orig)
        # Return if configuration  was changed
        # return boolean
        ret
      end

      def modified?
        Yast::Users.Modified
      end

      def modified
        Yast::Users.SetModified(true)
        true
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
        check_users.reject! { |u| !u.key?("uid") }
        if check_users.size > check_users.uniq { |u| u["uid"] }.size
          Yast::Report.Error(_("Found users in profile with equal <uid>."))
        end
      end
    end
  end
end
