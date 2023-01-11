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

# File:	include/users/dialogs.rb
# Package:	Configuration of users and groups
# Summary:	Wizards definitions
# Authors:	Johannes Buchhold <jbuch@suse.de>,
#          Jiri Suchomel <jsuchome@suse.cz>
#
# $Id$

require "pathname"
require "shellwords"

require "users/ssh_public_key"
require "yast2/popup"
require "y2users/username"

module Yast
  module UsersDialogsInclude
    def initialize_users_dialogs(include_target)
      textdomain "users"

      Yast.import "Autologin"
      Yast.import "GetInstArgs"
      Yast.import "FileUtils"
      Yast.import "Label"
      Yast.import "Ldap"
      Yast.import "LdapPopup"
      Yast.import "Message"
      Yast.import "Package"
      Yast.import "Popup"
      Yast.import "ProductFeatures"
      Yast.import "Report"
      Yast.import "Stage"
      Yast.import "String"
      Yast.import "Users"
      Yast.import "UsersCache"
      Yast.import "UsersLDAP"
      Yast.import "UsersPlugins"
      Yast.import "UsersRoutines"
      Yast.import "UsersSimple"
      Yast.import "Wizard"
      Yast.import "Mode"

      Yast.include include_target, "users/helps.rb"
      Yast.include include_target, "users/routines.rb"

      @default_pw = "******"
    end

    # Uppercase letters were used in username! (see bug #26409)
    # In these popups, ask user what to do.
    def AskForUppercasePopup(username)
      ret = :ok

      if username != Builtins.tolower(username) && !Users.NotAskUppercase &&
          Package.InstalledAny(["sendmail", "postfix"])
        # The login name contains uppercase 1/3
        text = _(
          "<p>\nYou have used uppercase letters in the user login entry.</p>"
        ) +
          # The login name contains uppercase 2/3
          _(
            "<p>This could cause problems with delivering mail\n" +
              "to this user, because mail systems generally do not\n" +
              "support case-sensitive names.<br>\n" +
              "You could solve this problem by editing the alias table.</p>\n"
          ) +
          # The login name contains uppercase 3/3
          _("<p>Really use the entered value?</p>")

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
          Users.SetAskUppercase(
            Convert.to_boolean(UI.QueryWidget(Id(:ch), :Value))
          )
        end
        UI.CloseDialog
      end
      ret
    end

    # Ask user for current password, see bugs 242531, 244718
    # @return [String] or nil when dialog was canceled
    def AskForOldPassword
      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          HSpacing(0.5),
          VBox(
            VSpacing(0.5),
            # password entry label
            Password(
              Id(:pw1),
              Opt(:hstretch),
              _(
                "To access the data required to modify\n" +
                  "the encryption settings for this user,\n" +
                  "enter the user's current password."
              )
            ),
            Password(Id(:pw2), Opt(:hstretch), Label.ConfirmPassword, ""),
            HBox(
              PushButton(Id(:ok), Opt(:key_F10), Label.OKButton),
              PushButton(Id(:cancel), Opt(:key_F9), Label.CancelButton)
            ),
            VSpacing(0.5)
          ),
          HSpacing(0.5)
        )
      )
      ret = :cancel
      begin
        ret = UI.UserInput
        if ret == :ok
          if UI.QueryWidget(Id(:pw1), :Value) !=
              UI.QueryWidget(Id(:pw2), :Value)
            Report.Error(_("The passwords do not match.\nTry again."))
            ret = :notnext
            next
          end
        end
      end until ret == :ok || ret == :cancel

      pw = Convert.to_string(UI.QueryWidget(Id(:pw1), :Value))
      UI.CloseDialog
      ret == :ok ? pw : nil
    end


    # helper function: show a popup if existing home directory should be used
    # and its ownership should be changed
    # @param dir [String]
    # @param chown_default [Boolean]
    def ask_chown_home(dir, chown_default)
      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          HSpacing(1),
          VBox(
            VSpacing(0.2),
            Label(
              # popup label, %1 is path to directory
              Builtins.sformat(_("The home directory (%1) already exists.\nUse it anyway?"), dir)
            ),
            Left(
              # checkbox label
              CheckBox(Id(:chown_home), _("&Change directory owner"), chown_default)
            ),
            ButtonBox(
              PushButton(Id(:yes), Opt(:default), Label.YesButton),
              PushButton(Id(:no), Label.NoButton)
            ),
            VSpacing(0.2)
          ),
          HSpacing(1)
        )
      )
      answer = UI.UserInput == :yes
      retmap = { "retval" => answer }
      if answer
        retmap["chown_home"] = UI.QueryWidget(Id(:chown_home), :Value)
      end
      UI.CloseDialog
      retmap
    end

    # @param count [Integer] number of days after 1970-01-01
    # @param date_format [String] strftime format like "%x" (localized date)
    # @return [String]
    def format_days_after_epoch(count, date_format)
      `date --date='1970-01-01 00:00:01 #{count} days' +#{date_format}`.chomp
    end

    # generate contents for Password Settings Dialog
    # @param user [Hash]
    # @param exp_date [String] may be MODIFIED on return corresponding to the UI
    # @return [Term] ui_term
    def get_password_term(user, exp_date)
      last_change = GetString(Ops.get(user, "shadowLastChange"), "0")
      last_change_label = ""
      expires = GetString(Ops.get(user, "shadowExpire"), "0")
      expires = "0" if expires == ""

      inact = GetInt(Ops.get(user, "shadowInactive"), -1)
      max = GetInt(Ops.get(user, "shadowMax"), -1)
      min = GetInt(Ops.get(user, "shadowMin"), -1)
      warn = GetInt(Ops.get(user, "shadowWarning"), -1)

      if last_change != "0"
        last_change_label = format_days_after_epoch(last_change, "%x")
      else
        # label (date of last password change)
        last_change_label = _("Never")
      end
      unless ["0", "-1", ""].include?(expires)
        exp_date.replace(format_days_after_epoch(expires, "%Y-%m-%d"))
      end
      HBox(
        HSpacing(3),
        VBox(
          VStretch(),
          Left(Label("")),
          HSquash(
            VBox(
              Left(
                Label(
                  # label
                  Builtins.sformat(_("Last Password Change: %1"), last_change_label)
                )
              ),
              VSpacing(0.2),
              Left(
                # check box label
                CheckBox(Id(:force_pw), _("Force Password Change"), last_change == "0")
              ),
              VSpacing(1),
              IntField(
                Id("shadowWarning"),
                # intfield label
                _("Days &before Password Expiration to Issue Warning"),
                -1,
                99999,
                warn
              ),
              VSpacing(0.5),
              IntField(
                Id("shadowInactive"),
                # intfield label
                _("Days after Password Expires with Usable &Login"),
                -1,
                99999,
                inact
              ),
              VSpacing(0.5),
              IntField(
                Id("shadowMax"),
                # intfield label
                _("Ma&ximum Number of Days for the Same Password"),
                -1,
                99999,
                max
              ),
              VSpacing(0.5),
              IntField(
                Id("shadowMin"),
                # intfield label
                _("&Minimum Number of Days for the Same Password"),
                -1,
                99999,
                min
              ),
              VSpacing(0.5),
              InputField(
                Id("shadowExpire"),
                Opt(:hstretch),
                # textentry label
                _("Ex&piration Date"),
                exp_date
              )
            )
          ),
          VStretch()
        ),
        HSpacing(3)
      )
    end

    # Dialog for adding or editing a user.
    # @param [String] what "add_user" or "edit_user"
    # @return [Symbol] for wizard sequencer
    def EditUserDialog(what)
      # user has returned to the "add user dialog" during installation workflow:
      if Users.StartDialog("user_add") && installation && Users.UseNextTime
        Users.RestoreCurrentUser
        Users.SetUseNextTime(false)
      end

      display_info = UI.GetDisplayInfo
      text_mode = Ops.get_boolean(display_info, "TextMode", false)

      user = Users.GetCurrentUser
      error_msg = ""

      if user == {}
        error_msg = Users.AddUser({})
        if error_msg != ""
          Popup.Error(error_msg)
          return :back
        end
        user = Users.GetCurrentUser
      end

      action = Ops.get_string(user, "modified", "")
      action = what == "add_user" ? "added" : "edited" if action == ""

      user_type = Ops.get_string(user, "type", "local")
      username = Ops.get_string(user, "uid", "")
      cn = ""
      # in LDAP, cn is list of strings
      if Ops.is_list?(Ops.get(user, "cn"))
        cn = Ops.get_string(user, ["cn", 0], "")
      else
        cn = Ops.get_string(user, "cn", "")
      end
      default_home = Users.GetDefaultHome(user_type)
      home = Ops.get_string(user, "homeDirectory", default_home)
      org_home = Ops.get_string(user, "org_homeDirectory", home)
      default_mode = Builtins.sformat(
        "%1",
        Ops.subtract(777, Builtins.tointeger(String.CutZeros(Users.GetUmask)))
      )
      mode = Ops.get_string(user, "home_mode", default_mode)
      password = Ops.get_string(user, "userPassword")
      org_username = Ops.get_string(user, "org_uid", username)
      uid = GetInt(Ops.get(user, "uidNumber"), nil)
      gid = GetInt(Ops.get(user, "gidNumber"), Users.GetDefaultGID(user_type))
      enabled = Ops.get_boolean(user, "enabled", true)
      enabled = false if Ops.get_boolean(user, "disabled", false)

      shell = Ops.get_string(user, "loginShell", "")
      defaultgroup = Ops.get_string(user, "groupname", "")
      # additional parts of GECOS (shown by `finger <username>`) (passwd only)
      addit_data = Ops.get_string(user, "addit_data", "")

      # this user gets root's mail
      root_mail = Builtins.haskey(Users.GetRootAliases, username)
      root_mail_checked = root_mail

      # if user's password should be set to root
      root_pw = false

      # only for LDAP users:
      sn = ""
      if Builtins.haskey(user, "sn")
        if Ops.is_list?(Ops.get(user, "sn"))
          sn = Ops.get_string(user, ["sn", 0]) { SplitFullName(:sn, cn) }
        else
          sn = Ops.get_string(user, "sn") { SplitFullName(:sn, cn) }
        end
      end
      givenname = ""
      if Builtins.haskey(user, "givenName")
        if Ops.is_list?(Ops.get(user, "givenName"))
          givenname = Ops.get_string(user, ["givenName", 0]) do
            SplitFullName(:givenname, cn)
          end
        elsif Ops.is_string?(Ops.get(user, "givenName"))
          givenname = Ops.get_string(user, "givenName") do
            SplitFullName(:givenname, cn)
          end
        end
      end

      create_home = Ops.get_boolean(user, "create_home", true)
      chown_home = Ops.get_boolean(user, "chown_home", true)
      no_skel = Ops.get_boolean(user, "no_skeleton", false)
      if user["btrfs_subvolume"] && user["btrfs_subvolume"].is_a?(::String)
        # Users.GetCurrentUser Perl module can also return "1" for a boolean
        user["btrfs_subvolume"] = user["btrfs_subvolume"] == "1"
      end

      btrfs_subvolume = Ops.get_boolean(user, "btrfs_subvolume", false)
      do_not_edit = user_type == "nis"

      complex_layout = installation && Users.StartDialog("user_add")
      groups = Ops.get_map(user, "grouplist", {})

      available_shells = Users.AllShells
      new_type = user_type

      all_groupnames = UsersCache.GetAllGroupnames

      # backup NIS groups of user (they are not shown in details dialog)
      nis_groups = {}
      Builtins.foreach(groups) do |group, val|
        if Ops.get(all_groupnames, ["nis", group], 0) == 1
          Ops.set(nis_groups, group, 1)
        end
      end
      # of local group list of remote user was modified
      grouplist_modified = false

      # date of password expiration
      exp_date = ""

      plugin_client = ""
      plugin = ""
      client2plugin = {}
      # names of plugin GUI clients
      clients = []

      # initialize local variables with current state of user
      reinit_userdata = lambda do
        user_type = Ops.get_string(user, "type", user_type)
        username = Ops.get_string(user, "uid", username)
        if Ops.is_list?(Ops.get(user, "cn"))
          cn = Ops.get_string(user, ["cn", 0], cn)
        else
          cn = Ops.get_string(user, "cn", cn)
        end
        home = Ops.get_string(user, "homeDirectory", home)
        org_home = Ops.get_string(user, "org_homeDirectory", org_home)
        mode = Ops.get_string(user, "home_mode", default_mode)
        password = Ops.get_string(user, "userPassword", password)
        org_username = Ops.get_string(user, "org_uid", org_username)
        uid = GetInt(Ops.get(user, "uidNumber"), uid)
        gid = GetInt(Ops.get(user, "gidNumber"), gid)
        enabled = Ops.get_boolean(user, "enabled", true)
        enabled = false if Ops.get_boolean(user, "disabled", false)

        shell = Ops.get_string(user, "loginShell", shell)
        defaultgroup = Ops.get_string(user, "groupname", defaultgroup)
        addit_data = Ops.get_string(user, "addit_data", addit_data)

        if Builtins.haskey(user, "sn")
          if Ops.is_list?(Ops.get(user, "sn"))
            sn = Ops.get_string(user, ["sn", 0]) { SplitFullName(:sn, cn) }
          else
            sn = Ops.get_string(user, "sn") { SplitFullName(:sn, cn) }
          end
        end
        if Builtins.haskey(user, "givenName")
          if Ops.is_list?(Ops.get(user, "givenName"))
            givenname = Ops.get_string(user, ["givenName", 0]) do
              SplitFullName(:givenname, cn)
            end
          elsif Ops.is_string?(Ops.get(user, "givenName"))
            givenname = Ops.get_string(user, "givenName") do
              SplitFullName(:givenname, cn)
            end
          end
        end

        chown_home = Ops.get_boolean(user, "chown_home", chown_home)
        no_skel = Ops.get_boolean(user, "no_skeleton", no_skel)
        btrfs_subvolume = Ops.get_boolean(user, "btrfs_subvolume", btrfs_subvolume)
        groups = Ops.get_map(user, "grouplist", {})
        do_not_edit = user_type == "nis"

        nil
      end

      # generate contents for User Data Dialog
      get_edit_term = lambda do
        # text entry
        fullnamelabel = _("User's &Full Name")
        name_entries = what == "add_user" ?
          InputField(Id(:cn), Opt(:notify), fullnamelabel, cn) :
          InputField(Id(:cn), fullnamelabel, cn)

        if user_type == "ldap"
          name_entries = HBox(
            # text entry
            InputField(Id(:givenname), _("&First Name"), givenname),
            HSpacing(0.8),
            # text entry
            InputField(Id(:sn), _("&Last Name"), sn)
          )
        end

        fields = VBox(
          # label text
          do_not_edit ?
            Label(
              _(
                "For remote users, only additional group memberships can be changed."
              )
            ) :
            VSpacing(0),
          do_not_edit ? VSpacing(1) : VSpacing(0),
          name_entries,
          InputField(
            Id(:username),
            what == "add_user" ? Opt(:notify, :hstretch) : Opt(:hstretch),
            # input field for login name
            _("&Username"),
            username
          ),
          VSpacing(),
          Password(Id(:pw1), Opt(:hstretch), Label.Password, ""),
          Password(Id(:pw2), Opt(:hstretch), Label.ConfirmPassword, "")
        )

        optionbox = VBox(
          # checkbox label
          Left(
            CheckBox(
              Id(:root_mail),
              _("Receive S&ystem Mail"),
              root_mail_checked
            )
          )
        )
        if complex_layout
          optionbox = Builtins.add(
            optionbox,
            # checkbox label
            Left(
              CheckBox(Id(:autologin), _("A&utomatic Login"), Autologin.used)
            )
          )
          root_pw_feature = ProductFeatures.GetFeature(
            "globals",
            "root_password_as_first_user"
          )
          if root_pw_feature != ""
            optionbox = Builtins.add(
              optionbox,
              Left(
                CheckBox(
                  Id(:root_pw),
                  # checkbox label
                  _("U&se this password for system administrator"),
                  root_pw_feature == true
                )
              )
            )
          end
        elsif !do_not_edit && !installation
          optionbox = Builtins.add(
            optionbox,
            # check box label
            Left(CheckBox(Id(:ena), _("D&isable User Login"), !enabled))
          )
        end
        contents = VBox(
          VSpacing(),
          VBox(
            VSpacing(0.5),
            HBox(
              HSpacing(2),
              VBox(
                HSquash(fields),
                VSpacing(0.5),
                HBox(HStretch(), HCenter(HVSquash(optionbox)), HStretch())
              ),
              HSpacing(2)
            ),
            VSpacing(0.5)
          )
        )

        if complex_layout
          contents = Builtins.add(
            contents,
            VBox(
              HCenter(
                PushButton(
                  Id(:additional),
                  Opt(:key_F3),
                  # push button
                  _("User &Management")
                )
              ),
              VSpacing(0.5)
            )
          )
        end
        HVCenter(contents)
      end

      # generate contents for User Details Dialog
      get_details_term = lambda do
        available_groups = []
        additional_groups = []
        additional_ldap_groups = []
        defaultgroup_shown = false

        # fill the list available_groups and set the user default group true
        Builtins.foreach(all_groupnames) do |grouptype, groupmap|
          if grouptype == "local" || grouptype == "system" ||
              grouptype == "ldap" && user_type == "ldap"
            Builtins.foreach(groupmap) do |group, val|
              if user_type == "ldap"
                if grouptype == "ldap"
                  if group == defaultgroup
                    available_groups = Builtins.add(
                      available_groups,
                      Item(Id(group), group, true)
                    )
                    defaultgroup_shown = true
                  else
                    available_groups = Builtins.add(
                      available_groups,
                      Item(Id(group), group)
                    )
                  end
                  if Builtins.haskey(groups, group)
                    additional_ldap_groups = Builtins.add(
                      additional_ldap_groups,
                      Item(Id(group), group, true)
                    )
                  else
                    additional_ldap_groups = Builtins.add(
                      additional_ldap_groups,
                      Item(Id(group), group, false)
                    )
                  end
                else
                  # if there is a group with same name, use only that
                  # with type "ldap"
                  next if Ops.get(all_groupnames, ["ldap", group], 0) == 1
                  if Builtins.haskey(groups, group)
                    additional_groups = Builtins.add(
                      additional_groups,
                      Item(Id(group), group, true)
                    )
                  else
                    additional_groups = Builtins.add(
                      additional_groups,
                      Item(Id(group), group, false)
                    )
                  end
                end
              else
                if group == defaultgroup
                  available_groups = Builtins.add(
                    available_groups,
                    Item(Id(group), group, true)
                  )
                  defaultgroup_shown = true
                else
                  available_groups = Builtins.add(
                    available_groups,
                    Item(Id(group), group)
                  )
                end
                if Builtins.haskey(groups, group)
                  additional_groups = Builtins.add(
                    additional_groups,
                    Item(Id(group), group, true)
                  )
                else
                  additional_groups = Builtins.add(
                    additional_groups,
                    Item(Id(group), group, false)
                  )
                end
              end
            end
          end
        end
        # show default group, even if the type is 'wrong' (#43433)
        if !defaultgroup_shown
          if Ops.get(all_groupnames, ["local", defaultgroup], 0) == 1 ||
              Ops.get(all_groupnames, ["system", defaultgroup], 0) == 1
            available_groups = Builtins.add(
              available_groups,
              Item(Id(defaultgroup), defaultgroup, true)
            )
          end
        end

        if defaultgroup == ""
          available_groups = Builtins.add(
            available_groups,
            # group name is not known (combobox item):
            Item(Id(""), _("(Unknown)"), true)
          )
        end

        edit_defaultgroup = ComboBox(
          Id(:defaultgroup),
          Opt(:hstretch),
          # combobox label
          _("De&fault Group"),
          available_groups
        )
        edit_shell = ComboBox(
          Id(:shell),
          Opt(:hstretch, :editable),
          # combobox label
          _("Login &Shell"),
          available_shells
        )

        additional_data = Empty()
        if user_type == "system" || user_type == "local"
          additional_data = Top(
            InputField(
              Id(:addd),
              Opt(:hstretch),
              # textentry label
              _("Addi&tional User Information"),
              addit_data
            )
          )
        end

        browse = VBox(
          VSpacing(1),
          PushButton(Id(:browse), Opt(:key_F6), _("B&rowse..."))
        )

        home_w = VBox(
          InputField(Id(:home), Opt(:hstretch), _("&Home Directory"), home),
        )
        new_user_term = action != "added" ?
          VBox() :
          VBox(
            InputField(
              Id(:mode),
              Opt(:hstretch),
              # textentry label
              _("Home Directory &Permission Mode"),
              mode
            ),
            # check box label
            HBox(
              HSpacing(),
              Left(CheckBox(Id(:skel), _("E&mpty Home"), no_skel))
            )
          )

        HBox(
          HSpacing(1),
          VBox(
            # label
            do_not_edit ?
              Label(
                _(
                  "For remote users, only additional \ngroup memberships can be changed."
                )
              ) :
              VSpacing(0),
            HBox(
              text_mode ? Empty() : HSpacing(1),
              HWeight(
                3,
                VBox(
                  VSpacing(0.5),
                  Top(
                    InputField(
                      Id(:uid),
                      Opt(:hstretch),
                      # textentry label
                      _("User &ID (uid)"),
                      Builtins.sformat("%1", uid)
                    )
                  ),
                  Top(
                    VBox(
                      VSpacing(1),
                      HBox(home_w, browse),
                      move_to_new_location_checkbox(action, create_home),
                      new_user_term,
                      HBox(
                        HSpacing(),
                        Left(CheckBox(Id(:btrfs_subvolume), btrfs_label, btrfs_subvolume))
                      ),
                    )
                  ),
                  VSpacing(1),
                  additional_data,
                  text_mode ? Empty() : HSpacing(1),
                  Top(edit_shell),
                  VStretch()
                )
              ),
              HSpacing(2),
              HWeight(
                2,
                VBox(
                  VSpacing(0.5),
                  edit_defaultgroup,
                  VSpacing(0.5),
                  MultiSelectionBox(
                    Id(:grouplist),
                    # selection box label
                    _("Additional Gr&oups"),
                    additional_groups
                  ),
                  user_type == "ldap" ?
                    MultiSelectionBox(
                      Id(:ldapgrouplist),
                      # selection box label
                      _("&LDAP Groups"),
                      additional_ldap_groups
                    ) :
                    Empty()
                )
              ),
              text_mode ? Empty() : HSpacing(1)
            ),
          ),
          HSpacing(1)
        )
      end

      # generate contents for Plugins Dialog
      get_plugins_term = lambda do
        plugin_client = Ops.get(clients, 0, "")
        plugin = Ops.get_string(client2plugin, plugin_client, plugin_client)

        items = []
        Builtins.foreach(clients) do |cl|
          summary = WFM.CallFunction(cl, ["Summary", { "what" => "user" }])
          pl = Ops.get_string(client2plugin, cl, cl)
          if Ops.is_string?(summary)
            items = Builtins.add(
              items,
              Item(
                Id(cl),
                Builtins.contains(Ops.get_list(user, "plugins", []), pl) ?
                  UI.Glyph(:CheckMark) :
                  " ",
                summary
              )
            )
          end
        end
        HBox(
          HSpacing(0.5),
          VBox(
            Table(
              Id(:table),
              Opt(:notify),
              Header(
                " ",
                # table header
                _("Plug-In Description")
              ),
              items
            ),
            HBox(
              PushButton(
                Id(:change),
                Opt(:key_F3),
                # pushbutton label
                _("Add or &Remove Plug-In")
              ),
              # pushbutton label
              Right(PushButton(Id(:run), Opt(:key_F6), _("&Launch")))
            ),
            VSpacing(0.5)
          ),
          HSpacing(0.5)
        )
      end


      dialog_labels = {
        "add_user"  => {
          # dialog caption:
          "local"  => _("New Local User"),
          # dialog caption:
          "system" => _("New System User"),
          # dialog caption:
          "ldap"   => _("New LDAP User")
        },
        "edit_user" => {
          # dialog caption:
          "local"  => _("Existing Local User"),
          # dialog caption:
          "system" => _("Existing System User"),
          # dialog caption:
          "ldap"   => _("Existing LDAP User"),
          # dialog caption:
          "nis"    => _("Existing NIS User")
        }
      }

      tabs = [
        # tab label
        Item(Id(:edit), _("Us&er Data"), true),
        # tab label
        Item(Id(:details), _("&Details"))
      ]

      if !do_not_edit && user_type != "ldap"
        # tab label
        tabs = Builtins.add(
          tabs,
          Item(Id(:passwordsettings), _("Pass&word Settings"))
        )
      end

      if user["type"] == "local" || user["uid"] == "root"
        tabs << Item(Id(:authorized_keys), _("SSH Public Keys"))
      end

      # Now initialize the list of plugins: we must know now if there is some available.
      # UsersPlugins will filter out plugins we cannot use for given type
      plugin_clients = UsersPlugins.Apply(
        "GUIClient",
        { "what" => "user", "type" => user_type },
        {}
      )
      # remove empty clients
      plugin_clients = Builtins.filter(
        Convert.convert(
          plugin_clients,
          :from => "map",
          :to   => "map <string, string>"
        )
      ) { |plugin2, client| client != "" }
      clients = Builtins.maplist(
        Convert.convert(
          plugin_clients,
          :from => "map",
          :to   => "map <string, string>"
        )
      ) do |plugin2, client|
        Ops.set(client2plugin, client, plugin2)
        client
      end
      if clients != []
        # tab label
        tabs = Builtins.add(tabs, Item(Id(:plugins), _("Plu&g-Ins")))
      end

      dialog_contents = VBox(
        DumbTab(
          Id(:tabs),
          tabs,
          ReplacePoint(Id(:tabContents), get_edit_term.call)
        )
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
        dialog_contents = VBox(
          Left(tabbar),
          Frame("", ReplacePoint(Id(:tabContents), get_edit_term.call))
        )
      end
      if complex_layout
        dialog_contents = ReplacePoint(Id(:tabContents), get_edit_term.call)
        Wizard.SetContents(
          Ops.get_string(dialog_labels, [what, user_type], ""),
          dialog_contents,
          EditUserDialogHelp(complex_layout, user_type, what),
          GetInstArgs.enable_back,
          GetInstArgs.enable_next
        )
      else
        Wizard.SetContentsButtons(
          Ops.get_string(dialog_labels, [what, user_type], ""),
          dialog_contents,
          EditUserDialogHelp(complex_layout, user_type, what),
          Label.CancelButton,
          Label.OKButton
        )
        Wizard.HideAbortButton
      end

      ret = :edit
      current = nil
      login_modified = false
      tabids = [:edit, :details, :passwordsettings, :plugins]
      ldap_user_defaults = UsersLDAP.GetUserDefaults

      # switch focus to specified tab (after error message) and widget inside
      focus_tab = lambda do |tab, widget|
        widget = deep_copy(widget)
        UI.ChangeWidget(Id(:tabs), :CurrentItem, tab) if has_tabs
        UI.SetFocus(Id(widget))
        ret = :notnext

        nil
      end

      # map with id's of confirmed questions
      ui_map = {}

      while true
        # map returned from Check*UI functions
        error_map = {}
        # error message
        error = ""

        ret = Convert.to_symbol(UI.UserInput) if current != nil

        if (ret == :abort || ret == :cancel) && ReallyAbort() != :abort
          ret = :notnext
          next
        end
        break if Builtins.contains([:abort, :back, :cancel], ret)
        ret = :next if ret == :ok

        tab = Builtins.contains(tabids, ret)
        next if tab && ret == current

        # ------------------- handle actions inside the tabs

        # 1. click inside User Data dialog or moving outside of it
        if current == :edit
          username = Convert.to_string(UI.QueryWidget(Id(:username), :Value))

          # empty username during installation (-> go to next module)
          if username == "" && ret == :next && Users.StartDialog("user_add")
            # The user login field is empty, this is allowed if the
            # system is part of a network with (e.g.) NIS user management.
            # yes-no popup headline
            if Popup.YesNoHeadline(
                _("Empty User Login"),
                # yes-no popup contents
                _(
                  "Leaving the user name empty only makes sense\n" +
                    "in a network environment with an authentication server.\n" +
                    "Leave it empty?"
                )
              )
              ret = :nextmodule
              break
            end
            focus_tab.call(current, :username)
            next
          end

          # now gather user data from dialog
          if user_type == "ldap"
            # Form the fullname for LDAP user
            # sn (surname) and cn (fullname) are required attributes,
            # they cannot be empty
            givenname = Convert.to_string(
              UI.QueryWidget(Id(:givenname), :Value)
            )
            sn = Convert.to_string(UI.QueryWidget(Id(:sn), :Value))

            # create default cn/sn if they are not marked for substitution
            if sn == "" &&
                (what == "edit_user" ||
                  !Builtins.haskey(ldap_user_defaults, "sn"))
              if givenname == ""
                sn = username
              else
                sn = givenname
                givenname = ""
              end
            end
            # enable changing of cn value only if LDAP user is not saved yet (bnc#904645)
            if (cn == "" || action == "added") &&
                # no substitution when editing: TODO bug 238282
                (what == "edit_user" ||
                  !# cn should not be substituted:
                  Builtins.haskey(ldap_user_defaults, "cn"))
              # if 'givenname' or 'sn' should be substituted, wait for it
              # and do not create cn now:
              if !Builtins.haskey(ldap_user_defaults, "sn") &&
                  !Builtins.haskey(ldap_user_defaults, "givenName")
                cn = Ops.add(Ops.add(givenname, givenname != "" ? " " : ""), sn)
              end
            end
            UI.ChangeWidget(Id(:givenname), :Value, givenname)
            UI.ChangeWidget(Id(:sn), :Value, sn)
          else
            cn = Convert.to_string(UI.QueryWidget(Id(:cn), :Value))
            error = UsersSimple.CheckFullname(cn)
            if error != ""
              Report.Error(error)
              focus_tab.call(current, :cn)
              next
            end
          end
          if Builtins.haskey(user, "givenName") &&
              Ops.is_list?(Ops.get(user, "givenName"))
            Ops.set(user, ["givenName", 0], givenname)
          else
            Ops.set(user, "givenName", givenname)
          end
          if Builtins.haskey(user, "sn") && Ops.is_list?(Ops.get(user, "sn"))
            Ops.set(user, ["sn", 0], sn)
          else
            Ops.set(user, "sn", sn)
          end
          if Builtins.haskey(user, "cn") && Ops.is_list?(Ops.get(user, "cn"))
            Ops.set(user, ["cn", 0], cn)
          else
            Ops.set(user, "cn", cn)
          end

          # generate a login name from the full name
          # (not for LDAP, there are customized rules...)
          if ret == :cn
            uname = Convert.to_string(UI.QueryWidget(Id(:username), :Value))
            login_modified = false if login_modified && uname == "" # reenable suggestion
            if !login_modified
              full_name = UI.QueryWidget(Id(ret), :Value)
              username = Y2Users::Username.generate_from(full_name)
              UI.ChangeWidget(Id(:username), :Value, username)
            end
          end
          login_modified = true if ret == :username
          # in continue mode: move to 'User Management' without adding user
          if ret == :additional
            if username == "" &&
                (user_type == "ldap" && cn == "" && givenname == "" ||
                  user_type != "ldap" && cn == "")
              ret = :nosave
            end
          end
        end
        # now check if currently added user data are correct
        # (going out from User Data tab)
        if current == :edit && !do_not_edit &&
            (ret == :next || ret == :additional || tab)
          # --------------------------------- username checks, part 1/2
          error = Users.CheckUsername(username)
          if error != ""
            Report.Error(error)
            focus_tab.call(current, :username)
            next
          end
          Ops.set(user, "uid", username)

          # --------------------------------- uid check (for nil value)
          if !tab && uid == nil
            error = Users.CheckUID(uid)
            if error != ""
              Report.Error(error)
              focus_tab.call(current, :details)
              next
            end
          end

          # --------------------------------- password checks
          pw1 = Convert.to_string(UI.QueryWidget(Id(:pw1), :Value))
          pw2 = Convert.to_string(UI.QueryWidget(Id(:pw2), :Value))

          if pw1 != pw2
            # The two user password information do not match
            # error popup
            Report.Error(_("The passwords do not match.\nTry again."))
            focus_tab.call(current, :pw1)
            next
          end
          if (pw1 != "" || !tab) && pw1 != @default_pw
            error = UsersSimple.CheckPassword(pw1, user_type)
            if error != ""
              Report.Error(error)
              focus_tab.call(current, :pw1)
              next
            end

            errors = UsersSimple.CheckPasswordUI(
              { "uid" => username, "userPassword" => pw1, "type" => user_type }
            )
            if errors != []
              message = Ops.add(
                Ops.add(
                  Builtins.mergestring(errors, "\n\n"),
                  # last part of message popup
                  "\n\n"
                ),
                _("Really use this password?")
              )
              if !Popup.YesNo(message)
                focus_tab.call(current, :pw1)
                next
              end
            end
            # now saving plain text password
            if Ops.get_boolean(user, "encrypted", false)
              Ops.set(user, "encrypted", false)
            end
            Ops.set(user, "userPassword", pw1)
            Ops.set(user, "shadowLastChange", Users.LastChangeIsNow)
            password = pw1
          end

          # build default home dir
          if home == "" || home == default_home ||
              Builtins.issubstring(home, "%")
            # LDAP: maybe value of homedirectory should be substituted?
            if user_type == "ldap" && Builtins.issubstring(home, "%")
              user = UsersLDAP.SubstituteValues("user", user)
              home = Ops.get_string(user, "homeDirectory", default_home)
            end
            if home == default_home || home == ""
              home = Ops.add(default_home, username)
            end
          end
          if ret != :details && username != org_username
            generated_home = Ops.add(default_home, username)
            if user_type == "ldap" && Builtins.issubstring(default_home, "%")
              tmp_user = UsersLDAP.SubstituteValues("user", user)
              generated_home = Ops.get_string(tmp_user, "homeDirectory", home)
            end
            if home != generated_home &&
                (what == "add_user" ||
                  Popup.YesNo(
                    Builtins.sformat(
                      # popup question
                      _("Change home directory to %1?"),
                      generated_home
                    )
                  ))
              home = generated_home
            end
          end
          # -------------------------------------- directory checks
          if !tab && home != org_home
            error = Users.CheckHome(home)
            if error != ""
              Report.Error(error)
              ret = :notnext
              next
            end
            failed = false
            begin
              error_map = Users.CheckHomeUI(uid, home, ui_map)
              if error_map != {}
                if Ops.get_string(error_map, "question_id", "") == "chown" &&
                    !Builtins.haskey(error_map, "owned")
                  ret2 = ask_chown_home(home, chown_home)
                  if Ops.get_boolean(ret2, "retval", false)
                    Ops.set(ui_map, "chown", home)
                    chown_home = Ops.get_boolean(ret2, "chown_home", chown_home)
                  else
                    failed = true
                  end
                else
                  if !Popup.YesNo(Ops.get_string(error_map, "question", ""))
                    failed = true
                  else
                    Ops.set(
                      ui_map,
                      Ops.get_string(error_map, "question_id", ""),
                      home
                    )
                  end
                end
              end
            end while error_map != {} && !failed

            if failed
              ret = :notnext
              next
            end
          end
          Ops.set(user, "homeDirectory", home)
          Ops.set(user, "chown_home", chown_home)

          # --------------------------------- username checks, part 2/2
          if what == "add_user" || username != org_username
            if AskForUppercasePopup(username) != :ok
              focus_tab.call(current, :username)
              next
            end
          end
          # --------------------------------- autologin (during installation)
          if Users.StartDialog("user_add") && installation
            if Autologin.available
              Autologin.user = Convert.to_boolean(
                UI.QueryWidget(Id(:autologin), :Value)
              ) ? username : ""
              Autologin.used = Convert.to_boolean(
                UI.QueryWidget(Id(:autologin), :Value)
              )
              Autologin.modified = true
            end
          elsif UI.WidgetExists(Id(:ena))
            # -------------------------------------- enable/disable checks

            new_enabled = !Convert.to_boolean(UI.QueryWidget(Id(:ena), :Value))
            if enabled != new_enabled
              enabled = new_enabled
              if enabled
                Ops.set(user, "enabled", true)
                if Builtins.haskey(user, "disabled")
                  Ops.set(user, "disabled", false)
                end
              else
                Ops.set(user, "disabled", true)
                if Builtins.haskey(user, "enabled")
                  Ops.set(user, "enabled", false)
                end
              end
            end
          end
          root_mail_checked = Convert.to_boolean(
            UI.QueryWidget(Id(:root_mail), :Value)
          )
          root_pw = UI.WidgetExists(Id(:root_pw)) &&
            Convert.to_boolean(UI.QueryWidget(Id(:root_pw), :Value))
          # save the username for possible check if it was changed
          # and home directory should be re-generated
          org_username = username if org_username == ""
        end

        # inside Details dialog
        if current == :details && ret == :browse
          start_dir = Dir.exist?(home) ? home : Users.GetDefaultHome(new_type)
          selected_dir = cleanpath(UI.AskForExistingDirectory(start_dir, ""))
          UI.ChangeWidget(Id(:home), :Value, selected_dir) unless selected_dir.empty?
        end

        # going from Details dialog
        if current == :details && (ret == :next || tab)
          new_shell = Convert.to_string(UI.QueryWidget(Id(:shell), :Value))
          new_uid = Convert.to_string(UI.QueryWidget(Id(:uid), :Value))
          new_defaultgroup = Convert.to_string(
            UI.QueryWidget(Id(:defaultgroup), :Value)
          )

          new_home = cleanpath(UI.QueryWidget(Id(:home), :Value))

          if what == "add_user"
            btrfs_subvolume = UI.QueryWidget(Id(:btrfs_subvolume), :Value)
            no_skel = Convert.to_boolean(UI.QueryWidget(Id(:skel), :Value))
            mode = Convert.to_string(UI.QueryWidget(Id(:mode), :Value))
          end

          if do_not_edit
            new_home = home
            new_shell = shell
            new_uid = Builtins.sformat("%1", uid)
            new_defaultgroup = defaultgroup
          end
          new_i_uid = Builtins.tointeger(new_uid)

          # additional data in GECOS field (passwd only)
          if new_type == "local" || new_type == "system"
            addit_data = Convert.to_string(UI.QueryWidget(Id(:addd), :Value))
            error2 = Users.CheckGECOS(addit_data)
            if error2 != ""
              Report.Error(error2)
              focus_tab.call(current, :addd)
              ret = :notnext
              next
            end
          end

          # check the uid
          if new_i_uid != uid
            error2 = Users.CheckUID(new_i_uid)
            if error2 != ""
              Report.Error(error2)
              focus_tab.call(current, :uid)
              next
            end
            failed = false
            begin
              error_map = Users.CheckUIDUI(new_i_uid, ui_map)
              if error_map != {}
                if !Popup.YesNo(Ops.get_string(error_map, "question", ""))
                  focus_tab.call(current, :uid)
                  failed = true
                else
                  Ops.set(
                    ui_map,
                    Ops.get_string(error_map, "question_id", ""),
                    new_i_uid
                  )
                  if Builtins.contains(
                      ["local", "system"],
                      Ops.get_string(error_map, "question_id", "")
                    )
                    new_type = Ops.get_string(error_map, "question_id", "local")
                    UsersCache.SetUserType(new_type)
                  end
                end
              end
            end while error_map != {} && !failed
            if failed
              focus_tab.call(current, :uid)
              next
            end
          end # end of uid checks

          if defaultgroup != new_defaultgroup
            g = Users.GetGroupByName(new_defaultgroup, new_type)
            g = Users.GetGroupByName(new_defaultgroup, "") if g == {}
            gid = GetInt(Ops.get(g, "gidNumber"), gid)
          end

          # check the homedirectory
          if home != new_home || what == "add_user"
            error2 = Users.CheckHome(new_home)
            if error2 != ""
              Report.Error(error2)
              focus_tab.call(current, :home)
              next
            end
            if new_home.empty?
              Report.Error(_("Home cannot be empty."))
              UI.ChangeWidget(Id(:home), :Value, home)
              focus_tab.call(current, :home)
              next
            end
            failed = false
            begin
              error_map = Users.CheckHomeUI(new_i_uid, new_home, ui_map)
              if error_map != {}
                if Ops.get_string(error_map, "question_id", "") == "chown" &&
                    !Builtins.haskey(error_map, "owned")
                  ret2 = ask_chown_home(new_home, chown_home)
                  if Ops.get_boolean(ret2, "retval", false)
                    Ops.set(ui_map, "chown", new_home)
                    chown_home = Ops.get_boolean(ret2, "chown_home", chown_home)
                  else
                    failed = true
                  end
                else
                  if !Popup.YesNo(Ops.get_string(error_map, "question", ""))
                    failed = true
                  else
                    Ops.set(
                      ui_map,
                      Ops.get_string(error_map, "question_id", ""),
                      new_home
                    )
                  end
                end
              end
            end while error_map != {} && !failed

            if failed
              focus_tab.call(current, :home)
              next
            end
          end

          error_map = Users.CheckShellUI(new_shell, ui_map)
          if error_map != {}
            if !Popup.YesNo(Ops.get_string(error_map, "question", ""))
              focus_tab.call(current, :shell)
              next
            else
              Ops.set(
                ui_map,
                Ops.get_string(error_map, "question_id", ""),
                new_shell
              )
            end
          end

          # generate new map of groups (NIS groups were not shown!)
          new_groups = Builtins.listmap(
            Convert.convert(
              UI.QueryWidget(Id(:grouplist), :SelectedItems),
              :from => "any",
              :to   => "list <string>"
            )
          ) { |g| { g => 1 } }
          if new_type == "ldap"
            Builtins.foreach(
              Convert.convert(
                UI.QueryWidget(Id(:ldapgrouplist), :SelectedItems),
                :from => "any",
                :to   => "list <string>"
              )
            ) { |group| new_groups = Builtins.add(new_groups, group, 1) }
          end
          # now add NIS groups again (were not shown in dialog)
          Builtins.foreach(nis_groups) do |group, val|
            if !Builtins.haskey(new_groups, group)
              new_groups = Builtins.add(new_groups, group, 1)
            end
          end
          # TODO remove from local g. when there is nis g. with same name
          if do_not_edit && !grouplist_modified && groups != new_groups
            grouplist_modified = true
          end
          if new_home == "/var/lib/nobody"
            create_home = false
            chown_home = false
          end
          if UI.WidgetExists(Id(:move_home)) &&
              UI.QueryWidget(Id(:move_home), :Value) == false
            create_home = false
          end

          # A flag to decide if the Btrfs path validation should be performed, since it is not
          # needed when moving it to other location. The "create_home" above is not reliable because
          # it is "true" **when moving the directory/subvolume**.
          check_btrfs_path = !UI.QueryWidget(Id(:move_home), :Value)

          # Check if is a valid path when creating a Btfs subvolume
          if perform_btrfs_validations? && !valid_btrfs_path?(new_home)
            Report.Error(
              # TRANSLATORS: the error message when user try to create a Btrfs subvolume in a not
              # valid location
              _("Given path is not a valid Btrfs location.\n\n" \
              "Choose another path for the home directory\n" \
              "or uncheck the '%{btrfs_option}' option.") % { btrfs_option: btrfs_label }
            )
            focus_tab.call(current, :home)
            next
          end

          home = new_home
          shell = new_shell
          uid = new_i_uid
          groups = deep_copy(new_groups)
          defaultgroup = new_defaultgroup
          user_type = new_type
          Ops.set(user, "homeDirectory", new_home)
          Ops.set(user, "loginShell", new_shell)
          Ops.set(user, "gidNumber", gid)
          Ops.set(user, "uidNumber", new_i_uid)
          Ops.set(user, "grouplist", new_groups)
          Ops.set(user, "groupname", new_defaultgroup)
          Ops.set(user, "type", new_type)
          Ops.set(user, "create_home", create_home)
          Ops.set(user, "chown_home", chown_home)
          Ops.set(user, "addit_data", addit_data)
          Ops.set(user, "no_skeleton", no_skel)
          Ops.set(user, "home_mode", mode)
          Ops.set(user, "btrfs_subvolume", btrfs_subvolume)
        end

        if current == :passwordsettings && (ret == :next || tab)
          exp = Convert.to_string(UI.QueryWidget(Id("shadowExpire"), :Value))
          if exp != "" &&
              !Builtins.regexpmatch(
                exp,
                "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]"
              )
            # popup text: Don't reorder the letters YYYY-MM-DD!!!
            # The date must stay in this format
            Popup.Message(
              _("The expiration date must be in the format YYYY-MM-DD.")
            )
            focus_tab.call(current, "shadowExpire")
            next
          end

          Builtins.foreach(
            ["shadowWarning", "shadowMax", "shadowMin", "shadowInactive"]
          ) do |shadowsymbol|
            if Ops.get(user, shadowsymbol) !=
                UI.QueryWidget(Id(shadowsymbol), :Value)
              Ops.set(
                user,
                shadowsymbol,
                Builtins.sformat("%1", UI.QueryWidget(Id(shadowsymbol), :Value))
              )
            end
          end

          new_exp_date = Convert.to_string(
            UI.QueryWidget(Id("shadowExpire"), :Value)
          )
          if new_exp_date != exp_date
            exp_date = new_exp_date
            if exp_date == ""
              user["shadowExpire"] = ""
            else
              out = SCR.Execute(
                path(".target.bash_output"),
                "/usr/bin/date --date=#{exp_date.shellescape}' UTC' +%s"
              )
              seconds_s = Builtins.deletechars(
                Ops.get_string(out, "stdout", "0"),
                "\n"
              )
              if seconds_s != ""
                days = Ops.divide(Builtins.tointeger(seconds_s), 60 * 60 * 24)
                Ops.set(user, "shadowExpire", Builtins.sformat("%1", days))
              end
            end
          end
          if UI.QueryWidget(Id(:force_pw), :Value) == true
            # force password change
            Ops.set(user, "shadowLastChange", "0")
          end
        end

        if current == :authorized_keys
          handle_authorized_keys_input(ret, user)
        end

        # inside plugins dialog
        if current == :plugins
          plugin_client = Convert.to_string(
            UI.QueryWidget(Id(:table), :CurrentItem)
          )
          if plugin_client != nil
            plugin = Ops.get_string(client2plugin, plugin_client, plugin_client)
          end

          if ret == :table || ret == :change
            ret = Builtins.contains(Ops.get_list(user, "plugins", []), plugin) ? :del : :add
          end
          if ret == :del
            out = UsersPlugins.Apply(
              "PluginRemovable",
              { "what" => "user", "type" => user_type, "plugins" => [plugin] },
              {}
            )
            # check if plugin _could_ be deleted!
            if Builtins.haskey(out, plugin) &&
                !Ops.get_boolean(out, plugin, false)
              # popup message
              Popup.Message(_("This plug-in cannot be removed."))
              ret = :not_next
              next
            end
          end
          if ret == :add || ret == :del || ret == :run
            # functions for adding/deleting/launching plugin work on
            # Users::user_in_work, so we must update it before
            if what == "edit_user"
              Users.EditUser(user)
            else
              Users.AddUser(user)
            end
          end
          if ret == :add
            error = Users.AddUserPlugin(plugin)
            if error != ""
              Popup.Error(error)
              ret = :notnext
              next
            end
            user = Users.GetCurrentUser
            reinit_userdata.call
            UI.ChangeWidget(
              Id(:table),
              term(:Item, plugin_client, 0),
              UI.Glyph(:CheckMark)
            )
          end
          if ret == :del
            error = Users.RemoveUserPlugin(plugin)
            if error != ""
              Popup.Error(error)
              ret = :notnext
              next
            end
            user = Users.GetCurrentUser
            reinit_userdata.call
            UI.ChangeWidget(Id(:table), term(:Item, plugin_client, 0), " ")
          end
          if ret == :run
            plugin_added = false
            # first, add the plugin if necessary
            if !Builtins.contains(Ops.get_list(user, "plugins", []), plugin)
              error = Users.AddUserPlugin(plugin)
              if error != ""
                Popup.Error(error)
                ret = :notnext
                next
              end
              plugin_added = true
              user = Users.GetCurrentUser
              reinit_userdata.call
            end
            plugin_ret = WFM.CallFunction(
              plugin_client,
              ["Dialog", { "what" => "user" }, user]
            )
            if plugin_ret == :next
              # update the map of changed user
              user = Users.GetCurrentUser
              reinit_userdata.call
              UI.ChangeWidget(
                Id(:table),
                term(:Item, plugin_client, 0),
                UI.Glyph(:CheckMark)
              )
            # for `cancel we must remove the plugin if it was added because of `run
            elsif plugin_added
              error = Users.RemoveUserPlugin(plugin)
              if error != ""
                Popup.Error(error)
                ret = :notnext
                next
              end
              user = Users.GetCurrentUser
              reinit_userdata.call
            end
          end
        end

        # ------------------- now handle switching between the tabs
        if ret == :edit
          Wizard.SetHelpText(EditUserDialogHelp(installation, user_type, what))
          UI.ReplaceWidget(:tabContents, get_edit_term.call)

          # update the contents of User Data Dialog
          if do_not_edit
            UI.ChangeWidget(Id(:cn), :Enabled, false)
            UI.ChangeWidget(Id(:username), :Enabled, false)
            UI.ChangeWidget(Id(:pw1), :Enabled, false)
            UI.ChangeWidget(Id(:pw2), :Enabled, false)
          end
          if what == "add_user"
            if user_type == "ldap"
              UI.SetFocus(Id(:givenname))
            else
              UI.SetFocus(Id(:cn))
            end
          end
          if password != nil || what == "edit_user"
            UI.ChangeWidget(Id(:pw1), :Value, @default_pw)
            UI.ChangeWidget(Id(:pw2), :Value, @default_pw)
          end
          if complex_layout && !Autologin.available
            UI.ChangeWidget(Id(:autologin), :Enabled, false)
            UI.ChangeWidget(Id(:autologin), :Value, false)
          end

          # LDAP users can be disabled only with certain plugins (bnc#557714)
          if UI.WidgetExists(Id(:ena)) && user_type == "ldap"
            ena = Builtins.contains(
              Ops.get_list(user, "plugins", []),
              "UsersPluginLDAPShadowAccount"
            ) ||
              Builtins.contains(
                Ops.get_list(user, "plugins", []),
                "UsersPluginLDAPPasswordPolicy"
              )
            UI.ChangeWidget(Id(:ena), :Enabled, ena)
          end

          current = ret
        end
        if ret == :details
          UI.ReplaceWidget(:tabContents, get_details_term.call)
          Wizard.SetHelpText(EditUserDetailsDialogHelp(user_type, what))

          UI.ChangeWidget(Id(:btrfs_subvolume), :Enabled, Mode.config || btrfs_available?)
          if what == "edit_user"
            if user["org_user"] && !Mode.config
              # User has already been created in the installed system. So btrfs_subvolume cannot be changed
              UI.ChangeWidget(Id(:btrfs_subvolume), :Enabled, false)
              # Show the value for the current home directory/subvolume
              UI.ChangeWidget(Id(:btrfs_subvolume), :Value, btrfs_subvolume?(org_home))
            else
              UI.ChangeWidget(Id(:btrfs_subvolume), :Value, user["btrfs_subvolume"])
            end
          end

          if do_not_edit
            [:uid, :home, :move_home, :shell, :defaultgroup, :browse, :btrfs_subvolume].each do |widget|
              UI.ChangeWidget(Id(widget), :Enabled, false)
            end
          end
          if user_type == "ldap" && !Ldap.file_server
            UI.ChangeWidget(Id(:browse), :Enabled, false)
            if UI.WidgetExists(Id(:move_home))
              UI.ChangeWidget(Id(:move_home), :Enabled, false)
            end
          end
          if !FileUtils.Exists(home) && UI.WidgetExists(Id(:move_home))
            UI.ChangeWidget(Id(:move_home), :Enabled, false)
          end
          if UI.WidgetExists(Id(:mode))
            UI.ChangeWidget(Id(:mode), :ValidChars, "01234567")
            UI.ChangeWidget(Id(:mode), :InputMaxLength, 3)
          end
          UI.ChangeWidget(Id(:shell), :Value, shell)

          current = ret
        end
        if ret == :passwordsettings
          # get_password_term may modify exp_date!
          UI.ReplaceWidget(:tabContents, get_password_term(user, exp_date))
          if GetString(Ops.get(user, "shadowLastChange"), "0") == "0"
            # forcing password change cannot be undone
            UI.ChangeWidget(Id(:force_pw), :Enabled, false)
          end
          Wizard.SetHelpText(EditUserPasswordDialogHelp())
          current = ret
        end
        if ret == :authorized_keys
          display_authorized_keys_tab(user)
          Wizard.SetHelpText(EditAuthorizedKeysDialogHelp())
          current = ret
        end
        if ret == :plugins
          UI.ReplaceWidget(:tabContents, get_plugins_term.call)
          Wizard.SetHelpText(PluginDialogHelp())
          UI.ChangeWidget(Id(:table), :CurrentItem, plugin_client)
          current = ret
        end

        if (ret == :next || ret == :additional) &&
            # for do_not_edit, there may be a change in groups (Details dialog)
            (!do_not_edit || grouplist_modified)
          # --------------------------------- final check
          error = Users.CheckUser(user)
          if error != ""
            Report.Error(error)
            ret = :notnext
            next
          end

          # --------------------------------- save the settings
          if Builtins.haskey(user, "check_error")
            user = Builtins.remove(user, "check_error")
          end
          if what == "edit_user"
            error_msg = Users.EditUser(user)
          else
            error_msg = Users.AddUser(user)
          end
          if error_msg != ""
            Report.Error(error_msg)
            ret = :notnext
            next
          end
          # check if autologin is not set for some user
          if what == "add_user" && !complex_layout &&
              # ask only when there is still one user (bnc#332729)
              Builtins.size(UsersCache.GetUsernames("local")) == 1
            Autologin.AskForDisabling(
              # popup text
              _("Now you have added a new user.")
            )
          end
          if root_mail_checked
            Users.RemoveRootAlias(org_username) if username != org_username
            Users.AddRootAlias(username)
          elsif root_mail # not checked now, but checked before
            if username != org_username
              Users.RemoveRootAlias(org_username)
            else
              Users.RemoveRootAlias(username)
            end
          end
          if username == "root"
            Users.SaveRootPassword(false)
          elsif root_pw
            # set root's password
            Users.SetRootPassword(password)
            Users.SaveRootPassword(true)
          end
        end

        if Builtins.contains(
            [:next, :abort, :back, :cancel, :additional, :nosave],
            ret
          )
          break
        end
      end

      if ret == :additional || ret == :nosave
        # during installation, store the data of first user
        # (to show it when clicking `back from Summary dialog)
        Users.SaveCurrentUser
        Users.SetStartDialog("users")
      end
      ret
    end

    def move_to_new_location_checkbox(action, checked)
      return Empty() if action != "edited"

      HBox(
        HSpacing(),
        Left(
          CheckBox(Id(:move_home), _("&Move to New Location"), checked)
        )
      )
    end

    def btrfs_label
      # TRANSLATORS: label for the checkbox that allows to create the user home directory as a
      # Btrfs subvolume
      _("Create as Btrfs Subvolume")
    end

    # Returns clean path
    #
    # Also useful to remove the trailing backslash
    #
    # @param [String] path
    #
    # @return [String] a string path representation or empty string
    def cleanpath(path)
      return "" if path.nil? || path.empty?

      Pathname.new(path).cleanpath.to_s
    rescue TypeError
      ""
    end

    # Check if given path is in a btrfs filesystem
    #
    # @param [String, Pathname] path
    #
    # @return [Boolean] true when is a path in a Btrfs filesystem; false otherwise
    def valid_btrfs_path?(path)
      dirname = Pathname.new(path).dirname
      fstype = Yast::Execute.locally!.stdout("/usr/bin/stat", "-f", "--format", "%T", dirname).chomp

      fstype == "btrfs"
    end

    # Determine if is necessary to check the home path as a valid Btrfs location
    #
    # @return [false] if running in AutoYaST configuration mode
    # @return [false] if the home directory is being moved
    # @return [Boolean] true when the btrfs_subvolume option is present and selected; false otherwise
    def perform_btrfs_validations?
      return false if Mode.config
      return false if UI.QueryWidget(Id(:move_home), :Value)

      UI.QueryWidget(Id(:btrfs_subvolume), :Value)
    end

    # Whether there is a Btrfs filesystem present
    #
    # @return [Boolean] true if a Btrfs filesystem is found; false otherwise
    def btrfs_available?
      available_filesystems = Yast::Execute.locally!.stdout(
        ["/usr/bin/df", "--output=fstype"],
        ["/usr/bin/tail", "-n", "+2"]
      ).split("\n")

      available_filesystems.include?("btrfs")
    end

    # Whether given path is a Btrfs subvolume
    #
    # @param [String, Pathname] path
    #
    # @return [Boolean] true when is a Btrfs subvolume; false otherwise
    def btrfs_subvolume?(path)
      return false if path.to_s.empty?

      !Yast::Execute.locally!.stdout("/usr/sbin/btrfs", "subvolume", "show", path).empty?
    end

    # Dialog for adding/editing group
    # @param [String] what "add_group" or "edit_group"
    # @return [Symbol] for wizard sequencer
    def EditGroupDialog(what)
      # create a local copy of current group
      group = Users.GetCurrentGroup
      groupname = Ops.get_string(group, "cn", "")
      gid = GetInt(Ops.get(group, "gidNumber"), -1)
      # these are the users with this group as a default:
      more_users = Ops.get_map(group, "more_users", {})
      # these are users from /etc/group:
      userlist = Ops.get_map(group, "userlist", {})
      group_type = Ops.get_string(group, "type", "")
      new_type = group_type
      additional_users = []
      member_attribute = UsersLDAP.GetMemberAttribute

      if group_type == "ldap"
        userlist = Ops.get_map(group, member_attribute, {})
      end

      more = Ops.greater_than(Builtins.size(more_users), 0)

      dialog_labels = {
        "add_group"  => {
          # dialog caption:
          "local"  => _("New Local Group"),
          # dialog caption:
          "system" => _("New System Group"),
          # dialog caption:
          "ldap"   => _("New LDAP Group")
        },
        "edit_group" => {
          # dialog caption:
          "local"  => _("Existing Local Group"),
          # dialog caption:
          "system" => _("Existing System Group"),
          # dialog caption:
          "ldap"   => _("Existing LDAP Group")
        }
      }

      plugin_client = ""
      plugin = ""
      client2plugin = {}
      clients = []

      # initialize local variables with current state of group
      reinit_groupdata = lambda do
        groupname = Ops.get_string(group, "cn", groupname)
        gid = GetInt(Ops.get(group, "gidNumber"), gid)
        more_users = Convert.convert(
          Ops.get(group, "more_users", more_users),
          :from => "any",
          :to   => "map <string, any>"
        )
        userlist = Convert.convert(
          Ops.get(group, "userlist", userlist),
          :from => "any",
          :to   => "map <string, any>"
        )
        group_type = Ops.get_string(group, "type", group_type)
        if group_type == "ldap"
          userlist = Ops.get_map(group, member_attribute, {})
        end

        nil
      end

      # generate contents for Group Data Dialog
      get_edit_term = lambda do
        i = 0
        more_users_items = []
        Builtins.foreach(more_users) do |u, val|
          if Ops.less_than(i, 42)
            more_users_items = Builtins.add(
              more_users_items,
              Item(Id(u), u, true)
            )
          end
          if i == 42
            more_users_items = Builtins.add(
              more_users_items,
              Item(Id("-"), "...", false)
            )
          end
          i = Ops.add(i, 1)
        end

        HBox(
          HWeight(
            1,
            VBox(
              VSpacing(1),
              Top(
                InputField(
                  Id(:groupname),
                  Opt(:hstretch),
                  # textentry label
                  _("Group &Name"),
                  groupname
                )
              ),
              Top(
                InputField(
                  Id(:gid),
                  Opt(:hstretch),
                  # textentry label
                  _("Group &ID (gid)"),
                  Builtins.sformat("%1", gid)
                )
              ),
              VSpacing(1)
            )
          ),
          HSpacing(2),
          HWeight(
            1,
            VBox(
              VSpacing(1),
              ReplacePoint(
                Id(:rpuserlist),
                # selection box label
                MultiSelectionBox(Id(:userlist), _("Group &Members"), [])
              ),
              more ? VSpacing(1) : VSpacing(0),
              more ?
                MultiSelectionBox(Id(:more_users), "", more_users_items) :
                VSpacing(0),
              VSpacing(1)
            )
          )
        )
      end

      # generate contents for Plugins Dialog
      get_plugins_term = lambda do
        plugin_client = Ops.get(clients, 0, "")
        plugin = Ops.get_string(client2plugin, plugin_client, plugin_client)

        items = []
        Builtins.foreach(clients) do |cl|
          summary = WFM.CallFunction(cl, ["Summary", { "what" => "group" }])
          pl = Ops.get_string(client2plugin, cl, cl)
          if Ops.is_string?(summary)
            items = Builtins.add(
              items,
              Item(
                Id(cl),
                Builtins.contains(Ops.get_list(group, "plugins", []), pl) ?
                  UI.Glyph(:CheckMark) :
                  " ",
                summary
              )
            )
          end
        end
        HBox(
          HSpacing(0.5),
          VBox(
            Table(
              Id(:table),
              Opt(:notify),
              Header(
                " ",
                # table header
                _("Plug-In Description")
              ),
              items
            ),
            HBox(
              PushButton(
                Id(:change),
                Opt(:key_F3),
                # pushbutton label
                _("Add or &Remove Plug-In")
              ),
              # pushbutton label
              Right(PushButton(Id(:run), Opt(:key_F6), _("&Launch")))
            ),
            VSpacing(0.5)
          ),
          HSpacing(0.5)
        )
      end

      tabs = []
      dialog_contents = Empty()

      # Now initialize the list of plugins: we must know now if there is some available.
      # UsersPlugins will filter out plugins we cannot use for given type
      plugin_clients = UsersPlugins.Apply(
        "GUIClient",
        { "what" => "group", "type" => group_type },
        {}
      )
      # remove empty clients
      plugin_clients = Builtins.filter(
        Convert.convert(
          plugin_clients,
          :from => "map",
          :to   => "map <string, string>"
        )
      ) { |plugin2, client| client != "" }
      clients = Builtins.maplist(
        Convert.convert(
          plugin_clients,
          :from => "map",
          :to   => "map <string, string>"
        )
      ) do |plugin2, client|
        Ops.set(client2plugin, client, plugin2)
        client
      end
      use_tabs = Ops.greater_than(Builtins.size(clients), 0)
      has_tabs = true

      if use_tabs
        tabs = [
          # tab label
          Item(Id(:edit), _("Group &Data"), true),
          # tab label
          Item(Id(:plugins), _("Plu&g-Ins"))
        ]

        dialog_contents = VBox(
          DumbTab(
            Id(:tabs),
            tabs,
            ReplacePoint(Id(:tabContents), get_edit_term.call)
          )
        )
        if !UI.HasSpecialWidget(:DumbTab)
          has_tabs = false
          tabbar = HBox()
          Builtins.foreach(tabs) do |it|
            label = Ops.get_string(it, 1, "")
            tabbar = Builtins.add(
              tabbar,
              PushButton(Ops.get_term(it, 0) { Id(label) }, label)
            )
          end
          dialog_contents = VBox(
            Left(tabbar),
            Frame("", ReplacePoint(Id(:tabContents), get_edit_term.call))
          )
        end
      else
        dialog_contents = get_edit_term.call
      end

      Wizard.SetContentsButtons(
        Ops.get_string(dialog_labels, [what, group_type], ""),
        dialog_contents,
        EditGroupDialogHelp(more),
        Label.CancelButton,
        Label.OKButton
      )
      Wizard.HideAbortButton

      ret = :edit
      current = nil
      tabids = [:edit, :plugins]

      # switch focus to specified tab (after error message) and widget inside
      focus_tab = lambda do |tab, widget|
        widget = deep_copy(widget)
        UI.ChangeWidget(Id(:tabs), :CurrentItem, tab) if use_tabs && has_tabs
        UI.SetFocus(Id(widget))
        ret = :notnext

        nil
      end
      begin
        # map returned from Check*UI functions
        error_map = {}
        # map with id's of confirmed questions
        ui_map = {}
        # error message
        error = ""

        ret = Convert.to_symbol(UI.UserInput) if current != nil

        if (ret == :abort || ret == :cancel) && ReallyAbort() != :abort
          ret = :notnext
          next
        end
        break if Builtins.contains([:abort, :back, :cancel], ret)

        tab = Builtins.contains(tabids, ret)
        next if tab && ret == current

        # 1. click inside Group Data dialog or moving outside of it
        if current == :edit && (ret == :next || tab)
          new_gid = Convert.to_string(UI.QueryWidget(Id(:gid), :Value))
          new_i_gid = Builtins.tointeger(new_gid)
          new_groupname = Convert.to_string(
            UI.QueryWidget(Id(:groupname), :Value)
          )

          # --------------------------------- groupname checks
          error2 = Users.CheckGroupname(new_groupname)
          if error2 != ""
            Report.Error(error2)
            focus_tab.call(current, :groupname)
            next
          end

          # --------------------------------- gid checks
          if new_i_gid != gid
            error2 = Users.CheckGID(new_i_gid)
            if error2 != ""
              Report.Error(error2)
              focus_tab.call(current, :gid)
              next
            end
            failed = false
            begin
              error_map = Users.CheckGIDUI(new_i_gid, ui_map)
              if error_map != {}
                if !Popup.YesNo(Ops.get_string(error_map, "question", ""))
                  failed = true
                else
                  Ops.set(
                    ui_map,
                    Ops.get_string(error_map, "question_id", ""),
                    new_i_gid
                  )
                  if Builtins.contains(
                      ["local", "system"],
                      Ops.get_string(error_map, "question_id", "")
                    )
                    new_type = Ops.get_string(error_map, "question_id", "local")
                    UsersCache.SetGroupType(new_type)
                  end
                end
              end
            end while error_map != {} && !failed
            if failed
              focus_tab.call(current, :gid)
              next
            end
          end

          # --------------------------------- update userlist
          new_userlist = Builtins.listmap(
            Convert.convert(
              UI.QueryWidget(Id(:userlist), :SelectedItems),
              :from => "any",
              :to   => "list <string>"
            )
          ) { |user| { user => 1 } }

          # --------------------------------- now everything should be OK
          Ops.set(group, "cn", new_groupname)
          Ops.set(group, "more_users", more_users)
          Ops.set(group, "gidNumber", new_i_gid)
          Ops.set(group, "type", new_type)
          if group_type == "ldap"
            Ops.set(group, member_attribute, new_userlist)
          else
            Ops.set(group, "userlist", new_userlist)
          end
          reinit_groupdata.call
        end

        # inside plugins dialog
        if current == :plugins
          plugin_client = Convert.to_string(
            UI.QueryWidget(Id(:table), :CurrentItem)
          )
          if plugin_client != nil
            plugin = Ops.get_string(client2plugin, plugin_client, plugin_client)
          end
          if ret == :table || ret == :change
            ret = Builtins.contains(Ops.get_list(group, "plugins", []), plugin) ? :del : :add
          end
          if ret == :del
            out = UsersPlugins.Apply(
              "PluginRemovable",
              { "what" => "group", "type" => group_type, "plugins" => [plugin] },
              {}
            )
            # check if plugin _could_ be deleted!
            if Builtins.haskey(out, plugin) &&
                !Ops.get_boolean(out, plugin, false)
              # popup message
              Popup.Message(_("This plug-in cannot be removed."))
              ret = :not_next
              next
            end
          end
          if ret == :add || ret == :del || ret == :run
            # functions for adding/deleting/launching plugin work on
            # Users::group_in_work, so we must update it before
            if what == "edit_group"
              Users.EditGroup(group)
            else
              Users.AddGroup(group)
            end
          end
          if ret == :add
            error = Users.AddGroupPlugin(plugin)
            if error != ""
              Popup.Error(error)
              ret = :notnext
              next
            end
            group = Users.GetCurrentGroup
            reinit_groupdata.call
            UI.ChangeWidget(
              Id(:table),
              term(:Item, plugin_client, 0),
              UI.Glyph(:CheckMark)
            )
          end
          if ret == :del
            error = Users.RemoveGroupPlugin(plugin)
            if error != ""
              Popup.Error(error)
              ret = :notnext
              next
            end
            group = Users.GetCurrentGroup
            reinit_groupdata.call
            UI.ChangeWidget(Id(:table), term(:Item, plugin_client, 0), " ")
          end
          if ret == :run
            plugin_added = false
            # first, add the plugin if necessary
            if !Builtins.contains(Ops.get_list(group, "plugins", []), plugin)
              error = Users.AddGroupPlugin(plugin)
              if error != ""
                Popup.Error(error)
                ret = :notnext
                next
              end
              plugin_added = true
              group = Users.GetCurrentGroup
              reinit_groupdata.call
            end
            plugin_ret = WFM.CallFunction(
              plugin_client,
              ["Dialog", { "what" => "group" }, group]
            )
            if plugin_ret == :next
              # update the map of changed group
              group = Users.GetCurrentGroup
              reinit_groupdata.call
              UI.ChangeWidget(
                Id(:table),
                term(:Item, plugin_client, 0),
                UI.Glyph(:CheckMark)
              )
            elsif plugin_added
              error = Users.RemoveGroupPlugin(plugin)
              if error != ""
                Popup.Error(error)
                ret = :notnext
                next
              end
              group = Users.GetCurrentGroup
              reinit_groupdata.call
            end
          end
        end

        # initialize Edit Group tab
        if ret == :edit
          if use_tabs
            Wizard.SetHelpText(EditGroupDialogHelp(more))
            UI.ReplaceWidget(:tabContents, get_edit_term.call)
          end

          UI.SetFocus(Id(:groupname)) if what == "add_group"

          if more
            # set of users having this group as default - cannot be edited!
            UI.ChangeWidget(Id(:more_users), :Enabled, false)
          end
          additional_users = UsersCache.BuildAdditional(group)

          # add items later (when there is a huge amount of them, it takes
          # long time to display, so display at least the rest of the dialog)
          if Ops.greater_than(Builtins.size(additional_users), 0)
            UI.ReplaceWidget(
              Id(:rpuserlist),
              MultiSelectionBox(
                Id(:userlist),
                _("Group &Members"),
                additional_users
              )
            )
          end
          current = ret
        end

        if ret == :plugins
          UI.ReplaceWidget(:tabContents, get_plugins_term.call)
          Wizard.SetHelpText(PluginDialogHelp())
          UI.ChangeWidget(Id(:table), :CurrentItem, plugin_client)
          current = ret
        end

        # save the changes
        if ret == :next
          error = Users.CheckGroup(group)
          if error != ""
            Report.Error(error)
            ret = :notnext
            next
          end
          if what == "edit_group"
            error = Users.EditGroup(group)
          else
            error = Users.AddGroup(group)
          end
          if error != ""
            Report.Error(error)
            ret = :notnext
            next
          end
        end
      end until Builtins.contains([:next, :abort, :back, :cancel], ret)
      ret
    end

    # Just giving paramaters for committing user
    # @return [Symbol] for wizard sequencer
    def UserSave
      Users.CommitUser
      # adding only one user during install
      if installation && Users.StartDialog("user_add")
        return :save
      else
        return :next
      end
    end

    # Check the group parameters and commit it if all is OK
    # @return [Symbol] for wizard sequencer
    def GroupSave
      group = Users.GetCurrentGroup
      # do not check group which should be deleted
      if Ops.get_string(group, "what", "") != "delete_group"
        error = Users.CheckGroup(group)
        if error != ""
          Report.Error(error)
          return :back
        end
      end
      Users.CommitGroup
      :next
    end

    # Handles authorized keys list events
    #
    # @param action [Symbol] Action to handle (:add_authorized_key and :remove_authorized_key)
    # @param user   [Hash] User to update
    def handle_authorized_keys_input(action, user)
      case action
      when :add_authorized_key
        add_authorized_key(user)
      when :remove_authorized_key
        remove_authorized_key(user)
      end
    end

    # Adds an authorized key to the list
    #
    # @note This method drives the UI and handles error conditions
    #
    # @param user [Hash] User to update
    def add_authorized_key(user)
      key = read_public_key
      return if key.nil?
      if user.fetch("authorized_keys", []).include?(key.to_s)
        # TRANSLATORS: this error happens when the selected public key is a duplicated
        # (already present in the list of public keys)
        Yast2::Popup.show(
          _("The selected public key is already present in the list."), headline: :error
        )
        return
      end

      user["authorized_keys"] ||= []
      user["authorized_keys"] << key.to_s
      display_authorized_keys_tab(user)
    end

    # Asks for the path and retrieves the public key
    def read_public_key
      # TRANSLATORS: title of the dialog to select a public key to be used when logging
      # via SSH
      path = Yast::UI.AskForExistingFile("", "*.pub", _("Select a public key"))
      return if path.nil?
      Y2Users::SSHPublicKey.new(File.read(path))
    rescue Y2Users::SSHPublicKey::InvalidKey
      # TRANSLATORS: this error happens when the file selected by the user is not a valid public
      # key
      Yast2::Popup.show(
        _("The selected file does not contain a valid public key"), headline: :error
      )
    rescue Errno::ENOENT
      # TRANSLATORS: this error happens when the user selected a file that has just been removed
      # (the file selector may contain outdated information)
      Yast2::Popup.show(
        _("Could not read the file containing the public key"), headline: :error
      )
    end

    # Removes the selected key from the list
    #
    # @param user [Hash] User to update
    def remove_authorized_key(user)
      selected_row = UI.QueryWidget(Id(:authorized_keys_table), :CurrentItem)
      user["authorized_keys"].delete_at(selected_row)

      rows_qty = UI.QueryWidget(Id(:authorized_keys_table), :Items).size - 1
      next_selected_row = selected_row == rows_qty ? selected_row - 1 : selected_row
      display_authorized_keys_tab(user, next_selected_row)
    end

    # Displays the authorized keys tab
    #
    # @param user         [Hash] User to update
    # @param selected_row [Integer] Current selected row
    def display_authorized_keys_tab(user, selected_row = nil)
      UI.ReplaceWidget(:tabContents, get_authorized_keys_term(user))
      UI.SetFocus(Id(:authorized_keys_table))
      UI.ChangeWidget(Id(:authorized_keys_table), :CurrentItem, selected_row) if selected_row
      key_present = !user.fetch("authorized_keys", []).empty?
      UI.ChangeWidget(Id(:remove_authorized_key), :Enabled, key_present)
    end


    # Generates content for the authorized keys tab
    #
    # @param user [Hash] User to get the list of authorized keys
    def get_authorized_keys_term(user)
      items = user.fetch("authorized_keys", []).each_with_index.map do |content, idx|
        key = Y2Users::SSHPublicKey.new(content)
        Item(Id(idx), key.formatted_fingerprint, key.comment)
      end

      VBox(
        Table(
          Id(:authorized_keys_table),
          Opt(:notify),
          Header(
            # TRANSLATORS: this fingerprint is a hash that can be used to identify a public key
            # (and it is usually a long string containing letters, numbers and other symbols)
            _("Fingerprint"),
            # TRANSLATORS: as fingerprint is hard to remember or identify for a user, a public
            # key can include a comment to make things easier
            _("Comment")
          ),
          items
        ),
        HBox(
          # TRANSLATORS: a push button label
          PushButton(Id(:add_authorized_key), _("&Add...")),
          PushButton(Id(:remove_authorized_key), Yast::Label.RemoveButton),
          HStretch()
        )
      )
    end
  end
end
