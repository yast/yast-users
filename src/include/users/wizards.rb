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

# File:	include/users/wizards.ycp
# Package:	Configuration of users and groups
# Summary:	Wizards definitions
# Authors:	Johannes Buchhold <jbuch@suse.de>,
#          Jiri Suchomel <jsuchome@suse.cz>
#
# $Id$
module Yast
  module UsersWizardsInclude
    def initialize_users_wizards(include_target)
      Yast.import "UI"

      textdomain "users"

      Yast.import "CWM"
      Yast.import "CWMTab"
      Yast.import "Label"
      Yast.import "Mode"
      Yast.import "Popup"
      Yast.import "Sequencer"
      Yast.import "Stage"
      Yast.import "UsersCache"
      Yast.import "Users"
      Yast.import "Wizard"

      Yast.include include_target, "users/complex.rb"
      Yast.include include_target, "users/dialogs.rb"
      Yast.include include_target, "users/widgets.rb"
    end

    # ------------------ CWM ---------------------------------------------------
    # --------------------------------------------------------------------------

    def ReallyBack
      if !Stage.cont && Users.Modified
        return Popup.ReallyAbort(Users.Modified)
      else
        return true
      end
    end

    # Before showing the table for first time,
    # read NIS if they are included in custom set
    def InitializeTableItems
      if UsersCache.CustomizedUsersView || UsersCache.CustomizedGroupsView
        Users.ChangeCurrentUsers("custom") if UsersCache.CustomizedUsersView
        Users.ChangeCurrentGroups("custom") if UsersCache.CustomizedGroupsView
      end
      :next
    end

    # run the main (Summary) dialog via CWM
    def SummaryDialog
      Ops.set(
        @widgets,
        "tab_users_groups",
        CWMTab.CreateWidget(
          {
            "tab_order"    => ["users", "groups", "defaults", "authentication"],
            "tabs"         => @tabs_description,
            "widget_descr" => @widgets,
            "initial_tab"  => UsersCache.GetCurrentSummary
          }
        )
      )

      contents = VBox("tab_users_groups")

      ret = CWM.ShowAndRun(
        {
          "widget_names"       => ["tab_users_groups"],
          "widget_descr"       => @widgets,
          "contents"           => contents,
          # dialog caption
          "caption"            => _(
            "User and Group Administration"
          ),
          "back_button"        => Stage.cont ? Label.BackButton : "",
          "next_button"        => Stage.cont ? Label.NextButton : Label.OKButton,
          "abort_button"       => Stage.cont ? Label.AbortButton : Label.CancelButton,
          "fallback_functions" => {
            :back => fun_ref(method(:ReallyBack), "boolean ()")
          }
        }
      )
      if ret != nil && Ops.is_symbol?(ret) &&
          Builtins.contains([:new, :edit, :delete], Convert.to_symbol(ret))
        update_symbol = {
          :new    => { "users" => :new_user, "groups" => :new_group },
          :edit   => { "users" => :edit_user, "groups" => :edit_group },
          :delete => { "users" => :delete_user, "groups" => :delete_group }
        }
        ret = Ops.get_symbol(
          update_symbol,
          [ret, UsersCache.GetCurrentSummary],
          :back
        )
      end

      if Stage.cont && (ret == :back || ret == :abort)
        Users.SetStartDialog("user_add")
        Users.SetUseNextTime(true)
        old_gui = Users.GetGUI
        Users.SetGUI(false)
        Users.Read
        Users.SetGUI(old_gui)
        ret = :back
      end

      ret
    end


    # --------------------------------------------------------------------------
    # --------------------------------------------------------------------------


    # Main workflow of the users/groups configuration
    # @param [String] start the first dialog
    # @return sequence result
    def MainSequence(start)
      aliases = {
        "init_summary"    => [lambda { InitializeTableItems() }, true],
        "summary"         => lambda { SummaryDialog() },
        "user_add"        => lambda { EditUserDialog("add_user") },
        "user_add_inst"   => lambda { EditUserDialog("add_user") },
        "user_inst_start" => [lambda { usersInstStart }, true],
        "user_edit"       => lambda { EditUserDialog("edit_user") },
        "user_save"       => [lambda { UserSave() }, true],
        "group_add"       => lambda { EditGroupDialog("add_group") },
        "group_edit"      => lambda { EditGroupDialog("edit_group") },
        "group_save"      => [lambda { GroupSave() }, true],
        "without_save"    => lambda { ReallyAbort() }
      }

      main_sequence = {
        "ws_start"        => "init_summary",
        "init_summary"    => { :next => start },
        "summary"         => {
          :new_user     => "user_add",
          :edit_user    => "user_edit",
          :delete_user  => "user_save",
          :new_group    => "group_add",
          :edit_group   => "group_edit",
          :delete_group => "group_save",
          :abort        => "without_save",
          :cancel       => "without_save",
          :next         => :next,
          :ok           => :next,
          :nosave       => :nosave,
          :exit         => :abort,
          :summary      => "summary"
        },
        "user_add"        => {
          :nextmodule => :next,
          :nosave     => "summary",
          :additional => "user_save",
          # only install
          :next       => "user_save",
          # -> Commit
          :abort      => :abort,
          :cancel     => :abort
        },
        "user_add_inst"   => {
          :nextmodule => :next,
          # no user and next pressed (install)
          :nosave     => "summary",
          :additional => "user_save",
          :next       => "user_save",
          :abort      => "without_save",
          :cancel     => "without_save"
        },
        "user_edit"       => {
          :next   => "user_save",
          :abort  => :abort,
          :cancel => :abort
        },
        "user_inst_start" => { :next => "user_add_inst" },
        "user_save" =>
          #this should be write - during install??
          { :next => "summary", :save => :next },
        "group_add"       => {
          :nosave => "summary",
          :next   => "group_save",
          :abort  => :abort,
          :cancel => :abort
        },
        "group_edit"      => {
          :next   => "group_save",
          :abort  => :abort,
          :cancel => :abort
        },
        "group_save"      => { :next => "summary" },
        "without_save"    => {
          :next  => :next,
          :abort => :abort,
          :back  => :back
        }
      }

      Sequencer.Run(aliases, main_sequence)
    end

    # Whole configuration of users/groups
    # @param [String] start the first dialog
    # @return sequence result
    def UsersSequence(start)
      aliases = {
        "read"  => [lambda { ReadDialog(!Stage.cont) }, true],
        "main"  => lambda { MainSequence(start) },
        "write" => [lambda { WriteDialog(true) }, true]
      } # true as parameter ??

      sequence = {
        "ws_start" => "read",
        "read" =>
          # this is for skiping users conf during install,
          # see Users::CheckHomeMounted() or bug #20365
          { :abort => :abort, :next => "main", :nextmodule => :next },
        "main"     => { :abort => :abort, :next => "write", :nosave => :next },
        "write"    => { :abort => :abort, :next => :next }
      }

      # init dialog caption
      caption = _("User and Group Configuration")
      # label (during init dialog)
      contents = Label(_("Initializing..."))

      Wizard.OpenNextBackDialog if !Stage.cont
      Wizard.SetDesktopIcon("org.opensuse.yast.Users")

      ret = Sequencer.Run(aliases, sequence)

      UI.CloseDialog if !Stage.cont

      Convert.to_symbol(ret)
    end

    # Whole configuration of users/groups but without reading and writing.
    # For use with autoinstallation.
    # @param [String] start the first dialog
    # @return sequence result
    def AutoSequence(start)
      # dialog caption
      caption = _("User and Group Configuration")

      # label (during init dialog)
      contents = Label(_("Initializing..."))

      Wizard.CreateDialog
      Wizard.SetDesktopIcon("org.opensuse.yast.Users")
      Wizard.SetContentsButtons(
        caption,
        contents,
        "",
        Label.BackButton,
        Label.NextButton
      )

      # initialization: ---------------- (simulate empty Import: bug #44660)
      Users.Initialize if Mode.config && !Users.Modified
      # --------------------------------

      ret = MainSequence(start)

      UI.CloseDialog
      ret
    end
  end
end
