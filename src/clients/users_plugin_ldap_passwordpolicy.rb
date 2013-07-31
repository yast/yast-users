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
#	include/users/users_plugin_ldap_passwordpolicy.ycp
#
# Package:
#	Configuration of Users
#
# Summary:
#	This is GUI part of UsersPluginLDAPPasswordPolicy
#	- plugin for editing LDAP user password policy (see feature 301179)
#
# Authors:
#	Jiri Suchomel <jsuchome@suse.cz>
#
# $Id$
module Yast
  class UsersPluginLdapPasswordpolicyClient < Client
    def main
      Yast.import "UI"
      textdomain "users"

      Yast.import "Label"
      Yast.import "LdapPopup"
      Yast.import "Report"
      Yast.import "Users"
      Yast.import "UsersPluginLDAPPasswordPolicy" # plugin module
      Yast.import "Wizard"

      @ret = nil
      @func = ""
      @config = {}
      @data = {}

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @config = Convert.convert(
            WFM.Args(1),
            :from => "any",
            :to   => "map <string, any>"
          )
        end
        if Ops.greater_than(Builtins.size(WFM.Args), 2) &&
            Ops.is_map?(WFM.Args(2))
          @data = Convert.convert(
            WFM.Args(2),
            :from => "any",
            :to   => "map <string, any>"
          )
        end
      end
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("users plugin started: LDAPPasswordPolicy")

      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("config=%1", @config)
      Builtins.y2debug("data=%1", @data)

      if @func == "Summary"
        @ret = UsersPluginLDAPPasswordPolicy.Summary(@config, {})
      elsif @func == "Name"
        @ret = UsersPluginLDAPPasswordPolicy.Name(@config, {})
      elsif @func == "Dialog"
        @caption = UsersPluginLDAPPasswordPolicy.Name(@config, {})
        @tmp_data = {}

        # helptext
        @help_text = _(
          "<p>Assign a password policy object to this user in <b>DN of Password Policy object</b>. Activate <b>Reset Password</b> to reset the password of modified user.</p>"
        )

        @pwdreset = Ops.get_string(@data, "pwdReset", "FALSE") == "TRUE"
        @pwdpolicysubentry = Ops.get_string(@data, "pwdPolicySubentry", "")
        @usedefault = @pwdpolicysubentry == ""

        @contents = HBox(
          HSpacing(3),
          VBox(
            Left(
              CheckBox(
                Id(:usedefault),
                Opt(:notify),
                # check box label
                _("Use &Default Password Policy"),
                @usedefault
              )
            ),
            HBox(
              # text entry label
              TextEntry(
                Id("pwdPolicySubentry"),
                _("DN of &Password Policy object"),
                @pwdpolicysubentry
              ),
              VBox(Label(""), PushButton(Id(:browse), Label.BrowseButton))
            ),
            Left(CheckBox(Id("pwdReset"), _("&Reset Password"), @pwdreset))
          ),
          HSpacing(3)
        )

        Wizard.CreateDialog
        Wizard.SetDesktopIcon("users")

        # dialog caption
        Wizard.SetContentsButtons(
          _("Password Policy Settings"),
          @contents,
          @help_text,
          Label.CancelButton,
          Label.OKButton
        )

        Wizard.HideAbortButton
        if @usedefault
          UI.ChangeWidget(Id(:browse), :Enabled, false)
          UI.ChangeWidget(Id("pwdPolicySubentry"), :Enabled, false)
        end

        @ret = :next
        begin
          @ret = UI.UserInput
          if @ret == :browse
            @dn = LdapPopup.BrowseTree("")
            UI.ChangeWidget(Id("pwdPolicySubentry"), :Value, @dn) if @dn != ""
          elsif @ret == :usedefault
            @usedefault = Convert.to_boolean(
              UI.QueryWidget(Id(:usedefault), :Value)
            )
            UI.ChangeWidget(Id(:browse), :Enabled, !@usedefault)
            UI.ChangeWidget(Id("pwdPolicySubentry"), :Enabled, !@usedefault)
          elsif @ret == :next
            @new_pwdpolicysubentry = ""
            if !@usedefault
              @new_pwdpolicysubentry = Convert.to_string(
                UI.QueryWidget(Id("pwdPolicySubentry"), :Value)
              )
            end

            if @new_pwdpolicysubentry != @pwdpolicysubentry
              Ops.set(@tmp_data, "pwdPolicySubentry", @new_pwdpolicysubentry)
            end

            @new_pwdreset = Convert.to_boolean(
              UI.QueryWidget(Id("pwdReset"), :Value)
            )
            if @new_pwdreset != @pwdreset
              Ops.set(@tmp_data, "pwdReset", @new_pwdreset ? "TRUE" : "FALSE")
            end

            break if @tmp_data == {}

            @err = UsersPluginLDAPPasswordPolicy.Check(@config, @tmp_data)

            if @err != ""
              Report.Error(@err)
              @ret = :notnext
              next
            end

            # if this plugin wasn't in default set, we must save its name
            if !Builtins.contains(
                Ops.get_list(@data, "plugins", []),
                "UsersPluginLDAPPasswordPolicy"
              )
              Ops.set(
                @tmp_data,
                "plugins",
                Builtins.add(
                  Ops.get_list(@tmp_data, "plugins", []),
                  "UsersPluginLDAPPasswordPolicy"
                )
              )
            end
            if Ops.get_string(@data, "what", "") == "edit_user"
              Users.EditUser(@tmp_data)
            elsif Ops.get_string(@data, "what", "") == "add_user"
              Users.AddUser(@tmp_data)
            end
          end
        end until Ops.is_symbol?(@ret) &&
          Builtins.contains(
            [:next, :abort, :back, :cancel],
            Convert.to_symbol(@ret)
          )

        Wizard.CloseDialog
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = false
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("users plugin finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret)
    end
  end
end

Yast::UsersPluginLdapPasswordpolicyClient.new.main
