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
#	include/users/users_plugin_ldap_shadowaccount.ycp
#
# Package:
#	Configuration of Users
#
# Summary:
#	This is GUI part of UsersPluginLDAPShadowAccount
#	- plugin for editing ShadowAccount LDAP user attributes.
#
# Authors:
#	Jiri Suchomel <jsuchome@suse.cz>
#

require "shellwords"

module Yast
  class UsersPluginLdapShadowaccountClient < Client
    def main
      Yast.import "UI"
      textdomain "users"

      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Report"
      Yast.import "Users"
      Yast.import "UsersPluginLDAPShadowAccount" # plugin module
      Yast.import "Wizard"

      Yast.include self, "users/helps.rb"
      Yast.include self, "users/routines.rb"

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
      Builtins.y2milestone("users plugin started: LDAPShadowAccount")

      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("config=%1", @config)
      Builtins.y2debug("data=%1", @data)

      if @func == "Summary"
        @ret = UsersPluginLDAPShadowAccount.Summary(@config, {})
      elsif @func == "Name"
        @ret = UsersPluginLDAPShadowAccount.Name(@config, {})
      elsif @func == "Dialog"
        @caption = UsersPluginLDAPShadowAccount.Name(@config, {})
        @tmp_data = {}

        @help_text = EditUserPasswordDialogHelp()

        # date of password expiration
        @exp_date = ""

        @last_change = GetString(Ops.get(@data, "shadowLastChange"), "0")
        @expires = GetString(Ops.get(@data, "shadowExpire"), "0")
        @expires = "0" if @expires == ""

        @inact = GetInt(Ops.get(@data, "shadowInactive"), 0)
        @max = GetInt(Ops.get(@data, "shadowMax"), 0)
        @min = GetInt(Ops.get(@data, "shadowMin"), 0)
        @warn = GetInt(Ops.get(@data, "shadowWarning"), 0)

        if @last_change != "0"
          @out = Convert.to_map(
            SCR.Execute(
              path(".target.bash_output"),
              Builtins.sformat(
                "/usr/bin/date --date='1970-01-01 00:00:01 '%1' days' +\"%%x\"",
                @last_change.to_s.shellescape
              )
            )
          )
          # label (date of last password change)
          @last_change = Ops.get_locale(@out, "stdout", _("Unknown"))
        else
          # label (date of last password change)
          @last_change = _("Never")
        end
        if @expires != "0" && @expires != "-1" && @expires != ""
          @out = SCR.Execute(
            path(".target.bash_output"),
            "/usr/bin/date --date='1970-01-01 00:00:01 '#{@expires.to_s.shellescape}' days' +\"%Y-%m-%d\""
          )
          # remove \n from the end
          @exp_date = Builtins.deletechars(
            Ops.get_string(@out, "stdout", ""),
            "\n"
          )
        end
        @contents = HBox(
          HSpacing(3),
          VBox(
            VStretch(),
            Left(Label("")),
            HSquash(
              VBox(
                Left(
                  Label(
                    Builtins.sformat(
                      # label
                      _("Last Password Change: %1"),
                      @last_change
                    )
                  )
                ),
                VSpacing(1),
                IntField(
                  Id("shadowWarning"),
                  # intfield label
                  _("Days &before Password Expiration to Issue Warning"),
                  -1,
                  99999,
                  @warn
                ),
                VSpacing(0.5),
                IntField(
                  Id("shadowInactive"),
                  # intfield label
                  _("Days after Password Expires with Usable &Login"),
                  -1,
                  99999,
                  @inact
                ),
                VSpacing(0.5),
                IntField(
                  Id("shadowMax"),
                  # intfield label
                  _("Ma&ximum Number of Days for the Same Password"),
                  -1,
                  99999,
                  @max
                ),
                VSpacing(0.5),
                IntField(
                  Id("shadowMin"),
                  # intfield label
                  _("&Minimum Number of Days for the Same Password"),
                  -1,
                  99999,
                  @min
                ),
                VSpacing(0.5),
                TextEntry(
                  Id("shadowExpire"),
                  # textentry label
                  _("Ex&piration Date"),
                  @exp_date
                )
              )
            ),
            VStretch()
          ),
          HSpacing(3)
        )

        Wizard.CreateDialog
        Wizard.SetDesktopIcon("org.openSUSE.YaST.Users")

        # dialog caption
        Wizard.SetContentsButtons(
          _("Shadow Account Settings"),
          @contents,
          EditUserPasswordDialogHelp(),
          Label.CancelButton,
          Label.OKButton
        )

        Wizard.HideAbortButton

        @ret = :next
        begin
          @ret = UI.UserInput
          if @ret == :next
            @exp = Convert.to_string(UI.QueryWidget(Id("shadowExpire"), :Value))
            if @exp != "" &&
                !Builtins.regexpmatch(
                  @exp,
                  "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]"
                )
              # popup text: Don't reorder the letters YYYY-MM-DD!!!
              # The date must stay in this format
              Popup.Message(
                _("The expiration date must be in the format YYYY-MM-DD.")
              )
              UI.SetFocus(Id("shadowExpire"))
              next
            end

            Builtins.foreach(
              ["shadowWarning", "shadowMax", "shadowMin", "shadowInactive"]
            ) do |shadowsymbol|
              sval = Builtins.sformat(
                "%1",
                UI.QueryWidget(Id(shadowsymbol), :Value)
              )
              if Builtins.sformat("%1", Ops.get_string(@data, shadowsymbol, "")) != sval
                Ops.set(@tmp_data, shadowsymbol, sval)
              end
            end

            @new_exp_date = Convert.to_string(
              UI.QueryWidget(Id("shadowExpire"), :Value)
            )
            if @new_exp_date != @exp_date
              @exp_date = @new_exp_date
              if @exp_date == ""
                Ops.set(@tmp_data, "shadowExpire", "")
              else
                @out = SCR.Execute(
                  path(".target.bash_output"),
                  "/usr/bin/date --date=#{@exp_date.to_s.shellescape}' UTC' +%s"
                )
                @seconds_s = Builtins.deletechars(
                  Ops.get_string(@out, "stdout", "0"),
                  "\n"
                )
                if @seconds_s != ""
                  @days = Ops.divide(
                    Builtins.tointeger(@seconds_s),
                    60 * 60 * 24
                  )
                  Ops.set(
                    @tmp_data,
                    "shadowExpire",
                    Builtins.sformat("%1", @days)
                  )
                end
              end
            end
            @err = UsersPluginLDAPShadowAccount.Check(
              @config,
              Convert.convert(
                Builtins.union(@data, @tmp_data),
                :from => "map",
                :to   => "map <string, any>"
              )
            )

            if @err != ""
              Report.Error(@err)
              @ret = :notnext
              next
            end

            break if @tmp_data == {}
            # if this plugin wasn't in default set, we must save its name
            if !Builtins.contains(
                Ops.get_list(@data, "plugins", []),
                "UsersPluginLDAPShadowAccount"
              )
              Ops.set(
                @tmp_data,
                "plugins",
                Builtins.add(
                  Ops.get_list(@tmp_data, "plugins", []),
                  "UsersPluginLDAPShadowAccount"
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

Yast::UsersPluginLdapShadowaccountClient.new.main
