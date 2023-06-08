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
require "y2users/config_merger"
require "y2users/config_manager"
require "y2users/autoinst/reader"
require "y2users/linux/writer"

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
        # Use new API for autoinstallation
        if Yast::Stage.initial
          reader = Y2Users::Autoinst::Reader.new(param)
          result = reader.read
          read_linuxrc_root_pwd(result.config)

          if result.issues?
            return false unless Y2Issues.report(result.issues)
          end

          Y2Users::ConfigManager.instance.target = result.config

          true
        # and old one for running system like autoyast UI
        else
          check_users(param["users"] || [])
          Yast::Users.Import(param)
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
      # users_finish is used). However, it is used when running ayast_setup
      # or using the AutoYaST UI.
      #
      # When working on an already installed system, the process of detecting
      # which users/groups changed is tricky:
      #
      # * The approach followed by [Y2Users::UsersModule::Reader](https://github.com/yast/yast-users/blob/414b6c7373068c367c0a01be20a1399fbd0ef470/src/lib/y2users/users_module/reader.rb#L103),
      #   checking the content of `org_user`, does not work because it is defined
      #   only if the user was modified using the AutoYaST UI.
      # * Directly comparing the users/groups from `system_config` and
      #   `target_config` does not work because passwords are missing from the
      #   `target_config` users.
      #
      # To overcome these limitations, we only consider those users/groups
      # which 'modified' property is not nil, although it does not guarantee
      # that they changed at all.
      #
      # @return [Boolean] true if configuration was changed; false otherwise.
      def write
        system_config = Y2Users::ConfigManager.instance.system(force_read: true)
        new_config = system_config.copy
        _, target_config = Y2Users::UsersModule::Reader.new.read
        remove_unchanged_elements(target_config)
        Y2Users::ConfigMerger.new(new_config, target_config).merge
        writer = Y2Users::Linux::Writer.new(new_config, system_config)
        issues = writer.write
        issues.empty?
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

      # Clean users and groups that have not changed according to the 'modified' attributes
      #
      # @param config [Y2Users::Config] Configuration to clean
      def remove_unchanged_elements(config)
        all_users = Yast::Users.GetUsers("uid", "local").values +
          Yast::Users.GetUsers("uid", "system").values
        uids = all_users.select { |u| u["modified"] }.map { |u| u["uid"] }
        users = config.users.reject { |u| uids.include?(u.name) }

        all_groups = Yast::Users.GetGroups("cn", "local").values +
          Yast::Users.GetGroups("cn", "system").values
        gids = all_groups.select { |g| g["modified"] }.map { |g| g["cn"] }
        groups = config.groups.reject { |g| gids.include?(g.name) }

        (users + groups).each { |e| config.detach(e) }
      end
    end
  end
end
