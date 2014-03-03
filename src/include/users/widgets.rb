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
  module UsersWidgetsInclude
    def initialize_users_widgets(include_target)
      Yast.import "UI"

      Yast.import "Autologin"
      Yast.import "CWMTab"
      Yast.import "Label"
      Yast.import "Ldap"
      Yast.import "AuthClient"
      Yast.import "Message"
      Yast.import "Mode"
      Yast.import "Package"
      Yast.import "Popup"
      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "Stage"
      Yast.import "String"
      Yast.import "Summary"
      Yast.import "Users"
      Yast.import "UsersCache"
      Yast.import "UsersLDAP"
      Yast.import "UsersRoutines"
      Yast.import "Wizard"

      Yast.include include_target, "users/complex.rb"
      Yast.include include_target, "users/routines.rb"
      Yast.include include_target, "users/ldap_dialogs.rb"

      textdomain "users"

      # values to MenuItem in Summary dialog
      @userset_to_string = {
        # the type of user set
        "system" => _("&System Users"),
        # the type of user set
        "local"  => _("&Local Users"),
        # the type of user set
        "nis"    => _("&NIS Users"),
        # the type of user set
        "ldap"   => _("L&DAP Users"),
        # the type of user set
        "samba"  => _("Sam&ba Users"),
        # the type of user set
        "custom" => _("&Custom")
      }

      # values to Label (no shortcut sign)
      @userset_to_label = {
        # the type of user set
        "system" => _("System Users"),
        # the type of user set
        "local"  => _("Local Users"),
        # the type of user set
        "nis"    => _("NIS Users"),
        # the type of user set
        "ldap"   => _("LDAP Users"),
        # the type of user set
        "samba"  => _("Samba Users"),
        # the type of user set
        "custom" => _("Custom")
      }

      # values to MenuItem in Summary dialog
      @groupset_to_string = {
        # the type of group set
        "system" => _("&System Groups"),
        # the type of group set
        "local"  => _("&Local Groups"),
        # the type of group set
        "nis"    => _("&NIS Groups"),
        # the type of group set
        "ldap"   => _("L&DAP Groups"),
        # the type of group set
        "samba"  => _("Sam&ba Groups"),
        # the type of group set
        "custom" => _("&Custom")
      }

      @groupset_to_label = {
        # the type of group set
        "system" => _("System Groups"),
        # the type of group set
        "local"  => _("Local Groups"),
        # the type of group set
        "nis"    => _("NIS Groups"),
        # the type of group set
        "ldap"   => _("LDAP Groups"),
        # the type of group set
        "samba"  => _("Samba Groups"),
        # the type of group set
        "custom" => _("Custom")
      }

      # map with group names allowed for a default group
      @all_groupnames = {}

      # global values for authentication tab: ---------

      # list of installed clients
      @installed_clients = []

      @configurable_clients = ["nis", "sssd", "samba"]

      # save if no more Available calls should be done (bug #225484)
      @check_available = true

      @client_label = {
        # richtext label
        "nis"      => _("NIS"),
        # richtext label
        "sssd"     => _("SSSD"),
        # richtext label
        "samba"    => _("Samba")
      }

      # name of module to call
      @call_module = {
        "samba" => "samba-client",
        "sssd" => "auth-client"
      }


      @tabs_description = {
        "users"          => {
          # tab header
          "header"       => _("&Users"),
          "contents"     => HBox(
            HSpacing(0.5),
            VBox("filter_line", "tab_switch_users", "table"),
            HSpacing(0.5)
          ),
          "widget_names" => ["tab_switch_users", "filter_line", "table"]
        },
        "groups"         => {
          # tab header
          "header"       => _("&Groups"),
          "contents"     => HBox(
            HSpacing(0.5),
            VBox("filter_line", "tab_switch_groups", "table"),
            HSpacing(0.5)
          ),
          "widget_names" => ["tab_switch_groups", "filter_line", "table"]
        },
        "defaults"       => {
          # tab header
          "header"       => _("De&faults for New Users"),
          "contents"     => HBox(
            HSpacing(2),
            VBox(
              VStretch(),
              VSpacing(0.2),
              "defaults_global",
              "defaultgroup",
              "groups",
              "shell",
              HBox("home", VBox(Label(""), "browse_home")),
              HBox("skel", VBox(Label(""), "browse_skel")),
              "umask",
              "expire",
              "inactive",
              VSpacing(0.2),
              VStretch()
            ),
            HSpacing(2)
          ),
          "widget_names" => [
            "defaults_global",
            "defaultgroup",
            "groups",
            "shell",
            "home",
            "browse_home",
            "skel",
            "browse_skel",
            "umask",
            "expire",
            "inactive"
          ]
        },
        "authentication" => {
          # tab header
          "header"       => _("&Authentication Settings"),
          "contents"     => HBox(
            HSpacing(),
            VBox(VSpacing(0.5), "auth_global", VSpacing(0.5)),
            HSpacing()
          ),
          "widget_names" => ["auth_global"]
        }
      }


      @widgets = {
        # widgets for "users" and "groups" tabs ---------------------------------
        "tab_switch_users"  => {
          "widget" => :empty,
          "init"   => fun_ref(method(:InitTabUsersGroups), "void (string)"),
          "help"   => UsersDialogHelp()
        },
        "tab_switch_groups" => {
          "widget" => :empty,
          "init"   => fun_ref(method(:InitTabUsersGroups), "void (string)"),
          "help"   => GroupsDialogHelp()
        },
        "filter_line"       => {
          "widget"        => :custom,
          "custom_widget" => ReplacePoint(
            Id(:rpfilter),
            HBox(
              Left(Label(Id(:current_filter), "")),
              Right(
                MenuButton(
                  Id(:sets),
                  Opt(:key_F2, :disabled),
                  _("&Set Filter"),
                  []
                )
              )
            )
          ),
          "init"          => fun_ref(method(:InitFilterLine), "void (string)"),
          "handle"        => fun_ref(
            method(:HandleFilterLine),
            "symbol (string, map)"
          ),
          "handle_events" => [
            # these are for user/group types
            "local",
            "system",
            "ldap",
            "nis",
            "custom",
            :customize
          ],
          "no_help"       => true
        },
        "table"             => {
          "widget"        => :custom,
          "custom_widget" => VBox(
            ReplacePoint(Id(:rptable), Table(Id("table"), Header(""))),
            HBox(
              PushButton(Id(:new), Opt(:key_F3), Label.AddButton),
              PushButton(Id(:edit), Opt(:key_F4), Label.EditButton),
              PushButton(Id(:delete), Opt(:key_F5), Label.DeleteButton),
              HStretch(),
              ReplacePoint(
                Id(:rpexpert),
                # Menu Buton label
                MenuButton(Id(:expertlist), _("E&xpert Options"), [])
              )
            ),
            VSpacing(0.2)
          ),
          "init"          => fun_ref(method(:SummaryTableInit), "void (string)"),
          "handle"        => fun_ref(
            method(:HandleSummaryTable),
            "symbol (string, map)"
          ),
          "handle_events" => [
            "table",
            :new,
            :edit,
            :delete,
            :next,
            :enc,
            :autologinconf,
            :save,
            :ldapfilter,
            :ldapconf
          ],
          "no_help"       => true
        },
        # widgets for user defaults --------------------------------------------
        "defaults_global"   => {
          "widget" => :empty,
          "init"   => fun_ref(method(:InitDefaults), "void (string)"),
          "store"  => fun_ref(method(:StoreDefaults), "void (string, map)"),
          "help"   => DefaultsDialogHelp()
        },
        "defaultgroup"      => {
          "widget"  => :combobox,
          "opt"     => [:hstretch],
          # combobox label
          "label"   => _("D&efault Group"),
          "no_help" => true
        },
        "shell"             => {
          "widget"            => :combobox,
          "opt"               => [:hstretch, :editable],
          # combobox label
          "label"             => _("Default &Login Shell"),
          "no_help"           => true,
          "validate_type"     => :function,
          "validate_function" => fun_ref(
            method(:ValidateShell),
            "boolean (string, map)"
          )
        },
        "groups"            => {
          "widget"            => :textentry,
          # text entry
          "label"             => _("Se&condary Groups"),
          "no_help"           => true,
          "validate_type"     => :function,
          "validate_function" => fun_ref(
            method(:ValidateGroupList),
            "boolean (string, map)"
          )
        },
        "home"              => {
          "widget"            => :textentry,
          # text entry
          "label"             => _(
            "Path Prefix for &Home Directory"
          ),
          "no_help"           => true,
          "validate_type"     => :function,
          "validate_function" => fun_ref(
            method(:ValidateHomePrefix),
            "boolean (string, map)"
          )
        },
        "browse_home"       => {
          "widget"  => :push_button,
          # push button label
          "label"   => _("&Browse..."),
          "opt"     => [:key_F6],
          "handle"  => fun_ref(
            method(:HandleBrowseDirectory),
            "symbol (string, map)"
          ),
          "no_help" => true
        },
        "skel"              => {
          "widget"            => :textentry,
          # text entry
          "label"             => _("&Skeleton for Home Directory"),
          "no_help"           => true,
          "validate_type"     => :function,
          "validate_function" => fun_ref(
            method(:ValidateSkeleton),
            "boolean (string, map)"
          )
        },
        "browse_skel"       => {
          "widget"  => :push_button,
          # push button label
          "label"   => _("Bro&wse..."),
          "opt"     => [:key_F7],
          "handle"  => fun_ref(
            method(:HandleBrowseDirectory),
            "symbol (string, map)"
          ),
          "no_help" => true
        },
        "expire"            => {
          "widget"            => :textentry,
          # text entry
          "label"             => _("Default E&xpiration Date"),
          "no_help"           => true,
          "validate_type"     => :function,
          "validate_function" => fun_ref(
            method(:ValidateExpire),
            "boolean (string, map)"
          )
        },
        "umask"             => {
          "widget"      => :textentry,
          "valid_chars" => "01234567",
          # text entry
          "label"       => _("&Umask for Home Directory"),
          "no_help"     => true
        },
        "inactive"          => {
          "widget"  => :intfield,
          "opt"     => [:hstretch],
          # intfield
          "label"   => _(
            "Days &after Password Expiration Login Is Usable"
          ),
          "minimum" => -1,
          "no_help" => true
        },
        # widgets for authentication settings tab ------------------------------
        "auth_global"       => {
          "widget"        => :custom,
          "help"          => AuthentizationDialogHelp(),
          "init"          => fun_ref(method(:InitAuthData), "void (string)"),
          "store"         => fun_ref(
            method(:StoreAuthData),
            "void (string, map)"
          ),
          "handle"        => fun_ref(
            method(:HandleAuthData),
            "symbol (string, map)"
          ),
          "custom_widget" => VBox(
            RichText(Id("auth_summary"), ""),
            VSpacing(0.5),
            ReplacePoint(
              Id(:rpbutton),
              # menu button label
              MenuButton(Opt(:key_F4), _("&Configure..."), [])
            )
          ),
          "handle_events" => ["sssd", "nis", "samba"]
        }
      }
    end

    # Popup for choosing the password encryption method.
    #
    def EncryptionPopup
      method = Users.EncryptionMethod

      # Help text for password expert dialog 1/5
      help_text = _(
        "<p>\n" +
          "<b>This is for experts only.</b>\n" +
          "</p>"
      )

      # Help text for password expert dialog 2/5
      help_text = Ops.add(
        help_text,
        _(
          "<p>\n" +
            "Choose a password encryption method for local and system users.\n" +
            "<b>DES</b>, the Linux default method, works in all network environments, but it\n" +
            "restricts passwords to eight characters or less.\n" +
            "</p>\n"
        )
      )

      # Help text for password expert dialog 3/5
      help_text = Ops.add(
        help_text,
        _(
          "<p>\n" +
            "<b>MD5</b> allows longer passwords, so provides more security, but some\n" +
            "network protocols do not support this and you may have problems with NIS.\n" +
            "</p>"
        )
      )

      # Help text for password expert dialog 4/5
      help_text = Ops.add(
        help_text,
        _(
          "<p><b>SHA-512</b> is the current standard hash method. Using other algorithms is not recommended unless needed for compatibility purposes.</p>"
        )
      )

      UI.OpenDialog(
        VBox(
          # Label
          Heading(_("Password Encryption")),
          VSpacing(0.7),
          HBox(
            HSpacing(2),
            # frame label
            RadioButtonGroup(
              Id(:methods),
              Frame(
                _("Encryption Type"),
                HBox(
                  HSpacing(),
                  VBox(
                    VSpacing(0.5),
                    # Radio buttons for password encryption: DES-crypt
                    Left(RadioButton(Id("des"), _("&DES"), method == "des")),
                    # Radio buttons for password encryption: MD5-crypt
                    Left(RadioButton(Id("md5"), _("&MD5"), method == "md5")),
                    # Radio buttons for password encryption: sha256 crypt
                    Left(
                      RadioButton(
                        Id("sha256"),
                        _("SHA-&256"),
                        method == "sha256"
                      )
                    ),
                    # Radio buttons for password encryption: sha512 crypt
                    Left(
                      RadioButton(
                        Id("sha512"),
                        _("SHA-&512"),
                        method == "sha512"
                      )
                    ),
                    VSpacing(0.5)
                  )
                )
              )
            ),
            HSpacing(2)
          ),
          VSpacing(0.5),
          HBox(
            HStretch(),
            HWeight(
              1,
              PushButton(Id(:ok), Opt(:default, :key_F10), Label.OKButton)
            ),
            HStretch(),
            HWeight(
              1,
              PushButton(Id(:cancel), Opt(:key_F9), Label.CancelButton)
            ),
            HStretch(),
            HWeight(1, PushButton(Id(:help), Opt(:key_F2), Label.HelpButton)),
            HStretch()
          )
        )
      )

      button = nil
      begin
        button = UI.UserInput

        if button == :help
          Wizard.ShowHelp(help_text)
        elsif button == :ok
          method = Convert.to_string(
            UI.QueryWidget(Id(:methods), :CurrentButton)
          )
          Builtins.y2milestone("Changing encryption method to %1", method)
        end
      end while button != :ok && button != :cancel

      UI.CloseDialog
      method
    end

    # NIS server enabled together with non-DES encryption of passwords
    # In these popup, ask user what to do.
    def AskForNISServerEncryptionPopup(encr)
      ret = :ok

      # help text 1/3
      text = _(
        "<p>\nYou have changed the default encryption for user passwords.</p>"
      ) +
        # help text 2/3
        _(
          "<p>It seems that you are running a NIS server. In some network environments,\n" +
            "you might be unable to log in to a NIS client when a user password is\n" +
            "encrypted with a method other than DES.\n" +
            "</p>\n"
        ) +
        # help text 3/3
        _("<p>Really use the selected method?</p>")

      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          VSpacing(14),
          VBox(
            HSpacing(50),
            RichText(Id(:rt), text),
            CheckBox(Id(:ch), Opt(:notify), Message.DoNotShowMessageAgain),
            HBox(
              PushButton(Id(:ok), Opt(:key_F10), Label.YesButton),
              PushButton(Id(:no), Opt(:key_F9), Label.NoButton)
            )
          )
        )
      )
      begin
        ret = Convert.to_symbol(UI.UserInput)
      end while !Builtins.contains([:cancel, :ok, :no], ret)

      if ret != :cancel
        Users.SetAskNISServerNotDES(
          Convert.to_boolean(UI.QueryWidget(Id(:ch), :Value))
        )
      end
      UI.CloseDialog
      ret
    end

    # Popup for configuration user/group filter for making the LDAP search
    # @return modified?
    def LDAPSearchFilterPopup
      default_user_f = UsersLDAP.GetDefaultUserFilter
      default_group_f = UsersLDAP.GetDefaultGroupFilter

      user_f = UsersLDAP.GetCurrentUserFilter
      group_f = UsersLDAP.GetCurrentGroupFilter

      user_f = default_user_f if user_f == ""
      group_f = default_group_f if group_f == ""

      ret = false

      # attributes are listed here, because during filter editing, the connection
      # to LDAP server doesn't have to be run yet
      user_attributes = [
        "objectClass",
        "loginShell",
        "gecos",
        "description",
        "cn",
        "uid",
        "uidNumber",
        "gidNumber",
        "homeDirectory",
        "shadowLastChange",
        "shadowMin",
        "shadowMax",
        "shadowWarning",
        "shadowInactive",
        "shadowExpire",
        "shadowFlag",
        "audio",
        "businessCategory",
        "carLicense",
        "departmentNumber",
        "displayName",
        "employeeNumber",
        "employeeType",
        "givenName",
        "homePhone",
        "homePostalAddress",
        "initials",
        "jpegPhoto",
        "labeledUri",
        "mail",
        "manager",
        "mobile",
        "o",
        "pager",
        "photo",
        "roomNumber",
        "secretary",
        "userCertificate",
        "x500uniqueIdentifier",
        "preferredLanguage",
        "userSMIMECertificate",
        "userPKCS12",
        "title",
        "x121Address",
        "registeredAddress",
        "destinationIndicator",
        "preferredDeliveryMethod",
        "telexNumber",
        "teletexTerminalIdentifier",
        "telephoneNumber",
        "internationalISDNNumber",
        "facsimileTelephoneNumber",
        "street",
        "postOfficeBox",
        "postalCode",
        "postalAddress",
        "physicalDeliveryOfficeName",
        "ou",
        "st",
        "l",
        "seeAlso",
        "sn"
      ]
      group_attributes = [
        "objectClass",
        "memberUid",
        "description",
        "gidNumber",
        "businessCategory",
        "seeAlso",
        "owner",
        "ou",
        "o",
        "member",
        "cn"
      ]

      connectives = [
        # combo box item
        Item(Id("and"), _("AND")),
        # combo box item
        Item(Id("or"), _("OR"))
      ]
      equality = ["=", "~=", "<=", ">="]
      curr_shown = UsersCache.GetCurrentSummary == "users" ? :users : :groups

      help_text =
        # helptext 1/4 - caption
        _("<p><b>LDAP Search Filter Changes</b></p>") +
          # helptext 2/4
          _(
            "<p>Here, extend the search filters for users and groups beyond the default search filters.</p>"
          ) +
          # helptext 3/4
          _(
            "<p>With <b>Default</b>, load the default filter from the user and group\n" +
              "configuration modules saved on the LDAP server (values of 'suseSearchFilter' attributes).\n" +
              "If you are not connected yet, you are prompted for the password.</p>\n"
          ) +
          # helptext 4/4 (do not translate the value (written as <tt> font))
          _(
            "<p><b>Example:</b>\n" +
              "<br>With the user filter\n" +
              "<br>\n" +
              "<tt>(&(objectClass=posixAccount)(uid=u*))</tt>\n" +
              "<br>\n" +
              "only obtain users with a username beginning with 'u'.</p>\n"
          )


      contents = HBox(
        HSpacing(1.5),
        VBox(
          HSpacing(70), # max 65 with help on left side...
          VSpacing(0.5),
          Left(
            RadioButtonGroup(
              VBox(
                Left(
                  RadioButton(
                    Id(:users),
                    Opt(:notify),
                    # radiobutton label
                    _("Search Filter for &Users"),
                    curr_shown == :users
                  )
                ),
                Left(
                  RadioButton(
                    Id(:groups),
                    Opt(:notify),
                    # radiobutton label
                    _("Search Filter for &Groups"),
                    curr_shown == :groups
                  )
                )
              )
            )
          ),
          TextEntry(Id(:currf), "", curr_shown == :users ? user_f : group_f),
          VSpacing(0.5),
          # frame label
          Frame(
            _("New Condition for Current Filter"),
            HBox(
              HSpacing(0.5),
              VBox(
                Left(ComboBox(Id(:andor), "", connectives)),
                HBox(
                  ReplacePoint(
                    Id(:rpa),
                    # combobox label
                    ComboBox(
                      Id(:atrs),
                      Opt(:editable),
                      _("&Attribute"),
                      curr_shown == :users ? user_attributes : group_attributes
                    )
                  ),
                  HSpacing(),
                  VBox(Label(""), ComboBox(Id(:eq), "", equality)),
                  HSpacing(),
                  # textentry label
                  TextEntry(Id(:val), _("&Value"), "")
                ),
                # pushbuttton label
                Right(PushButton(Id(:addu), _("A&dd to Filter")))
              ),
              HSpacing(0.5)
            )
          ),
          VSpacing(),
          HBox(
            PushButton(Id(:ok), Opt(:default, :key_F10), Label.OKButton),
            PushButton(Id(:cancel), Opt(:key_F9), Label.CancelButton),
            PushButton(Id(:help), Opt(:key_F2), Label.HelpButton),
            # Pushbutton label
            PushButton(Id(:read), Opt(:key_F3), _("De&fault"))
          ),
          VSpacing(0.5)
        ),
        HSpacing(1.5)
      )

      UI.OpenDialog(Opt(:decorated), contents)
      button = :notnext
      begin
        button = Convert.to_symbol(UI.UserInput)

        if button == :help
          Wizard.ShowHelp(help_text)
          next
        end
        if button == :read
          if Ldap.bind_pass == nil
            Ldap.SetBindPassword(Ldap.GetLDAPPassword(true))
          end
          if Ldap.bind_pass != nil && UsersLDAP.ReadFilters == ""
            UI.ChangeWidget(
              Id(:currf),
              :Value,
              curr_shown == :users ?
                UsersLDAP.GetDefaultUserFilter :
                UsersLDAP.GetDefaultGroupFilter
            )
          end
          next
        end
        curr_f = Convert.to_string(UI.QueryWidget(Id(:currf), :Value))
        if button == :addu
          if Convert.to_string(UI.QueryWidget(Id(:val), :Value)) == ""
            # error popup
            Popup.Error(_("Enter the value for the attribute."))
            UI.SetFocus(Id(:val))
            next
          end
          new_value = Builtins.sformat(
            "%1%2%3",
            Convert.to_string(UI.QueryWidget(Id(:atrs), :Value)),
            Convert.to_string(UI.QueryWidget(Id(:eq), :Value)),
            Convert.to_string(UI.QueryWidget(Id(:val), :Value))
          )

          conn = Convert.to_string(UI.QueryWidget(Id(:andor), :Value))
          UI.ChangeWidget(
            Id(:currf),
            :Value,
            UsersLDAP.AddToFilter(curr_f, new_value, conn)
          )
        end
        if button == :ok || button == :users || button == :groups
          if (button == :groups || button == :ok && curr_shown == :users) &&
              user_f != curr_f
            curr_user_f = curr_f
            if curr_user_f == ""
              # error popup
              Popup.Error(_("Enter the value of the user filter."))
              UI.SetFocus(Id(:currf))
              button = :notnext
              next
            end
            if !Builtins.issubstring(
                Builtins.tolower(curr_user_f),
                Builtins.tolower(default_user_f)
              ) &&
                # yes/no popup question
                !Popup.YesNo(
                  _(
                    "The new user filter does not contain the default user filter.\nReally use it?\n"
                  )
                )
              UI.SetFocus(Id(:currf))
              button = :notnext
              next
            end
            user_f = curr_user_f
          end
          if (button == :users || button == :ok && curr_shown == :groups) &&
              group_f != curr_f
            curr_group_f = curr_f
            if curr_group_f == ""
              # error popup
              Popup.Error(_("Enter the value of the group filter."))
              UI.SetFocus(Id(:currf))
              button = :notnext
              next
            end
            if !Builtins.issubstring(
                Builtins.tolower(curr_group_f),
                Builtins.tolower(default_group_f)
              )
              # yes/no popup question
              if !Popup.YesNo(
                  _(
                    "The new group filter does not contain the default group filter.\nReally use it?\n"
                  )
                )
                UI.SetFocus(Id(:currf))
                button = :notnext
                next
              end
            end
            group_f = curr_group_f
          end
          if button == :ok
            # checks are OK, let's update the values now
            if user_f != UsersLDAP.GetCurrentUserFilter
              UsersLDAP.SetCurrentUserFilter(user_f)
              ret = true
            end
            if group_f != UsersLDAP.GetCurrentGroupFilter
              UsersLDAP.SetCurrentGroupFilter(group_f)
              ret = true
            end
          else
            UI.ChangeWidget(Id(curr_shown), :Value, false)
            curr_shown = curr_shown == :users ? :groups : :users
            UI.ChangeWidget(Id(curr_shown), :Value, true)
            UI.ChangeWidget(
              Id(:currf),
              :Value,
              curr_shown == :users ? user_f : group_f
            )
            UI.ReplaceWidget(
              Id(:rpa),
              # combobox label
              ComboBox(
                Id(:atrs),
                Opt(:editable),
                _("&Attribute"),
                curr_shown == :users ? user_attributes : group_attributes
              )
            )
          end
        end
      end while button != :ok && button != :cancel

      UI.CloseDialog
      ret
    end

    # Popup for Login settings (Auotolgin feature, login without passwords)
    # @return modified?
    #
    def AutologinPopup
      help_text =
        # helptext 0/3 - caption
        _("<p><b>Login Settings</b></p>") +
          # helptext 1/3 - general info
          _(
            "<p>\n" +
              "The features described below are only available if you are using KDM or GDM as the login manager.\n" +
              "</p>\n"
          ) +
          # helptext 2/3
          _(
            "<p><b>Auto Login</b><br>\nBy setting <b>Auto Login</b>, skip the login procedure. The user chosen from the list is logged in automatically.</p>\n"
          ) +
          # helptext 3/3
          _(
            "<p><b>Passwordless Logins</b><br>\n" +
              "If this option is checked, all users are allowed to log in without entering\n" +
              "passwords. Otherwise, you are asked for the password even if you set a user to log in automatically.</p>\n"
          )


      ret = false

      user = Autologin.user
      pw_less = Autologin.pw_less
      auto_used = user != ""

      # TODO check if nis/ldap users were read?

      usernames = UsersCache.GetUsernames("local")

      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          HSpacing(1.5),
          VBox(
            HSpacing(40),
            VSpacing(0.5),
            # dialog label
            Heading(_("Display Manager Login Settings")),
            HBox(
              HSpacing(0.5),
              VBox(
                VSpacing(0.5),
                Left(
                  CheckBox(
                    Id(:auto),
                    Opt(:notify),
                    # checkbox label
                    _("&Auto Login"),
                    auto_used
                  )
                ),
                VSpacing(0.2),
                HBox(
                  HSpacing(4), # move text under the checkbox
                  Left(
                    ComboBox(
                      Id(:autouser),
                      # textentry label
                      _("&User to Log In"),
                      usernames
                    )
                  )
                ),
                VSpacing(0.5),
                Left(
                  CheckBox(
                    Id(:pw_less),
                    # checkbox label
                    _("Password&less Logins"),
                    pw_less
                  )
                ),
                VSpacing(0.5)
              ),
              HSpacing(0.5)
            ),
            VSpacing(0.5),
            HBox(
              PushButton(Id(:ok), Opt(:default, :key_F10), Label.OKButton),
              PushButton(Id(:cancel), Opt(:key_F9), Label.CancelButton),
              PushButton(Id(:help), Opt(:key_F2), Label.HelpButton)
            ),
            VSpacing(0.5)
          ),
          HSpacing(1.5)
        )
      )

      UI.ChangeWidget(Id(:autouser), :Value, user) if user != ""
      UI.ChangeWidget(Id(:autouser), :Enabled, auto_used)

      button = nil
      begin
        button = Convert.to_symbol(UI.UserInput)

        Wizard.ShowHelp(help_text) if button == :help
        if button == :auto
          auto_used = Convert.to_boolean(UI.QueryWidget(Id(:auto), :Value))
          UI.ChangeWidget(Id(:autouser), :Enabled, auto_used)
        end
      end while !Builtins.contains([:ok, :cancel, :abort], button)

      if button == :ok
        user = auto_used ?
          Convert.to_string(UI.QueryWidget(Id(:autouser), :Value)) :
          ""
        pw_less = Convert.to_boolean(UI.QueryWidget(Id(:pw_less), :Value))

        if user != Autologin.user || pw_less != Autologin.pw_less
          ret = true
          Autologin.used = auto_used
          Autologin.user = user
          Autologin.pw_less = pw_less
          Autologin.modified = true
        end
      end
      UI.CloseDialog
      ret
    end


    # Popup for deleting user
    # @return [Symbol] for sequencer
    def DeleteUserPopup
      delete = true
      delete_home = false

      type = UsersCache.GetUserType
      user = Users.GetCurrentUser
      username = Ops.get_string(user, "uid", "")
      home = Ops.get_string(
        user,
        ["org_user", "homeDirectory"],
        Ops.get_string(
          user,
          "org_homeDirectory",
          Ops.get_string(user, "homeDirectory", "")
        )
      )
      uid = -1
      uid_a = Ops.get_string(
        user,
        ["org_user", "uidNumber"],
        Ops.get_string(
          user,
          "org_uidNumber",
          Ops.get_string(user, "uidNumber", "-1")
        )
      )
      if Ops.is_string?(uid_a)
        uid = Builtins.tointeger(uid_a)
      else
        uid = Convert.to_integer(uid_a)
      end

      if type == "nis"
        # error popup
        Report.Message(
          Builtins.sformat(
            _("Cannot delete the user %1. It must be done on the NIS server."),
            username
          )
        )
        return nil
      end

      if UserLogged(username) &&
        # Continue/Cancel popup
        !Popup.ContinueCancel(_("The user seems to be currently logged in.
Continue anyway?"))
        delete = false
        return nil
      end

      no_home = false
      # check if dir exists with this owner
      stat = Convert.to_map(SCR.Read(path(".target.stat"), home))
      crypted_img = UsersRoutines.CryptedImagePath(username)
      if crypted_img != "" # check crypted dir image
        stat = Convert.to_map(SCR.Read(path(".target.stat"), crypted_img))
      end
      if type == "ldap" && !Ldap.file_server ||
          Ops.get_integer(stat, "uid", -1) != uid
        no_home = true
      end

      # if the user want to delete a system user
      if type == "system"
        # yes-no popup headline
        if !Popup.YesNoHeadline(
            _("Selected User Is System User"),
            # yes-no popup contents
            _("Really delete this system user?")
          )
          delete = false
        end
      else
        if home != "" && !no_home
          contents = HBox(
            HSpacing(3),
            VBox(
              VSpacing(1),
              Left(
                # question popup. %1 is username
                Heading(Builtins.sformat(_("Delete the user %1?"), username))
              ),
              VSpacing(0.5),
              Left(
                CheckBox(
                  Id(:delete_home),
                  # checkbox label
                  Builtins.sformat(_("Delete &Home Directory\n%1\n"), home)
                )
              ),
              VSpacing(1),
              HBox(
                Bottom(PushButton(Id(:ok), Opt(:key_F10), Label.YesButton)),
                Bottom(PushButton(Id(:cancel), Opt(:key_F9), Label.NoButton))
              )
            ),
            HSpacing(3)
          )

          UI.OpenDialog(Opt(:decorated), contents)
          ret = UI.UserInput
          delete = false if ret != :ok
          delete_home = Convert.to_boolean(
            UI.QueryWidget(Id(:delete_home), :Value)
          )

          UI.CloseDialog
        else
          # yes-no popup. %1 is username
          if !Popup.YesNo(
              Builtins.sformat(_("\nReally delete the user %1?\n"), username)
            )
            delete = false
          end
        end
      end
      if delete
        Users.DeleteUser(delete_home)
        return :delete
      end
      nil
    end

    # Popup for deleting group
    # @return [Symbol] for sequencer
    def DeleteGroupPopup
      delete = true
      type = UsersCache.GetGroupType
      group = Users.GetCurrentGroup
      member_attribute = UsersLDAP.GetMemberAttribute

      # if no user is in this group
      if Ops.get_map(group, "userlist", {}) == {} &&
          Ops.get_map(group, "more_users", {}) == {} &&
          Ops.get_map(group, member_attribute, {}) == {}
        #if the group is a system group ask the user ..
        if type == "system"
          # yes-no popup headline
          if !Popup.YesNoHeadline(
              _("System Group"),
              #/ yes-no popup contents
              _("Really delete this system group?")
            )
            return nil
          end
        else
          # yes-no popup, %1 si group name
          if !Popup.YesNo(
              Builtins.sformat(
                _("\nReally delete the group %1?\n"),
                Ops.get_string(group, "cn", "")
              )
            )
            return nil
          end
        end
      else
        # warning popup
        Popup.Warning(
          _(
            "You cannot delete this group because\n" +
              "there are users in the group.\n" +
              "Remove these users from the group first.\n"
          )
        )
        return nil
      end

      Users.DeleteGroup
      :delete
    end

    # Dialog for definition of customized view
    # @param [String] what "users" or "groups"
    # @return true if customs were odified
    def CustomizePopup(what)
      view = VBox()
      label = ""
      sets = []
      custom_sets = []
      set_to_string = {}

      if what == "users"
        sets = Builtins.filter(Users.GetAvailableUserSets) do |set|
          set != "custom"
        end
        custom_sets = Users.GetUserCustomSets
        set_to_string = deep_copy(@userset_to_string)
        # Frame label
        label = _("User List View")
      else
        sets = Builtins.filter(Users.GetAvailableGroupSets) do |set|
          set != "custom"
        end
        custom_sets = Users.GetGroupCustomSets
        set_to_string = deep_copy(@groupset_to_string)
        # Frame label
        label = _("Group List View")
      end

      Builtins.foreach(sets) do |set|
        view = Builtins.add(view, VSpacing(0.5))
        if Builtins.contains(custom_sets, set)
          view = Builtins.add(
            view,
            Left(
              CheckBox(Id(set), Ops.get_string(set_to_string, set, ""), true)
            )
          )
        else
          view = Builtins.add(
            view,
            Left(
              CheckBox(Id(set), Ops.get_string(set_to_string, set, ""), false)
            )
          )
        end
      end
      view = Builtins.add(view, VSpacing(0.5))

      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          HSpacing(1.5),
          VBox(
            HSpacing(40),
            VSpacing(0.5),
            Frame(label, view),
            VSpacing(0.5),
            HBox(
              PushButton(Id(:ok), Opt(:default, :key_F10), Label.OKButton),
              PushButton(Id(:cancel), Opt(:key_F9), Label.CancelButton)
            ),
            VSpacing(0.5)
          ),
          HSpacing(1.5)
        )
      )
      ret = UI.UserInput
      modified = false
      new_customs = []
      Builtins.foreach(sets) do |set|
        if Convert.to_boolean(UI.QueryWidget(Id(set), :Value))
          new_customs = Builtins.add(new_customs, set)
          modified = true if !Builtins.contains(custom_sets, set)
        else
          modified = true if Builtins.contains(custom_sets, set)
        end
      end if ret == :ok
      UI.CloseDialog
      if modified
        if Builtins.contains(new_customs, "ldap") && Ldap.bind_pass == nil
          Ldap.SetBindPassword(Ldap.GetLDAPPassword(true))
          if Ldap.bind_pass == nil || UsersLDAP.ReadSettings != ""
            new_customs = Builtins.filter(new_customs) { |set| set != "ldap" }
          end
        end
        modified = Users.ChangeCustoms(what, new_customs)
      end
      modified
    end

    # When there are more users/groups shown, choose which type should be created
    # after `add click
    def ChooseTypePopup(sets, what)
      sets = deep_copy(sets)
      set_to_string = {
        # type of user/group
        # (item of list with the headline 'Choose the type of user to add')
        "local"  => _(
          "Local"
        ),
        # type of user/group
        # (item of list with the headline 'Choose the type of user to add')
        "ldap"   => _(
          "LDAP"
        ),
        # type of user/group
        # (item of list with the headline 'Choose the type of user to add')
        "system" => _(
          "System"
        )
      }

      sets = Builtins.filter(sets) { |set| set != "nis" }
      ret = Ops.get(sets, 0, "local")
      label = what == "user" ?
        # label
        _("User Type") :
        # label
        _("Group Type")

      return ret if Ops.less_than(Builtins.size(sets), 2)

      rbs = VBox()
      Builtins.foreach(sets) do |set|
        rbs = Builtins.add(
          rbs,
          Left(
            RadioButton(
              Id(set),
              Ops.get_string(set_to_string, set, set),
              set == ret
            )
          )
        )
      end

      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          HSpacing(1.5),
          VBox(
            HSpacing(40),
            VSpacing(0.5),
            Left(Label(label)),
            VSpacing(0.5),
            Left(RadioButtonGroup(rbs)),
            VSpacing(0.5),
            HBox(
              PushButton(Id(:ok), Opt(:default, :key_F10), Label.OKButton),
              PushButton(Id(:cancel), Opt(:key_F9), Label.CancelButton)
            ),
            VSpacing(0.5)
          ),
          HSpacing(1.5)
        )
      )

      r = UI.UserInput

      Builtins.foreach(sets) do |set|
        ret = set if Convert.to_boolean(UI.QueryWidget(Id(set), :Value))
      end

      UI.CloseDialog

      return "" if r == :cancel

      ret
    end


    #================================================================

    def GetSetsItems(set)
      items = []
      if set == "users"
        Builtins.foreach(Users.GetAvailableUserSets) do |set2|
          items = Builtins.add(
            items,
            Item(Id(set2), Ops.get_string(@userset_to_string, set2, ""))
          )
        end
        # menubutton item
        items = Builtins.add(
          items,
          Item(Id(:customize), _("Customi&ze Filter..."))
        )
      else
        Builtins.foreach(Users.GetAvailableGroupSets) do |set2|
          items = Builtins.add(
            items,
            Item(Id(set2), Ops.get_string(@groupset_to_string, set2, ""))
          )
        end
        # menubutton item
        items = Builtins.add(
          items,
          Item(Id(:customize), _("Customi&ze Filter..."))
        )
      end
      deep_copy(items)
    end

    # return the list of menu items of "Expert Options" menubutton
    def GetExpertList
      expert_list = []
      if Autologin.available
        expert_list = Builtins.add(
          expert_list,
          # menubutton label
          Item(Id(:autologinconf), _("&Login Settings"))
        )
      end
      if !Mode.config
        expert_list = Builtins.prepend(
          expert_list,
          # menubutton label
          Item(Id(:enc), _("Password &Encryption"))
        )
        if !Stage.cont
          expert_list = Builtins.add(
            expert_list,
            # menubutton label
            Item(Id(:save), _("&Write Changes Now"))
          )
        end
      end
      deep_copy(expert_list)
    end

    # return the list of menu items for LDAP expert options
    def GetLDAPExpertList
      expert_list = []
      if !Mode.config && Users.LDAPAvailable && !Users.LDAPModified
        expert_list = Builtins.add(
          expert_list,
          # menubutton label
          Item(Id(:ldapfilter), _("LDAP &Search Filter"))
        )
        expert_list = Builtins.add(
          expert_list,
          # menubutton label
          Item(Id(:ldapconf), _("L&DAP User and Group Configuration"))
        )
      end
      deep_copy(expert_list)
    end

    #================================================================
    #----------------- some help texts ------------------------------

    # First part of the help text.
    # @return [String] help text
    def help_main_start
      # help text 1/1
      _(
        "<p>\n" +
          "Linux is a multiuser system. Several different users can be logged in to the\n" +
          "system at the same time.  To avoid confusion, each user must have\n" +
          "a unique identity. Additionally, every user belongs to at least one group.\n" +
          "</p>\n"
      )
    end


    # Last part of the help text.
    # @return [String] help text
    def help_main_end
      button = Stage.cont ? Label.NextButton : Label.FinishButton

      # help text 1/3
      Ops.add(
        _(
          "<p>\n" +
            "Users and groups are arranged in various sets. Change the set currently shown in the table with <b>Set Filter</b>.\n" +
            "Customize your view with <b>Customize Filter</b>.</p>\n"
        ) +
          # help text 2/3
          _(
            "<p>\n" +
              "Click <b>Expert Options</b> to edit various expert settings, such as\n" +
              "password encryption type, user authentication method, default values for new\n" +
              "users, or login settings. With <b>Write Changes Now</b>, save\n" +
              "all changes made so far without exiting the configuration module.</p>\n"
          ),
        # help text 3/3, %1 is translated button label
        Builtins.sformat(
          _(
            "<p>\n" +
              "To save the modified user and group settings to your system, press\n" +
              "<b>%1</b>.\n" +
              "</p>\n"
          ),
          String.RemoveShortcut(button)
        )
      )
    end

    # Help for UsersDialog.
    # @return [String] help text
    def UsersDialogHelp
      # help text 1/4
      Ops.add(
        Ops.add(
          Ops.add(
            Ops.add(
              Ops.add(
                help_main_start,
                _(
                  "\n" +
                    "<p>\n" +
                    "Use this dialog to get information about existing users and add or modify\n" +
                    "users.  \n" +
                    "</p>\n"
                )
              ),
              # help text 2/4
              _(
                "<p>\n" +
                  "To shift to the group dialog, select <b>Groups</b>.\n" +
                  "</p>\n"
              )
            ),
            # help text 3/4
            _(
              "\n" +
                "<p>\n" +
                "To create a new user, click <b>Add</b>.\n" +
                "</p>\n"
            )
          ),
          # help text 4/4
          _(
            "<p>\n" +
              "To edit or delete an existing user, select one user from the list and\n" +
              "click <b>Edit</b> or <b>Delete</b>.\n" +
              "</p>\n"
          )
        ),
        help_main_end
      )
    end

    # Help for usersGroups.
    # @return [String] help text
    def GroupsDialogHelp
      Ops.add(
        Ops.add(
          Ops.add(
            Ops.add(
              Ops.add(
                help_main_start,
                # help text 1/4
                _(
                  "\n" +
                    "<p>\n" +
                    "Use this dialog to get information about existing groups and add or modify groups.\n" +
                    "</p>\n"
                )
              ),
              # help text 2/4
              _(
                "<p>\n" +
                  "To shift to the user dialog, select <b>Users</b>.\n" +
                  "</p>\n"
              )
            ),
            # help text 3/4
            _(
              "\n" +
                "<p>\n" +
                "To create a new group, click <b>Add</b>.\n" +
                "</p>\n"
            )
          ),
          # help text 4/4
          _(
            "<p>\n" +
              "To edit or delete an existing group, select one group from the list and\n" +
              "click <b>Edit</b> or <b>Delete</b>.\n" +
              "</p>\n"
          )
        ),
        help_main_end
      )
    end


    #================================================================

    # Validation function for the default value of account expiration
    def ValidateExpire(key, event)
      event = deep_copy(event)
      new_exp_date = Convert.to_string(UI.QueryWidget(Id(key), :Value))

      if new_exp_date != "" &&
          !Builtins.regexpmatch(
            new_exp_date,
            "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]"
          )
        # popup label - don't reorder the letters YYYY-MM-DD
        # The date must stay in this format
        Report.Error(_("The expiration date must be in the format YYYY-MM-DD."))
        UI.SetFocus(Id(key))
        return false
      end
      true
    end

    # Validation function for home directory skeleton directory
    def ValidateSkeleton(key, event)
      event = deep_copy(event)
      new_skel = Convert.to_string(UI.QueryWidget(Id(key), :Value))
      if SCR.Read(path(".target.dir"), new_skel) == nil
        # popup error label
        Report.Error(
          _(
            "The entered home directory skeleton is not a directory.\nTry again.\n"
          )
        )
        UI.SetFocus(Id(key))
        return false
      end
      true
    end

    # Validation function for the default home prefix
    def ValidateHomePrefix(key, event)
      event = deep_copy(event)
      new_home = Convert.to_string(UI.QueryWidget(Id(key), :Value))
      if SCR.Read(path(".target.dir"), new_home) == nil
        if SCR.Read(path(".target.size"), new_home) != -1
          # error message
          Report.Error(
            _(
              "The entered path prefix for home is not a directory.\nTry again.\n"
            )
          )
          UI.SetFocus(Id(key))
          return false
        else
          # yes/no popup
          if Popup.YesNo(
              _("The selected directory does not exist.\nCreate it now?\n")
            )
            if !Convert.to_boolean(SCR.Execute(path(".target.mkdir"), new_home))
              Report.Error(Message.UnableToCreateDirectory(new_home))
              UI.SetFocus(Id(key))
              return false
            end
          else
            UI.SetFocus(Id(key))
            return false
          end
        end
      end
      true
    end

    # Validation function for the value of the default list of groups
    def ValidateGroupList(key, event)
      event = deep_copy(event)
      groups = Users.GetDefaultGrouplist("local")
      grouplist = Builtins.mergestring(Builtins.maplist(groups) { |g, i| g }, ",")
      new_grouplist = Convert.to_string(UI.QueryWidget(Id(key), :Value))

      if new_grouplist != grouplist
        l_grouplist = []
        dont_exist = []
        Builtins.foreach(Builtins.splitstring(new_grouplist, ",")) do |g|
          # check for group existence
          if Ops.get(@all_groupnames, ["local", g], 0) == 0 &&
              Ops.get(@all_groupnames, ["system", g], 0) == 0
            dont_exist = Convert.convert(
              Builtins.union(dont_exist, [g]),
              :from => "list",
              :to   => "list <string>"
            )
          else
            # filter out the duplicates
            l_grouplist = Convert.convert(
              Builtins.union(l_grouplist, [g]),
              :from => "list",
              :to   => "list <string>"
            )
          end
        end
        if dont_exist != []
          # error message
          Report.Error(
            Builtins.sformat(
              _(
                "These groups do not exist in your system:\n" +
                  "%1\n" +
                  "Try again.\n"
              ),
              Builtins.mergestring(dont_exist, ",")
            )
          )

          UI.SetFocus(Id("groups"))
          return false
        end
        new_grouplist = Builtins.mergestring(l_grouplist, ",")
        UI.ChangeWidget(Id("groups"), :Value, new_grouplist)
      end
      true
    end

    # Validation function for the default login shell
    def ValidateShell(key, event)
      event = deep_copy(event)
      new_shell = Convert.to_string(UI.QueryWidget(Id(key), :Value))
      if !Builtins.contains(Users.AllShells, new_shell)
        # Yes-No popup
        return Popup.YesNo(
          _(
            "If you select a nonexistent shell, the user\nmay be unable to log in. Continue?\n"
          )
        )
      end
      true
    end

    # Initialize all the values in the dialog with new user defaults
    def InitDefaults(key)
      defaults = Users.GetLoginDefaults
      items = []
      @all_groupnames = UsersCache.GetAllGroupnames
      defaultgroup = Users.GetDefaultGroupname("local")

      Builtins.foreach(@all_groupnames) do |grouptype, groupmap|
        # only local sets
        next if !Builtins.contains(["local", "system"], grouptype)
        Builtins.foreach(groupmap) do |group, val|
          if group == defaultgroup
            items = Builtins.add(items, Item(Id(group), group, true))
          else
            items = Builtins.add(items, Item(Id(group), group))
          end
        end
      end
      UI.ChangeWidget(Id("defaultgroup"), :Items, items)
      UI.ChangeWidget(Id("shell"), :Items, Users.AllShells)
      UI.ChangeWidget(Id("shell"), :Value, Users.GetDefaultShell("local"))

      groups = Users.GetDefaultGrouplist("local")
      grouplist = Builtins.mergestring(Builtins.maplist(groups) { |g, i| g }, ",")
      UI.ChangeWidget(Id("groups"), :Value, grouplist)
      UI.ChangeWidget(
        Id("home"),
        :Value,
        Ops.get_string(defaults, "home", "/home")
      )
      UI.ChangeWidget(
        Id("skel"),
        :Value,
        Ops.get_string(defaults, "skel", "/etc/skel")
      )

      UI.ChangeWidget(
        Id("inactive"),
        :Value,
        Builtins.tointeger(Ops.get_string(defaults, "inactive", "0"))
      )

      expire = Ops.get_string(defaults, "expire", "")
      exp_date = ""
      if expire != "0" && expire != ""
        # 'expire' is expected to be number of days since 1970-01-01
        out = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            Ops.add(
              Builtins.sformat(
                "date --date='1970-01-01 00:00:01 %1 days' ",
                expire
              ),
              "+\"%Y-%m-%d\""
            )
          )
        )
        exp_date = Builtins.deletechars(Ops.get_string(out, "stdout", ""), "\n")
      end
      UI.ChangeWidget(Id("expire"), :Value, exp_date)
      UI.ChangeWidget(
        Id("umask"),
        :Value,
        Ops.get_string(defaults, "umask", "")
      )
      UI.ChangeWidget(Id("umask"), :InputMaxLength, 3)

      nil
    end

    # Store all the values from the dialog with new user defaults
    # (when leaving the dialog)
    def StoreDefaults(key, event)
      event = deep_copy(event)
      defaults = Users.GetLoginDefaults
      new_defaults = {}
      Builtins.foreach(["home", "shell", "skel", "inactive", "umask"]) do |key2|
        val = UI.QueryWidget(Id(key2), :Value)
        val = Builtins.sformat("%1", val) if Ops.is_integer?(val)
        if Ops.get(defaults, key2) != val
          Ops.set(new_defaults, key2, Convert.to_string(val))
        end
      end
      new_grouplist = Convert.to_string(UI.QueryWidget(Id("groups"), :Value))
      if Builtins.sort(
          Builtins.splitstring(Ops.get_string(defaults, "groups", ""), ",")
        ) !=
          Builtins.sort(Builtins.splitstring(new_grouplist, ","))
        Ops.set(new_defaults, "groups", new_grouplist)
      end

      new_exp_date = Convert.to_string(UI.QueryWidget(Id("expire"), :Value))
      new_expire = Ops.get_string(defaults, "expire", "")
      if new_exp_date == ""
        new_expire = ""
      else
        out = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            Ops.add(
              Builtins.sformat("date --date='%1 UTC' ", new_exp_date),
              "+%s"
            )
          )
        )
        seconds_s = Builtins.deletechars(
          Ops.get_string(out, "stdout", "0"),
          "\n"
        )
        if seconds_s != ""
          days = Ops.divide(Builtins.tointeger(seconds_s), 60 * 60 * 24)
          new_expire = Builtins.sformat("%1", days)
        end
      end
      if new_expire != Ops.get_string(defaults, "expire", "")
        Ops.set(new_defaults, "expire", new_expire)
      end

      new_defgroup = Convert.to_string(
        UI.QueryWidget(Id("defaultgroup"), :Value)
      )
      if Users.GetDefaultGroupname("local") != new_defgroup
        g = Users.GetGroupByName(new_defgroup, "")
        Ops.set(
          new_defaults,
          "group",
          Builtins.sformat(
            "%1",
            GetInt(Ops.get(g, "gidNumber"), Users.GetDefaultGID("local"))
          )
        )
      end
      Users.SetLoginDefaults(new_defaults, new_defgroup) if new_defaults != {}

      nil
    end

    # universal handler for directory browsing
    def HandleBrowseDirectory(key, event)
      event = deep_copy(event)
      return nil if Ops.get(event, "ID") != key
      val = Builtins.substring(key, 7)
      current = Convert.to_string(UI.QueryWidget(Id(val), :Value))
      current = "" if current == nil
      # directory location popup label
      dir = UI.AskForExistingDirectory(current, _("Path to Directory"))
      UI.ChangeWidget(Id(val), :Value, dir) if dir != nil
      nil
    end


    # Handle the switch between tabs (load set of items for users or groups)
    def InitTabUsersGroups(widget_id)
      current_summary = UsersCache.GetCurrentSummary
      if current_summary == CWMTab.CurrentTab
        # tab shows already current set
        return
      else
        UsersCache.ChangeCurrentSummary
      end

      nil
    end

    # Initialize the contents of Summary Table widget
    def SummaryTableInit(widget_id)
      items = []
      current_summary = UsersCache.GetCurrentSummary
      if current_summary == "users"
        items = UsersCache.GetUserItems
        UI.ReplaceWidget(
          Id(:rptable),
          Table(
            Id("table"),
            Opt(:notify),
            Header(
              # table header
              _("Login"),
              # table header
              _("Name"),
              # table header
              _("UID"),
              # table header
              _("Groups")
            ),
            []
          )
        )
      else
        items = UsersCache.GetGroupItems
        UI.ReplaceWidget(
          Id(:rptable),
          Table(
            Id("table"),
            Opt(:notify),
            Header(
              # table header
              _("Group Name"),
              # table header
              _("Group ID"),
              # table header
              _("Group Members")
            ),
            []
          )
        )
      end
      UI.ChangeWidget(Id(widget_id), :Items, items)
      if Ops.greater_than(Builtins.size(items), 0)
        UI.SetFocus(Id(widget_id))
        focusline = UsersCache.GetCurrentFocus
        if focusline != nil
          UI.ChangeWidget(Id(widget_id), :CurrentItem, focusline)
        end
      end
      UI.ReplaceWidget(
        Id(:rpexpert),
        # Menu Buton label
        MenuButton(
          Id(:expertlist),
          _("E&xpert Options"),
          Builtins.union(GetExpertList(), GetLDAPExpertList())
        )
      )

      nil
    end

    # Handler for users/groups summary table
    def HandleSummaryTable(widget_id, event)
      event = deep_copy(event)
      ev_id = Ops.get(event, "ID")

      current_summary = UsersCache.GetCurrentSummary

      ev_id = :edit if ev_id == "table"
      if ev_id == :new
        error = ""
        if current_summary == "users"
          current_users = Users.GetCurrentUsers
          if Ops.greater_than(Builtins.size(current_users), 1)
            set = ChooseTypePopup(current_users, "user")
            return nil if set == ""
            current_users = Builtins.filter(current_users) { |u| u != set }
            current_users = Builtins.prepend(current_users, set)
            Users.SetCurrentUsers(current_users)
          end
          error = Users.AddUser({})
        else
          current_groups = Users.GetCurrentGroups
          if Ops.greater_than(Builtins.size(current_groups), 1)
            set = ChooseTypePopup(current_groups, "group")
            return nil if set == ""
            current_groups = Builtins.filter(current_groups) { |u| u != set }
            current_groups = Builtins.prepend(current_groups, set)
            Users.SetCurrentGroups(current_groups)
          end
          error = Users.AddGroup({})
        end
        if error != ""
          Popup.Error(error)
          return nil
        end
      end
      if ev_id == :edit || ev_id == :delete
        selected = Convert.to_string(UI.QueryWidget(Id("table"), :CurrentItem))
        if selected != nil
          error = ""
          UsersCache.SetCurrentFocus(selected)
          if current_summary == "users"
            Users.SelectUserByName(selected)
            if ev_id == :delete
              ev_id = DeleteUserPopup()
            else
              error = Users.EditUser({})
            end
          else
            Users.SelectGroupByName(selected)
            if UsersCache.GetGroupType == "nis"
              # error popup
              Report.Message(
                _(
                  "NIS groups can only be\nmodified and deleted on the server.\n"
                )
              )
              ev_id = nil
            end

            if ev_id == :delete
              ev_id = DeleteGroupPopup()
            else
              error = Users.EditGroup({})
            end
          end
          if error != ""
            Report.Error(error)
            return nil
          end
        else
          # error popup
          Report.Message(_("Select an entry from the table."))
          return nil
        end
      end
      if ev_id == :enc
        enc = EncryptionPopup()
        if enc != Users.EncryptionMethod
          if enc != "des" && Users.NISMaster && !Users.NotAskNISServerNotDES
            return nil if AskForNISServerEncryptionPopup(enc) != :ok
          end
          Users.SetEncryptionMethod(enc)
        end
        return nil
      end
      if ev_id == :autologinconf
        AutologinPopup()
        return nil
      end
      if ev_id == :save
        if !Users.Modified
          #popup message (user wants to save but there is no modification)
          Popup.Message(_("There are no changes to save."))
          return nil
        end
        Wizard.CreateDialog
        Wizard.SetDesktopTitleAndIcon("users")
        ret = WriteDialog(true)
        Wizard.CloseDialog
        Builtins.y2milestone("WriteDialog returned %1", ret)
        # LDAP expert options could be available again
        SummaryTableInit("table")
        return nil
      end
      if ev_id == :ldapfilter
        # change of search filter (only when LDAP was not modified yet)
        if LDAPSearchFilterPopup() && !Users.LDAPModified
          Users.SetLDAPNotRead(true)
          current = current_summary == "users" ?
            Users.GetCurrentUsers :
            Users.GetCurrentGroups
          if Builtins.contains(current, "ldap")
            # simulate the action "show LDAP users"
            HandleFilterLine(widget_id, { "ID" => "ldap" })
          end
          # now update the other list (not current_summary)
          current = current_summary == "users" ?
            Users.GetCurrentGroups :
            Users.GetCurrentUsers
          if Builtins.contains(current, "ldap")
            # customize view is lost... TODO
            if current_summary == "users"
              Users.ChangeCurrentGroups("ldap")
            else
              Users.ChangeCurrentUsers("ldap")
            end
          end
        end
        return nil
      end
      if ev_id == :ldapconf
        if LdapAdministrationDialog() && Ldap.ldap_modified
          if !Users.LDAPNotRead &&
              # yes/no popup (data were changed)
              Popup.YesNo(_("Reread all data from LDAP server?"))
            # read all LDAP configuration again!
            Users.SetLDAPNotRead(true)
            UsersLDAP.SetFiltersRead(false)
            UsersLDAP.SetInitialized(false)
            current = current_summary == "users" ?
              Users.GetCurrentUsers :
              Users.GetCurrentGroups
            if Builtins.contains(current, "ldap")
              # simulate the action "show LDAP users"
              HandleFilterLine(widget_id, { "ID" => "ldap" })
            end
            # now update the other list (not current_summary)
            current = current_summary == "users" ?
              Users.GetCurrentGroups :
              Users.GetCurrentUsers
            if Builtins.contains(current, "ldap")
              # customize view is lost... TODO
              if current_summary == "users"
                Users.ChangeCurrentGroups("ldap")
              else
                Users.ChangeCurrentUsers("ldap")
              end
            end
          end
          Ldap.ldap_modified = false
        end
        return nil
      end
      if !Ops.is_symbol?(ev_id)
        Builtins.y2error("strange ev_id value: %1", ev_id)
        return nil
      end
      Convert.to_symbol(ev_id)
    end

    # Initialize the value of the label with current filter and filter selection
    def InitFilterLine(widget_id)
      current_summary = UsersCache.GetCurrentSummary
      curr = ""
      if current_summary == "users"
        if UsersCache.CustomizedUsersView
          curr = Ops.get_string(@userset_to_label, "custom", "")
        else
          current_users = Users.GetCurrentUsers
          curr = Ops.get_string(
            @userset_to_label,
            Ops.get_string(current_users, 0, "custom"),
            ""
          )
        end
      else
        if UsersCache.CustomizedGroupsView
          curr = Ops.get_string(@groupset_to_label, "custom", "")
        else
          current_groups = Users.GetCurrentGroups
          curr = Ops.get_string(
            @groupset_to_label,
            Ops.get_string(current_groups, 0, "custom"),
            ""
          )
        end
      end
      UI.ReplaceWidget(
        Id(:rpfilter),
        HBox(
          # label, e.g. 'Filter: Local Users', 'Filter: Custom'
          Left(
            Label(Id(:current_filter), Builtins.sformat(_("Filter: %1"), curr))
          ),
          # MenuButton label
          MenuButton(
            Id(:sets),
            Opt(:key_F2),
            _("&Set Filter"),
            GetSetsItems(current_summary)
          )
        )
      )

      nil
    end
    def HandleFilterLine(widget_id, event)
      event = deep_copy(event)
      ev_id = Ops.get(event, "ID")
      current_summary = UsersCache.GetCurrentSummary

      if current_summary == "users" && Ops.is_string?(ev_id) &&
          Builtins.contains(
            Users.GetAvailableUserSets,
            Convert.to_string(ev_id)
          )
        if ev_id == "ldap" && Ldap.bind_pass == nil
          Ldap.SetBindPassword(Ldap.GetLDAPPassword(true))
          return nil if Ldap.bind_pass == nil
        end
        popup = false
        if ev_id == "ldap" && Users.LDAPNotRead ||
            ev_id == "nis" && Users.NISNotRead
          UI.OpenDialog(
            Opt(:decorated),
            # wait popup
            Label(_("Reading sets of users and groups. Please wait..."))
          )
          popup = true
        end
        if Users.ChangeCurrentUsers(Convert.to_string(ev_id))
          if popup
            UI.CloseDialog
            popup = false
          end
          UsersCache.SetCustomizedUsersView(ev_id == "custom")
          SummaryTableInit("table")
          InitFilterLine(widget_id)
          InitTabUsersGroups("")
        end
        UI.CloseDialog if popup
        return nil
      end
      if current_summary == "groups" && Ops.is_string?(ev_id) &&
          Builtins.contains(
            Users.GetAvailableGroupSets,
            Convert.to_string(ev_id)
          )
        if ev_id == "ldap" && Ldap.bind_pass == nil
          Ldap.SetBindPassword(Ldap.GetLDAPPassword(true))
        end
        popup = false
        if ev_id == "ldap" && Users.LDAPNotRead ||
            ev_id == "nis" && Users.NISNotRead
          UI.OpenDialog(
            Opt(:decorated),
            # wait popup
            Label(_("Reading sets of users and groups. Please wait..."))
          )
          popup = true
        end
        if Users.ChangeCurrentGroups(Convert.to_string(ev_id))
          if popup
            UI.CloseDialog
            popup = false
          end
          UsersCache.SetCustomizedGroupsView(ev_id == "custom")
          SummaryTableInit("table")
          InitFilterLine(widget_id)
          InitTabUsersGroups("")
        end
        UI.CloseDialog if popup
        return nil
      end
      if ev_id == :customize
        if CustomizePopup(current_summary) && UsersCache.CustomizedUsersView
          SummaryTableInit("table")
        end
        InitFilterLine(widget_id)
        InitTabUsersGroups("")
        return nil
      end
      if !Ops.is_symbol?(ev_id)
        Builtins.y2error("strange ev_id value: %1", ev_id)
        return nil
      end
      Convert.to_symbol(ev_id)
    end



    # helper function to get information about authentication from
    # appropriate module
    # @param [String] client
    # @return
    def get_module_data(client)
      ret = ""
      progress_orig = Progress.set(false)
      if !Builtins.contains(@installed_clients, client)
        ret = Summary.NotConfigured
      elsif client == "sssd"
        AuthClient.Read
        ret = AuthClient.Summary
      elsif client == "nis"
        WFM.CallFunction("nis_auto", ["Read"])
        a = WFM.CallFunction("nis_auto", ["ShortSummary"])
        ret = Convert.to_string(a) if Ops.is_string?(a)
      elsif client == "samba"
        WFM.CallFunction("samba-client_auto", ["Read"])
        a = WFM.CallFunction("samba-client_auto", ["ShortSummary"])
        ret = Convert.to_string(a) if Ops.is_string?(a)
      end
      Progress.set(progress_orig)
      ret
    end

    # Reloads the configuration for given client and creates updated
    # summary widget contents
    # returns the summary value for richtext
    def reload_config(clients)
      clients = deep_copy(clients)
      summary = ""
      if clients == nil || clients == []
        clients = deep_copy(@configurable_clients)
      end
      Builtins.foreach(clients) do |client|
        summary = Summary.AddHeader(
          summary,
          Builtins.sformat(
            "<font color=\"#8BC460\"><a href=\"%1\">%2</a></font>",
            client,
            Ops.get_string(@client_label, client, client)
          )
        )
        summary = Summary.AddLine(summary, get_module_data(client))
      end
      summary
    end


    # Init the widgets in Authentication tab
    def InitAuthData(key)
      mb = []

      auth_methods = {
        "nis" => {
          # menubutton label
          "label" => _("&NIS"),
          "package" => "yast2-nis-client",
        },
        "sssd" => {
          # menubutton label
          "label" => _("&SSSD"),
          "package" => "yast2-auth-client",
        },
        "samba" => {
          # menubutton label
          "label" => _("&Samba"),
          "package" => "yast2-samba-client",
        },
      }

      # check availability of authentication packages,
      # update the RichText summary and menubutton labels accordingly
      Builtins.foreach(@configurable_clients) do |client|
        package = auth_methods[client]["package"] or raise "Unknown auth client #{client}"

        client_item = Item(
          Id(client),
          auth_methods[client]["label"]
        )

        if Package.Installed(package)
          @installed_clients = Builtins.add(@installed_clients, client)
        end

        mb << client_item

        UI.ChangeWidget(
          Id("auth_summary"),
          :Value,
          Ops.add(
            Convert.to_string(UI.QueryWidget(Id("auth_summary"), :Value)),
            reload_config([client])
          )
        )
      end

      if ! mb.empty?
        UI.ReplaceWidget(
          Id(:rpbutton),
          # menu button label
          MenuButton(Opt(:key_F4), _("&Configure..."), mb)
        )
      end

      nil
    end


    # Handler for actions in Authentication tab
    def HandleAuthData(key, event)
      event = deep_copy(event)
      return nil if Ops.get_string(event, "EventType", "") != "MenuEvent"
      button = Ops.get_string(event, "ID", "")

      return nil if !Builtins.contains(@configurable_clients, button)

      if !Builtins.contains(@installed_clients, button)
        package = button == "sssd" ? "yast2-auth-client" : "yast2-#{button}-client" 
        if @check_available
          avai = Package.Available(package)
          if avai == nil
            # package manager is probably not accessible -> no more checks
            @check_available = false
          end
          if avai != true
            # error popup, %1 is package name
            Popup.Error(
              Builtins.sformat(
                _("Package %1 is not available for installation."),
                package
              )
            )
            @configurable_clients = Builtins.filter(@configurable_clients) do |p|
              p != button
            end
            UI.ChangeWidget(Id("auth_summary"), :Value, reload_config([]))
            return nil
          end
        end
        if Package.InstallAllMsg(
            [package],
            # popup label (%1 is package to install)
            Builtins.sformat(
              _("Package %1 is not installed.\nInstall it now?\n"),
              package
            )
          )
          @installed_clients = Builtins.add(@installed_clients, button)
        else
          return nil
        end
      end
      param = installation ? ["from_users"] : []
      if WFM.CallFunction(Ops.get_string(@call_module, button, button), param) == :next
        UI.ChangeWidget(Id("auth_summary"), :Value, reload_config([]))
      end
      nil
    end

    # Actions done when Authentication tab is left
    def StoreAuthData(key, event)
      event = deep_copy(event)
      was_nis_available = Users.NISAvailable
      was_ldap_available = Users.LDAPAvailable
      Users.ReadSourcesSettings

      # enabling NIS/LDAP could add + lines (they are not in current cache that
      # would be saved after user modifications):
      if !was_nis_available && Users.NISAvailable ||
          !was_ldap_available && Users.LDAPAvailable
        Builtins.y2milestone("ldap or nis enabled now")
        Users.AddPlusPasswd("+::::::")
        Users.AddPlusGroup("+:::")
        Users.AddPlusShadow("+")
      end

      nil
    end
  end
end
