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

# File:	include/users/users_finish.ycp
# Package:	Configuration of users and groups
# Summary:	Installation client for writing users configuration
#		at the end of 1st stage
# Authors:	Jiri Suchomel <jsuchome@suse.cz>
#
# $Id$

require "installation/minimal_installation"

module Yast
  class UsersFinishClient < Client
    def main
      textdomain "users"

      Yast.import "Users"
      Yast.import "UsersSimple"

      # create_users()
      Yast.include self, "users/routines.rb"

      @func = ""
      @param = {}

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.to_map(WFM.Args(1))
        end
      end

      Builtins.y2milestone("starting users_finish")
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      if @func == "Info"
        minimal_inst = Installation::MinimalInstallation.instance.enabled?
        return {
          "steps" => 1,
          # progress step title
          "title" => _("Writing Users Configuration..."),
          "when"  => minimal_inst ? [] :
            [:installation, :live_installation, :autoinst]
        }
      elsif @func == "Write"
        # disable UI (progress)
        Users.SetGUI(false)

        # write the root password
        UsersSimple.Write

        @users = UsersSimple.GetUsers

        if !@users.empty?
          Users.Read
          Users.ResetCurrentUser
          Builtins.y2milestone("There are #{@users.size} users to import")

          create_users(@users)

          Users.Write
        end
      else
        Builtins.y2error("unknown function: %1", @func)
      end

      Builtins.y2milestone("users_finish finished")
      nil
    end
  end
end

Yast::UsersFinishClient.new.main
