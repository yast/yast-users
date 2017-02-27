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

# File:	include/users/complex.ycp
# Package:	Configuration of users and groups
# Summary:	Dialogs definitions
# Authors:	Johannes Buchhold <jbuch@suse.de>,
#		Jiri Suchomel <jsuchome@suse.cz>
#
# $Id$
module Yast
  module UsersComplexInclude
    def initialize_users_complex(include_target)
      Yast.import "UI"

      textdomain "users"

      Yast.import "Autologin"
      Yast.import "Label"
      Yast.import "Ldap"
      Yast.import "Popup"
      Yast.import "Report"
      Yast.import "Security"
      Yast.import "Stage"
      Yast.import "Users"
      Yast.import "UsersCache"
      Yast.import "UsersDialogsFlags"
      Yast.import "Wizard"

      Yast.include include_target, "users/helps.rb"
    end

    # Return a modification status
    # @return true if data was modified
    def Modified
      Users.Modified || Autologin.modified
    end


    # Read settings dialog
    # @param [Boolean] useUI boolean use user interface (change progress bar)
    # @return [Symbol] `next if success, else `abort
    def ReadDialog(useUI)
      # Set help text
      Wizard.RestoreHelp(ReadDialogHelp()) if useUI

      # A callback function for abort
      abort = lambda { UI.PollInput == :abort }

      Users.SetGUI(useUI)
      ret = :next
      if Users.Read != ""
        ret = :back
        ret = :nextmodule if Stage.cont
      end
      Users.SetGUI(true)
      ret
    end

    # Write settings dialog
    # @param [Boolean] useUI boolean use user interface (change progress bar)
    # @return [Symbol] `next if success, else `abort
    def WriteDialog(useUI)
      # Set help text
      Wizard.RestoreHelp(WriteDialogHelp()) if useUI

      if Users.LDAPModified && (Ldap.anonymous || Ldap.bind_pass == nil)
        # ask for real LDAP password if reading was anonymous
        Ldap.SetBindPassword(Ldap.LDAPAskAndBind(false))
        if Ldap.bind_pass == nil
          # popup text
          return :back if Popup.YesNo(_("Really abort the writing process?"))
        end
      end

      Users.SetGUI(useUI)
      ret = :next
      ret = :abort if !Stage.cont if Users.Write != ""
      Users.SetGUI(true)
      ret
    end

    # Set the module into installation mode with
    # first dialog for single user addition
    # @return [Symbol] for wizard sequencer
    def usersInstStart
      UsersDialogsFlags.assign_start_dialog("user_add")
      Users.AddUser({})
      :next
    end

    # The dialog that appears when the [Abort] button is pressed.
    # @return `abort if user really wants to abort
    def ReallyAbort
      ret = true

      if !Stage.cont
        ret = Modified() ? Popup.ReallyAbort(true) : true
      else
        ret = Popup.ConfirmAbort(:incomplete)
      end

      if ret
        return :abort
      else
        return :back
      end
    end
  end
end
