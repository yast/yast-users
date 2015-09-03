# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2006-2012 Novell, Inc. All Rights Reserved.
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------

# File:
#   users_auto.ycp
#
# Package:
#   Configuration of Users
#
# Summary:
#   Client for autoinstallation
#
# Authors:
#   Anas Nashif <nashif@suse.de>
#
# $Id$
#
# This is a client for autoinstallation. It takes its arguments,
# goes through the configuration and return the setting.
# Does not do any changes to the configuration.
module Yast
  class UsersAutoClient < Client
    def main
      Yast.import "UI"
      textdomain "users"
      Yast.import "Mode"
      Yast.import "Users"
      Yast.import "UsersSimple"
      Yast.import "Wizard"

      Yast.include self, "users/wizards.rb"

      @ret = nil
      @func = ""
      @param = {}
      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.convert(
            WFM.Args(1),
            :from => "any",
            :to   => "map <string, any>"
          )
        end
      end
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)


      @users = [
        {
          "username"          => "my_user",
          "user_password"     => "passw",
          "encrypted"         => false,
          #           "uid":501,
          "gid"               => 100,
          "password_settings" => { "expire" => "" },
          "grouplist"         => "audio"
        },
        {
          "username"      => "daemon",
          "user_password" => "pass",
          "encrypted"     => false
        },
        { "username" => "root", "uidNumber" => 0, "user_password" => "pass" }
      ]

      #    param = $["users": users];

      if @func == "Import"
        @ret = Users.Import(@param)
      # create a  summary
      elsif @func == "Summary"
        @ret = Users.Summary
      elsif @func == "Reset"
        Users.Import({})
        @ret = {}
      elsif @func == "Packages"
        @ret = {}
      elsif @func == "Change"
        @start_dialog = "summary" #look to users.ycp for possible values
        Wizard.CreateDialog
        Wizard.SetDesktopIcon("users")
        @ret = AutoSequence(@start_dialog)
        Wizard.CloseDialog
      elsif @func == "Export"
        if Stage.initial
          # Importing all users/groups from the UI if we are
          # in the installation workflow
          Users.SetExportAll(true)
          setup_all_users
        end

        @ret = Users.Export

        if Stage.initial
          #Setting root password in the return value. We are in the inst_sys.
          #The root password has not been written but is only available in
          #UserSimple model. We have to set it manually.
          root = @ret["users"].find { |u| u["uid"] == "0" }
          root["user_password"] = Users.CryptPassword(UsersSimple.GetRootPassword, "system") if root
        end
        Users.SetExportAll(false)
      elsif @func == "Read"
        Yast.import "Progress"
        Users.SetExportAll(true)
        @progress_orig = Progress.set(false)
        @ret = Users.Read == ""
        Progress.set(@progress_orig)
      elsif @func == "Write"
        # NOTE: this code is not executed during autoinstallation (instead, the
        # users_finish is used).
        Yast.import "Progress"
        Users.SetWriteOnly(true)
        @progress_orig = Progress.set(false)
        @ret = Users.Write == ""
        Progress.set(@progress_orig)
        # Return if configuration  was changed
        # return boolean
      elsif @func == "GetModified"
        @ret = Users.Modified
      # Set all modified flags
      # return boolean
      elsif @func == "SetModified"
        Users.SetModified(true)
        @ret = true
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = false
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("users auto finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret)
    end
  end
end

Yast::UsersAutoClient.new.main
