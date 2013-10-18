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

# File:	include/users/widgets.ycp
# Package:	Configuration of users and groups
# Summary:	Widgets definitions and helper functions
# Authors:	Jiri Suchomel <jsuchome@suse.cz>
#
# $Id$
module Yast
  module UsersLdapDialogsInclude
    def initialize_users_ldap_dialogs(include_target)
      Yast.import "UI"

      Yast.import "Label"
      Yast.import "Ldap"
      Yast.import "LdapPopup"
      Yast.import "Popup"
      Yast.import "Users"
      Yast.import "Wizard"

      Yast.include include_target, "ldap/routines.rb"

      textdomain "users"
    end

    # dialog for Password Policy configuration object
    # @param [Hash] ppolicy data with Password Policy object to be edited (as obtained from LDAP search)
    # @return [Hash] with modifications of ppolicy object, nil in case of `cancel
    def PasswordPolicyDialog(ppolicy)
      ppolicy = deep_copy(ppolicy)
      # reduce the list values to single ones
      ppolicy = Builtins.mapmap(
        Convert.convert(ppolicy, :from => "map", :to => "map <string, any>")
      ) do |a, val|
        if Ops.is_list?(val) &&
            (Ldap.SingleValued(a) || Builtins.size(Convert.to_list(val)) == 1)
          val = Ops.get(Convert.to_list(val), 0)
        end
        val = val == "TRUE" if val == "TRUE" || val == "FALSE"
        { a => val }
      end
      ppolicy_orig = deep_copy(ppolicy)

      # help text for Password Policy Dialog
      help_text = _(
        "<p>Select the <b>Password Change Policies</b>, <b>Password Aging Policies</b>, and <b>Lockout Policies</b> tabs to choose LDAP password policy groups of attributes to configure.</p>"
      )


      # tab-specific help texts
      tabs_help_text = {
        # help text for pwdInHistory attribute
        :pwchange => _(
          "<p>Specify the <b>Maximum Number of Passwords Stored in History</b> to set how many previously used passwords should be saved. Saved passwords may not be used.</p>"
        ) +
          # help text for pwdMustChange attribute
          _(
            "<p>Check <b>User Must Change Password after Reset</b> to force users to change their passwords after the the password is reset or changed by an administrator.</p>"
          ) +
          # help text for pwdAllowUserChange attribute
          _(
            "<p>Check <b>User Can Change Password</b> to allow users to change their passwords.</p>"
          ) +
          # help text for pwdSafeModify attribute
          _(
            "<p>If the existing password must be provided along with the new password, check <b>Old Password Required for Password Change</b>.</p>"
          ) +
          # help text for pwdCheckQuality attribute
          _(
            "<p>Select whether the password quality should be verified while passwords are modified or added. Select <b>No Checking</b> if passwords should not be checked at all. With <b>Accept Uncheckable Passwords</b>, passwords are accepted even if the check cannot be performed, for example, if the user has provided an encrypted password. With <b>Only Accept Checked Passwords</b> passwords are refused if the quality test fails or the password cannot be checked.</p>"
          ) +
          # help text for pwdMinLength attribute
          _(
            "Set the minimum number of characters that must be used in a password in <b>Minimum Password Length</b>.</p>"
          ),
        # help text for pwdMinAge attribute
        :aging    => _(
          "<p><b>Minimum Password Age</b> sets how much time must pass between modifications to the password.</p>"
        ) +
          # help text for pwdMaxAge attribute
          _(
            "<p><b>Maximum Password Age</b> sets how long after modification a password expires.</p>"
          ) +
          # help text for pwdExpireWarning attribute
          _(
            "<p>In <b>Time before Password Expiration to Issue Warning</b> set how long before a password is due to expire that an expiration warning messages should be given to an authenticating user.</p>"
          ) +
          # help text for pwdGraceAuthNLimit attribute
          _(
            "<p>Set the number of times an expired password can be used to authenticate in <b>Allowed Uses of an Expired Password</b>.</p>"
          ),
        # help text for pwdLockout attribute
        :lockout  => _(
          "<p>Check <b>Enable Password Locking</b> to forbid use of a password after a specified number of consecutive failed bind attempts.</p>"
        ) +
          # help text for pwdMaxFailure attribute
          _(
            "<p>Set the number of consecutive failed bind  attempts after which the password may not be used to authenticate in <b>Bind Failures to Lock the Password</b>.</p>"
          ) +
          # help text for pwdLockoutDuration attribute
          _(
            "<p>Set how long the password cannot be used in <b>Password Lock Duration</b>.</p>"
          ) +
          # help text for pwdFailureCountInterval attribute
          _(
            "<p><b>Bind Failures Cache Duration</b> sets how long before password failures are purged from the failure counter even though no successful authentication has occurred.</p>"
          )
      }

      # map of attribute names for each tab
      attributes = {
        :pwchange => [
          "pwdInHistory",
          "pwdMustChange",
          "pwdAllowUserChange",
          "pwdSafeModify",
          "pwdCheckQuality",
          "pwdMinLength"
        ],
        :aging    => [
          "pwdMinAge",
          "pwdMaxAge",
          "pwdExpireWarning",
          "pwdGraceAuthNLimit"
        ],
        :lockout  => [
          "pwdLockout",
          "pwdLockoutDuration",
          "pwdMaxFailure",
          "pwdFailureCountInterval"
        ]
      }

      time_attributes = [
        "pwdMinAge",
        "pwdMaxAge",
        "pwdExpireWarning",
        "pwdLockoutDuration",
        "pwdFailureCountInterval"
      ]

      default_values = {
        "pwdMustChange"      => false,
        "pwdAllowUserChange" => true,
        "pwdSafeModify"      => false,
        "pwdLockout"         => false
      }

      # maximal value of IntFields
      max = 99999

      tabs = [
        # tab label
        Item(Id(:pwchange), _("&Password Change Policies"), true),
        # tab label
        Item(Id(:aging), _("Pa&ssword Aging Policies")),
        # tab label
        Item(Id(:lockout), _("&Lockout Policies"))
      ]
      tabs_term = VBox(
        DumbTab(Id(:tabs), tabs, ReplacePoint(Id(:tabContents), VBox(Empty())))
      )
      has_tabs = true
      if !UI.HasSpecialWidget(:DumbTab)
        has_tabs = false
        tabbar = HBox()
        Builtins.foreach(tabs) do |it|
          label = Ops.get_string(it, 1, "")
          tabbar = Builtins.add(tabbar, PushButton(Ops.get_term(it, 0) do
            Id(label)
          end, label))
        end
        tabs_term = VBox(
          Left(tabbar),
          Frame("", ReplacePoint(Id(:tabContents), Empty()))
        )
      end

      contents = deep_copy(tabs_term)

      # generate the term of password policy tab and update the help text
      set_password_policies_term = lambda do
        pwdcheckquality = Builtins.tointeger(
          Ops.get_string(ppolicy, "pwdCheckQuality", "0")
        )
        tab_cont = Top(
          HBox(
            HSpacing(0.5),
            VBox(
              VSpacing(0.8),
              IntField(
                Id("pwdInHistory"),
                # IntField label
                _("Ma&ximum Number of Passwords Stored in History"),
                0,
                max,
                Builtins.tointeger(Ops.get_string(ppolicy, "pwdInHistory", "0"))
              ),
              VSpacing(0.4),
              Left(
                CheckBox(
                  Id("pwdMustChange"),
                  # checkbox label
                  _("U&ser Must Change Password after Reset"),
                  Ops.get_boolean(ppolicy, "pwdMustChange", true)
                )
              ),
              VSpacing(0.2),
              Left(
                CheckBox(
                  Id("pwdAllowUserChange"),
                  # checkbox label
                  _("&User Can Change Password"),
                  Ops.get_boolean(ppolicy, "pwdAllowUserChange", true)
                )
              ),
              VSpacing(0.2),
              Left(
                CheckBox(
                  Id("pwdSafeModify"),
                  # checkbox label
                  _("&Old Password Required for Password Change"),
                  Ops.get_boolean(ppolicy, "pwdSafeModify", false)
                )
              ),
              VSpacing(0.4),
              # frame label
              HBox(
                HSpacing(2),
                Frame(
                  _("Password Quality Checking"),
                  VBox(
                    VSpacing(0.5),
                    RadioButtonGroup(
                      Id("pwdCheckQuality"),
                      VBox(
                        Left(
                          RadioButton(
                            Id(0),
                            Opt(:notify),
                            _("&No Checking"),
                            pwdcheckquality == 0
                          )
                        ),
                        Left(
                          RadioButton(
                            Id(1),
                            Opt(:notify),
                            _("Acc&ept Uncheckable Passwords"),
                            pwdcheckquality == 1
                          )
                        ),
                        Left(
                          RadioButton(
                            Id(2),
                            Opt(:notify),
                            _("&Only Accept Checked Passwords"),
                            pwdcheckquality == 2
                          )
                        )
                      )
                    ),
                    VSpacing(0.4),
                    # IntField label
                    IntField(
                      Id("pwdMinLength"),
                      _("&Minimum Password Length"),
                      0,
                      max,
                      Builtins.tointeger(
                        Ops.get_string(ppolicy, "pwdMinLength", "0")
                      )
                    )
                  )
                )
              )
            ),
            HSpacing(0.5)
          )
        )

        UI.ReplaceWidget(:tabContents, tab_cont)
        UI.ChangeWidget(
          Id("pwdMinLength"),
          :Enabled,
          Ops.greater_than(pwdcheckquality, 0)
        )
        nil
      end

      time_dialog = lambda do |id, label|
        value = Builtins.tointeger(Ops.get_string(ppolicy, id, "0"))
        days = Ops.divide(value, 24 * 60 * 60)
        if Ops.greater_than(days, 0)
          value = Ops.subtract(
            value,
            Ops.multiply(Ops.multiply(Ops.multiply(days, 24), 60), 60)
          )
        end
        hours = Ops.divide(value, 60 * 60)
        if Ops.greater_than(hours, 0)
          value = Ops.subtract(value, Ops.multiply(Ops.multiply(hours, 60), 60))
        end
        minutes = Ops.divide(value, 60)
        if Ops.greater_than(minutes, 0)
          value = Ops.subtract(value, Ops.multiply(minutes, 60))
        end
        HBox(
          HSpacing(0.3),
          Frame(
            label,
            HBox(
              IntField(Id(Ops.add(id, "d")), _("Days"), 0, max, days),
              IntField(Id(Ops.add(id, "h")), _("Hours"), 0, 23, hours),
              IntField(Id(Ops.add(id, "m")), _("Minutes"), 0, 59, minutes),
              IntField(Id(Ops.add(id, "s")), _("Seconds"), 0, 59, value)
            )
          ),
          HSpacing(0.3)
        )
      end

      get_seconds_value = lambda do |attr|
        days = Convert.to_integer(
          UI.QueryWidget(Id(Ops.add(attr, "d")), :Value)
        )
        hours = Convert.to_integer(
          UI.QueryWidget(Id(Ops.add(attr, "h")), :Value)
        )
        minutes = Convert.to_integer(
          UI.QueryWidget(Id(Ops.add(attr, "m")), :Value)
        )
        seconds = Convert.to_integer(
          UI.QueryWidget(Id(Ops.add(attr, "s")), :Value)
        )
        Ops.add(
          Ops.add(
            Ops.add(
              Ops.multiply(Ops.multiply(Ops.multiply(days, 24), 60), 60),
              Ops.multiply(Ops.multiply(hours, 60), 60)
            ),
            Ops.multiply(minutes, 60)
          ),
          seconds
        )
      end

      # generate the term of password aging tab
      set_aging_policies_term = lambda do
        tab_cont = Top(
          HBox(
            HSpacing(0.5),
            VBox(
              VSpacing(0.7),
              # frame label
              time_dialog.call("pwdMinAge", _("Minimum Password Age")),
              VSpacing(0.4),
              # frame label
              time_dialog.call("pwdMaxAge", _("Maximum Password Age")),
              VSpacing(0.4),
              time_dialog.call(
                "pwdExpireWarning",
                # frame label
                _("Time before Password Expiration to Issue Warning")
              ),
              VSpacing(0.2),
              IntField(
                Id("pwdGraceAuthNLimit"),
                # IntField label
                _("Allowed Uses of an Expired Password"),
                0,
                max,
                Builtins.tointeger(
                  Ops.get_string(ppolicy, "pwdGraceAuthNLimit", "0")
                )
              )
            ),
            HSpacing(0.5)
          )
        )
        UI.ReplaceWidget(:tabContents, tab_cont)
        nil
      end

      # generate the term of lockout aging tab
      set_lockout_policies_term = lambda do
        pwdlockout = Ops.get_boolean(ppolicy, "pwdLockout", false)

        tab_cont = Top(
          HBox(
            HSpacing(0.5),
            VBox(
              VSpacing(0.8),
              Left(
                CheckBox(
                  Id("pwdLockout"),
                  Opt(:notify),
                  # check box label
                  _("Enable Password Locking"),
                  pwdlockout
                )
              ),
              VSpacing(0.4),
              IntField(
                Id("pwdMaxFailure"),
                # intField label
                _("Bind Failures to Lock the Password"),
                0,
                max,
                Builtins.tointeger(
                  Ops.get_string(ppolicy, "pwdMaxFailure", "0")
                )
              ),
              # frame label
              time_dialog.call(
                "pwdLockoutDuration",
                _("Password Lock Duration")
              ),
              VSpacing(0.4),
              time_dialog.call(
                "pwdFailureCountInterval",
                # frame label
                _("Bind Failures Cache Duration")
              )
            ),
            HSpacing(0.5)
          )
        )

        UI.ReplaceWidget(:tabContents, tab_cont)
        UI.ChangeWidget(Id("pwdMaxFailure"), :Enabled, pwdlockout)
        Builtins.foreach(["d", "h", "m", "s"]) do |suffix|
          UI.ChangeWidget(
            Id(Ops.add("pwdLockoutDuration", suffix)),
            :Enabled,
            pwdlockout
          )
          UI.ChangeWidget(
            Id(Ops.add("pwdFailureCountInterval", suffix)),
            :Enabled,
            pwdlockout
          )
        end
        nil
      end

      current_tab = :pwchange
      result = nil

      Wizard.OpenNextBackDialog

      # dialog label
      Wizard.SetContentsButtons(
        _("Password Policy Configuration"),
        contents,
        Ops.add(help_text, Ops.get_string(tabs_help_text, current_tab, "")),
        Label.CancelButton,
        Label.OKButton
      )
      Wizard.HideAbortButton

      set_password_policies_term.call

      while true
        result = UI.UserInput

        if Ops.is_symbol?(result) &&
            Builtins.contains(
              [:back, :cancel, :abort],
              Convert.to_symbol(result)
            )
          break
        end

        # save the values from UI
        Builtins.foreach(Ops.get_list(attributes, current_tab, [])) do |attr|
          if Builtins.contains(time_attributes, attr)
            Ops.set(
              ppolicy,
              attr,
              Builtins.sformat("%1", get_seconds_value.call(attr))
            )
            next
          end
          val = UI.QueryWidget(Id(attr), :Value)
          val = Builtins.sformat("%1", val) if Ops.is_integer?(val)
          Ops.set(ppolicy, attr, val)
        end

        if (result == :pwchange || result == :aging || result == :lockout) &&
            result != current_tab
          if result == :pwchange
            set_password_policies_term.call
          elsif result == :aging
            set_aging_policies_term.call
          elsif result == :lockout
            set_lockout_policies_term.call
          end
          current_tab = Convert.to_symbol(result)
          UI.ChangeWidget(Id(:tabs), :CurrentItem, current_tab) if has_tabs
          Wizard.SetHelpText(
            Ops.add(help_text, Ops.get_string(tabs_help_text, current_tab, ""))
          )
          next
        end
        if result == :next
          cont = false

          # check the template required attributes...
          Builtins.foreach(Ops.get_list(ppolicy, "objectClass", [])) do |oc|
            next if cont
            Builtins.foreach(Ldap.GetRequiredAttributes(oc)) do |attr|
              val = Ops.get(ppolicy, attr)
              if !cont && val == nil || val == [] || val == ""
                #error popup, %1 is attribute name
                Popup.Error(
                  Builtins.sformat(
                    _("The \"%1\" attribute is mandatory.\nEnter a value."),
                    attr
                  )
                )
                UI.SetFocus(Id(:table))
                cont = true
              end
            end
          end
          next if cont
          break
        end
        # now solve events inside the tabs
        if current_tab == :pwchange && Ops.is_integer?(result)
          UI.ChangeWidget(Id("pwdMinLength"), :Enabled, result != 0)
        end
        if current_tab == :lockout && result == "pwdLockout"
          pwdlockout = Convert.to_boolean(
            UI.QueryWidget(Id("pwdLockout"), :Value)
          )
          UI.ChangeWidget(Id("pwdMaxFailure"), :Enabled, pwdlockout)
          Builtins.foreach(["d", "h", "m", "s"]) do |suffix|
            UI.ChangeWidget(
              Id(Ops.add("pwdFailureCountInterval", suffix)),
              :Enabled,
              pwdlockout
            )
            UI.ChangeWidget(
              Id(Ops.add("pwdLockoutDuration", suffix)),
              :Enabled,
              pwdlockout
            )
          end
        end
      end
      Wizard.CloseDialog

      ret = {}
      if result == :next
        Builtins.foreach(
          Convert.convert(ppolicy, :from => "map", :to => "map <string, any>")
        ) do |key, val|
          if !Builtins.haskey(ppolicy_orig, key) &&
              (val == Ops.get(default_values, key) || val == "0")
            next
          end
          if val != Ops.get(ppolicy_orig, key)
            val = val == true ? "TRUE" : "FALSE" if Ops.is_boolean?(val)
            Ops.set(ret, key, val)
          end
        end
      end
      result == :next ? deep_copy(ret) : nil
    end

    # Dialog for administering User & Group specific LDAP settigns
    def LdapAdministrationDialog
      Users.SetLdapSettingsRead(Ldap.Read) if !Users.LdapSettingsRead

      base_dn = Ldap.GetBaseDN
      file_server = Ldap.file_server
      modified = true

      ppolicy_list = []

      ppolicies_enabled = false
      ppolicies = {}
      ppolicies_orig = {}
      ppolicies_deleted = [] # list of DN

      # map with modifications of Password Policies objects
      write_ppolicies = {}

      # read the list of pwdpolicy objects under base_config_dn
      read_ppolicies = lambda do
        return if base_dn == ""

        if Ldap.ldap_initialized && Ldap.tls_when_initialized != Ldap.ldap_tls
          Ldap.LDAPClose
        end

        if Ldap.ldap_initialized || Ldap.LDAPInit == ""
          ppolicies_enabled = Convert.to_boolean(
            SCR.Execute(
              path(".ldap.ppolicy"),
              {
                "hostname" => Ldap.GetFirstServer(Ldap.server),
                "bind_dn"  => Ldap.GetBaseDN
              }
            )
          )

          schemas = Convert.to_list(
            SCR.Read(
              path(".ldap.search"),
              {
                "base_dn" => "",
                "attrs"   => ["subschemaSubentry"],
                "scope"   => 0
              }
            )
          )
          schema_dn = Ops.get_string(schemas, [0, "subschemaSubentry", 0], "")
          if schemas != nil && schema_dn != "" &&
              SCR.Execute(path(".ldap.schema"), { "schema_dn" => schema_dn }) == true
            pp = Convert.convert(
              SCR.Read(
                path(".ldap.search"),
                {
                  "base_dn"      => base_dn,
                  "filter"       => "objectClass=pwdPolicy",
                  "scope"        => 2,
                  "map"          => true,
                  "not_found_ok" => true
                }
              ),
              :from => "any",
              :to   => "map <string, map>"
            )
            if pp != nil
              ppolicies = deep_copy(pp)
              ppolicies_orig = deep_copy(ppolicies)
            end
          end
        end

        nil
      end

      read_ppolicies.call

      help_text = _("<p><b>Home Directories</b></p>") +
        # help text
        _(
          "<p>If home directories of LDAP users should be stored on this machine,\n" +
            "check the appropriate option. Changing this value does not cause any direct\n" +
            "action.  It is only information for the YaST users module, which can manage\n" +
            "user home directories.</p>\n"
        ) + # help text caption
        # help text
        _(
          "<p>Press <b>Configure</b> to configure settings stored on the\n" +
            "LDAP server. You will be asked for the password if you are not connected yet or\n" +
            "have changed your configuration.</p>\n"
        ) +
        # password policy help text caption
        _("<p><b>Password Policy</b></p>") +
        # password policy help
        _(
          "<p>Configure the selected password policy with <b>Edit</b>. Use <b>Add</b> to add a new password policy. The configuration is only possible,\n  if the password policies are already enabled on the LDAP server.</p>"
        )

      contents = VBox(
        VSpacing(0.4),
        Left(
          CheckBox(
            Id(:file_server),
            # checkbox label
            _("&Home Directories on This Machine"),
            file_server
          )
        ),
        VSpacing(0.5),
        Right(
          PushButton(
            Id(:configure),
            # pushbutton label
            _("Configure User Management &Settings...")
          )
        ),
        VSpacing(),
        Table(
          Id(:ppolicy_table),
          Opt(:notify),
          Header(
            # table header
            _("Password Policy")
          ),
          Builtins.maplist(ppolicies) { |dn, pp| Item(Id(dn), dn) }
        ),
        HBox(
          PushButton(Id(:add), Label.AddButton),
          PushButton(Id(:edit), Label.EditButton),
          PushButton(Id(:delete), Label.DeleteButton),
          HStretch()
        ),
        VSpacing(0.4)
      )

      Wizard.CreateDialog
      # dialog title
      Wizard.SetContentsButtons(
        _("LDAP Administration Settings"),
        contents,
        help_text,
        Label.CancelButton,
        Label.OKButton
      )
      Wizard.HideAbortButton

      Builtins.foreach([:ppolicy_table, :add, :edit, :delete]) do |s|
        UI.ChangeWidget(Id(s), :Enabled, ppolicies_enabled)
      end

      ret = :cancel

      while true
        ret = Convert.to_symbol(UI.UserInput)
        if ret == :add
          suffix = base_dn
          UI.OpenDialog(
            Opt(:decorated),
            HBox(
              HSpacing(1),
              VBox(
                # InputField label
                InputField(
                  Id(:cn),
                  Opt(:hstretch),
                  _("Name of Password Policy Object")
                ),
                ReplacePoint(
                  Id(:rp_suf),
                  HBox(
                    # text label,suffix will follow in next label
                    Label(Id(:suffix_label), _("Suffix:")),
                    Label(Id(:suffix), base_dn),
                    # pushbutton label
                    PushButton(Id(:br_suf), _("Change Suffix"))
                  )
                ),
                ButtonBox(
                  PushButton(Id(:ok), Opt(:default, :key_F10), Label.OKButton),
                  PushButton(Id(:cancel), Opt(:key_F9), Label.CancelButton)
                )
              ),
              HSpacing(1)
            )
          )
          UI.SetFocus(Id(:cn))
          ret2 = nil
          new_dn = ""
          while true
            ret2 = UI.UserInput
            break if ret2 == :cancel
            if ret2 == :br_suf
              suf = LdapPopup.InitAndBrowseTree(
                base_dn,
                {
                  "hostname"   => Ldap.GetFirstServer(Ldap.server),
                  "port"       => Ldap.GetFirstPort(Ldap.server),
                  "use_tls"    => Ldap.ldap_tls ? "yes" : "no",
                  "cacertdir"  => Ldap.tls_cacertdir,
                  "cacertfile" => Ldap.tls_cacertfile
                }
              )
              if suf != ""
                UI.ReplaceWidget(
                  Id(:rp_suf),
                  HBox(
                    # text label,suffix will follow in next label
                    Label(Id(:suffix_label), _("Suffix:")),
                    Label(Id(:suffix), suf),
                    # pushbutton label
                    PushButton(Id(:br_suf), _("Change Suffix"))
                  )
                )
              end
            end
            if ret2 == :ok
              cn = Convert.to_string(UI.QueryWidget(Id(:cn), :Value))
              break if cn == ""
              suffix2 = Convert.to_string(UI.QueryWidget(Id(:suffix), :Value))
              new_dn = Builtins.sformat("cn=%1,%2", cn, suffix2)
              if Builtins.haskey(ppolicies, new_dn)
                Popup.Error(
                  Builtins.sformat(
                    _(
                      "The Policy '%1' already exists.\nPlease select another one."
                    ),
                    new_dn
                  )
                )
                next
              end
              break
            end
          end
          UI.CloseDialog
          if ret2 == :ok && new_dn != ""
            new = PasswordPolicyDialog({ "dn" => new_dn })
            if new != nil
              Ops.set(ppolicies, new_dn, new)
              UI.ChangeWidget(
                Id(:ppolicy_table),
                :Items,
                Builtins.maplist(ppolicies) { |dn, pp| Item(Id(dn), dn) }
              )
              UI.ChangeWidget(
                Id(:edit),
                :Enabled,
                Ops.greater_than(Builtins.size(ppolicies), 0)
              )
              UI.ChangeWidget(
                Id(:delete),
                :Enabled,
                Ops.greater_than(Builtins.size(ppolicies), 0)
              )
            end
          end
        end
        if ret == :edit || ret == :ppolicy_table
          dn = Convert.to_string(
            UI.QueryWidget(Id(:ppolicy_table), :CurrentItem)
          )
          changes = PasswordPolicyDialog(Ops.get(ppolicies, dn, {}))
          if changes != nil
            Ops.set(
              ppolicies,
              dn,
              Builtins.union(Ops.get(ppolicies, dn, {}), changes)
            )
          end
        end
        if ret == :delete
          dn = Convert.to_string(
            UI.QueryWidget(Id(:ppolicy_table), :CurrentItem)
          )
          ppolicies = Builtins.remove(ppolicies, dn)
          ppolicies_deleted = Convert.convert(
            Builtins.union(ppolicies_deleted, [dn]),
            :from => "list",
            :to   => "list <string>"
          )
          UI.ChangeWidget(
            Id(:ppolicy_table),
            :Items,
            Builtins.maplist(ppolicies) { |dn2, pp| Item(Id(dn2), dn2) }
          )
          UI.ChangeWidget(
            Id(:edit),
            :Enabled,
            Ops.greater_than(Builtins.size(ppolicies), 0)
          )
          UI.ChangeWidget(
            Id(:delete),
            :Enabled,
            Ops.greater_than(Builtins.size(ppolicies), 0)
          )
        end
        # open "LDAP User objects configuration"
        if ret == :configure
          result = WFM.CallFunction("ldap_config")
          modified = true if result == :next
          next
        end
        break if ret == :back || ret == :cancel || ret == :abort
        if ret == :next
          file_server = Convert.to_boolean(
            UI.QueryWidget(Id(:file_server), :Value)
          )
          if file_server != Ldap.file_server
            Users.SetLdapSysconfigModified(true)
            Ldap.file_server = file_server
          end
          Builtins.foreach(ppolicies) do |dn, ppolicy|
            # new ppolicy
            if !Builtins.haskey(ppolicies_orig, dn)
              Ops.set(ppolicy, "modified", "added")
              Ops.set(ppolicy, "pwdAttribute", "userPassword")
              Ops.set(ppolicy, "objectClass", ["pwdPolicy", "namedObject"])
              Ops.set(ppolicy, "cn", get_cn(dn))
              Ops.set(write_ppolicies, dn, ppolicy)
            else
              pp = {}
              Builtins.foreach(
                Convert.convert(
                  ppolicy,
                  :from => "map",
                  :to   => "map <string, any>"
                )
              ) do |a, val|
                Ops.set(pp, a, val) if val != Ops.get(ppolicies_orig, [dn, a])
              end
              if pp != {}
                Ops.set(pp, "modified", "edited")
                Ops.set(write_ppolicies, dn, pp)
              end
            end
          end
          # deleted ppolicies
          Builtins.foreach(ppolicies_deleted) do |dn|
            pp = Ops.get(write_ppolicies, dn, {})
            if Ops.get_string(pp, "modified", "") == "added"
              write_ppolicies = Builtins.remove(write_ppolicies, dn)
            elsif Builtins.haskey(ppolicies_orig, dn)
              Ops.set(pp, "modified", "deleted")
              Ops.set(write_ppolicies, dn, pp)
            end
          end
          if write_ppolicies != {}
            Ldap.WriteLDAP(write_ppolicies)
            write_ppolicies = {}
          end
          break
        end
      end
      Wizard.CloseDialog
      modified || ret == :next
    end
  end
end
