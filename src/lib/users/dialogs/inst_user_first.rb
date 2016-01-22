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

# File:	clients/inst_user_first.ycp
# Package:	Configuration of users and groups
# Summary:	Dialog for creating the first user during installation
# Authors:     Jiri Suchomel <jsuchome@suse.cz>
#
# $Id$
require "yast"
require "ui/event_dispatcher"
require "users/dialogs/users_to_import"
require "users/ca_password_validator"
require "users/local_password"

module Yast
  class InstUserFirstDialog
    include ::UI::EventDispatcher
    include Yast::I18n
    include Yast::UIShortcuts

    def run
      create_dialog
      begin
        event_loop
      ensure
        close_dialog
      end
    end

    def initialize
      import_yast_modules
      textdomain "users"

      @text_mode = UI.TextMode

      # Widgets to enable/disable depending on the selected action
      # (the first one receives the initial focus if applicable)
      @widgets = {
        new_user: [:full_name, :username, :pw1, :pw2, :root_pw, :root_mail, :autologin],
        import: [:choose_users, :import_qty_label],
        skip: []
      }

      # full info about imported users
      @importable_users = {}
      # user names of imported users
      @importable_usernames = []
      # names of imported users selected for writing
      @usernames_to_import = []

      # if importing users from different partition is possible
      @import_available = UsersSimple.ImportAvailable

      if @import_available
        @importable_users = UsersSimple.GetImportedUsers("local")
        @importable_usernames = @importable_users.keys

        if @importable_usernames.empty?
          Builtins.y2milestone("No users to import")
          @import_available = false
        end
      end

      # do not open package progress wizard window
      @progress_orig = Progress.set(false)

      @users = UsersSimple.GetUsers
      @action = case @users.size
      when 0
        # New user is the default option
        GetInstArgs.going_back ? :skip : :new_user
      when 1
        @users.first["__imported"] ? :import : :new_user
      else
        :import
      end

      if action == :import
        @usernames_to_import = @users.map { |u| u["uid"] || "" }
      end
      @usernames_to_import ||= []
      if action == :new_user
        @user = @users.first
      end
      @user ||= {}
      init_user_attributes

      @login_modified = false
    end

    # UI sends events as user types the full name
    def full_name_handler
      # reenable suggestion
      @login_modified = false if UI.QueryWidget(Id(:username), :Value).empty?
      propose_login unless @login_modified
    end

    def username_handler
      @login_modified = true
    end

    def choose_users_handler
      imported = UsersToImportDialog.new(@importable_usernames, @usernames_to_import).run
      return unless imported
      @usernames_to_import = imported
      UI.ReplaceWidget(Id(:import_qty), import_qty_widget)
    end

    # Used from proposal
    def accept_handler
      next_handler
    end

    def next_handler
      if action == :new_user
        return unless process_new_user_form
      elsif action == :import
        return unless process_import_form
      end

      UsersSimple.SetAfterAuth("users")
      UsersSimple.SetKerberosConfiguration(false)

      case action
      when :new_user
        create_new_user
      when :import
        import_users
      when :skip
        clean_users_info
      end
      finish_dialog(:next)
    end

    def cancel_handler
      finish_dialog(:cancel)
    end

    def back_handler
      finish_dialog(:back)
    end

    def abort_handler
      finish_dialog(:abort) if Popup.ConfirmAbort(:painless)
    end

    def skip_handler
      self.action = :skip
    end

    def new_user_handler
      self.action = :new_user
    end

    def import_handler
      self.action = :import
    end

    # help text
    def main_help
      help = _(
        "<p>\nUse one of the available options to add local users to the system.\n" \
        "Local users are stored in <i>/etc/passwd</i> and <i>/etc/shadow</i>.\n</p>\n"
      ) +
        "<p>\n<b>" + _("Create new user") + "</b>\n</p>\n" +
      _(
        "<p>\nEnter the <b>User's Full Name</b>, <b>Username</b>, and <b>Password</b> to\n" +
        "assign to this user account.\n</p>\n") +
      _(
        "<p>\nWhen entering a password, distinguish between uppercase and\n" +
        "lowercase. Passwords should not contain any accented characters or umlauts.\n</p>\n"
      )

      help += (
        # TRANSLATORS: %{min} and %{max} will be replaced by numbers
        _(
          "<p>\nThe password length should be between %{min}\n and %{max} characters.\n</p>\n"
        ) %
        {
          min: UsersSimple.GetMinPasswordLength("local"),
          max: UsersSimple.GetMaxPasswordLength("local")
        }
      ) + UsersSimple.ValidPasswordHelptext

      help += ::Users::CAPasswordValidator.new.help_text

      help += _(
        "<p>\nTo ensure that the password was entered correctly,\n" \
        "repeat it exactly in a second field. Do not forget your password.\n" \
        "</p>\n"
      ) +
      _(
        "<p>\nFor the <b>Username</b> use only letters (no accented characters), digits, and <tt>._-</tt>.\n" \
        "Do not use uppercase letters in this entry unless you know what you are doing.\n" \
        "Usernames have stricter restrictions than passwords. You can redefine the\n" \
        "restrictions in the /etc/login.defs file. Read its man page for information.\n" \
        "</p>\n"
      ) +
      _(
        "<p>Check <b>Use this password for system administrator</b> if the " \
        "same password as entered for the first user should be used for root.</p>"
      ) +
      _(
        "<p>\nThe username and password created here are needed to log in " \
        "and work with your Linux system. With <b>Automatic Login</b> enabled, " \
        "the login procedure is skipped. This user is logged in automatically.</p>\n"
      ) +
      _(
        "<p>\nHave mail for root forwarded to this user by checking <b>Receive System Mail</b>.</p>\n"
      )

      if import_available?
        help += "<p>\n<b>" + _("Import User Data from a Previous Installation") + "</b>\n</p>\n"
        help += _(
          "<p>\nA previous Linux installation with local users has been detected.\n" \
          "The information there can be used to create users in the system being installed.\n" \
          "Use the <b>Choose Users</b> button to select some users. Their basic information will\n" \
          "be imported.\n</p>\n"
        )
      end

      help += "<p>\n<b>" + _("Skip User Creation") + "</b>\n</p>\n"
      help += _(
        "<p>\nSometimes root is the only needed local user, like in network environments\n" \
        "with an authentication server. Select this option to proceed without creating\n" \
        "a local user.\n</p>\n"
      )

      help
    end

  private

    # Imports all the used YaST modules
    #
    # Importing them before class initialization has been observed to
    # be problematic
    def import_yast_modules
      Yast.import "UI"
      Yast.import "GetInstArgs"
      Yast.import "Label"
      Yast.import "Mode"
      Yast.import "Popup"
      Yast.import "ProductFeatures"
      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "UsersSimple"
      Yast.import "Wizard"
    end

    # Initializes the instance variables used to configure a new user
    #
    # Requires @user to be set in advance
    def init_user_attributes
      @user_type = @user.fetch("type", "local")
      @username = @user.fetch("uid", "")
      @full_name = @user.fetch("cn", "")
      @password = @user["userPassword"]

      init_autologin
      init_pw_for_root
      init_root_mail
    end

    # Sets the initial default value for autologin
    # Requires @user to be already set
    def init_autologin
      @autologin = UsersSimple.AutologinUsed
      if @user.empty? && !@autologin
        if ProductFeatures.GetBooleanFeature("globals", "enable_autologin") == true
          @autologin = true
        end
        Builtins.y2debug("autologin default value: %1", @autologin)
      end
    end

    # Sets the initial default value for root pw checkbox
    # Requires @user to be already set
    def init_pw_for_root
      @use_pw_for_root = UsersSimple.GetRootPassword == @password
      if @user == {} && !@use_pw_for_root
        if ProductFeatures.GetBooleanFeature(
            "globals",
            "root_password_as_first_user"
          ) == true
          @use_pw_for_root = true
        end
        Builtins.y2debug("root_pw default value: %1", @use_pw_for_root)
      end
    end

    # Sets the initial value of the flag for the user to get root's mail
    # Requires @username to be already set
    def init_root_mail
      @root_mail = !@username.empty? && UsersSimple.GetRootAlias == @username
    end

    def create_dialog
      Wizard.CreateDialog if Mode.normal # for testing only
      Wizard.SetTitleIcon("yast-users")
      # dialog caption
      Wizard.SetContents(
        _("Local Users"),
        contents,
        main_help,
        GetInstArgs.enable_back,
        GetInstArgs.enable_next || Mode.normal
      )
      refresh
      set_focus
    end

    def close_dialog
      Wizard.CloseDialog if Mode.normal
      Progress.set(@progress_orig)
    end

    # Takes the first word from full name and proposes a login name which is then used
    # to relace the current login name in UI
    def propose_login
      # get the first name
      full_name = UI.QueryWidget(Id(:full_name), :Value)

      login = full_name.strip.split(" ", 2).first || ""
      login = UsersSimple.Transliterate(login).delete("^" + UsersSimple.ValidLognameChars).downcase

      UI.ChangeWidget(Id(:username), :Value, login)
    end

    def refresh
      @widgets.values.flatten.each do |w|
        UI.ChangeWidget(Id(w), :Enabled, @widgets[action].include?(w))
      end
    end

    def set_focus
      widget = @widgets[action].first
      UI.SetFocus(Id(widget)) if widget
    end

    attr_reader :action

    def action=(value)
      @action = value
      refresh
    end

    def process_new_user_form
      # username checks
      @username = UI.QueryWidget(Id(:username), :Value)
      if @username.empty?
        Report.Error(
          # TRANSLATORS: Error popup
          _("The new username cannot be blank.\n" \
            "If you don't want to create a user now, select\n" \
            "'Skip User Creation'.")
        )
        return false
      end

      if !valid_username?(@username)
        UI.SetFocus(Id(:username))
        return false
      end

      # full name checks
      @full_name = UI.QueryWidget(Id(:full_name), :Value)
      error = UsersSimple.CheckFullname(@full_name)
      if !error.empty?
        Report.Error(error)
        UI.SetFocus(Id(:full_name))
        return false
      end

      # password checks
      pw1 = UI.QueryWidget(Id(:pw1), :Value)
      pw2 = UI.QueryWidget(Id(:pw2), :Value)
      @use_pw_for_root = UI.QueryWidget(Id(:root_pw), :Value)

      if !valid_password?(@username, pw1, pw2)
        UI.SetFocus(Id(:pw1))
        return false
      end
      @password = pw1

      return true
    end

    def create_new_user
      # save the first user data
      user_map = {
        "uid"          => @username,
        "userPassword" => @password,
        "cn"           => @full_name
      }
      UsersSimple.SetUsers([user_map])
      UsersSimple.SkipRootPasswordDialog(@use_pw_for_root)
      if root_dialog_follows || @use_pw_for_root
        UsersSimple.SetRootPassword(@use_pw_for_root ? @password : "")
      end

      UsersSimple.SetAutologinUser(
        UI.QueryWidget(Id(:autologin), :Value) == true ? @username : ""
      )
      UsersSimple.SetRootAlias(
        UI.QueryWidget(Id(:root_mail), :Value) == true ? @username : ""
      )
    end

    def process_import_form
      if @usernames_to_import.empty?
        Report.Error(
          # TRANSLATORS: error popup
          _("No users from the previous installation were choosen.\n" \
            "If you don't want to create a user now, select\n" \
            "'Skip User Creation'.")
        )
        return false
      end
      return true
    end

    def import_users
      create_users = []
      @usernames_to_import.each do |name|
        u = @importable_users.fetch(name, {})
        u["__imported"] = true
        u["encrypted"] = true
        create_users << u
      end
      set_users_list(create_users)
    end

    def clean_users_info
      set_users_list([])
    end

    def set_users_list(users)
      UsersSimple.SetUsers(users)
      UsersSimple.SkipRootPasswordDialog(false)
      UsersSimple.SetRootPassword("") if root_dialog_follows
      UsersSimple.SetAutologinUser("")
      UsersSimple.SetRootAlias("")
    end

    def valid_username?(username)
      error = UsersSimple.CheckUsernameLength(username)
      if !error.empty?
        Report.Error(error)
        return false
      end

      error = UsersSimple.CheckUsernameContents(username, "")
      if !error.empty?
        Report.Error(error)
        return false
      end

      error = UsersSimple.CheckUsernameConflicts(username)
      if !error.empty?
        Report.Error(error)
        return false
      end

      return true
    end

    def valid_password?(username, pw1, pw2)
      if pw1 != pw2
        # The two group password information do not match
        # error popup
        Report.Error(_("The passwords do not match.\nTry again."))
        return false
      end

      error = UsersSimple.CheckPassword(pw1, "local")
      if !error.empty?
        Report.Error(error)
        return false
      end

      passwd = Users::LocalPassword.new(username: username, plain: pw1, also_for_root: @use_pw_for_root)
      if !passwd.valid?
        message = passwd.errors.join("\n\n") + "\n\n" + _("Really use this password?")
        if !Popup.YesNo(message)
          return false
        end
      end

      return true
    end

    def contents
      HSquash(
        VBox(
          RadioButtonGroup(
            Id(:action),
            VBox(
              new_user_option,
              import_option,
              skip_option
            )
          )
        )
      )
    end

    def new_user_option
      VBox(
        Left(
          RadioButton(
            Id(:new_user),
            Opt(:notify),
            "Create new user",
            action == :new_user
          )
        ),
        Left(
          HBox(
            HSpacing(5),
            new_user_widget
          )
        ),
        VSpacing(1)
      )
    end

    def import_option
      if import_available?
        VBox(
          Left(
            RadioButton(
              Id(:import),
              Opt(:notify),
              _("Import User Data from a Previous Installation"),
              action == :import
            )
          ),
          Left(
            HBox(
              HSpacing(5),
              ReplacePoint(Id(:import_qty), import_qty_widget),
              HSpacing(1),
              PushButton(Id(:choose_users), _("Choose Users"))
            )
          ),
          VSpacing(1)
        )
      else
        Empty()
      end
    end

    def skip_option
      Left(
        RadioButton(
          Id(:skip),
          Opt(:notify),
          _("Skip User Creation"),
          action == :skip
        )
      )
    end

    def new_user_widget
      VBox(
        *new_user_fields,
        VSpacing(0.2),
        *new_user_options
      )
    end

    def new_user_fields
      [
        InputField(
          Id(:full_name),
          Opt(:notify, :hstretch),
          # text entry
          _("User's &Full Name"),
          @full_name
        ),
        InputField(
          Id(:username),
          Opt(:notify, :hstretch),
          # input field for login name
          _("&Username"),
          @username
        ),
        Password(
          Id(:pw1),
          Opt(:hstretch),
          Label.Password,
          @password == nil ? "" : @password
        ),
        Password(
          Id(:pw2),
          Opt(:hstretch),
          Label.ConfirmPassword,
          @password == nil ? "" : @password
        )
      ]
    end

    def new_user_options
      [
        Left(
          CheckBox(
            Id(:root_pw),
            # checkbox label
            _("U&se this password for system administrator"),
            @use_pw_for_root
          )
        ),
        Left(
          # checkbox label
          CheckBox(Id(:root_mail), _("Receive S&ystem Mail"), @root_mail)
        ),
        # checkbox label
        Left(CheckBox(Id(:autologin), _("&Automatic Login"), @autologin))
      ]
    end

    def import_qty_widget
      qty = @usernames_to_import.size
      if qty == 0
        msg = _("No users selected")
      else
        msg = n_("%d user will be imported", "%d users will be imported", qty)
      end
      Label(Id(:import_qty_label), msg % qty)
    end

    # indication that client was called directly from proposal
    def root_dialog_follows
      @root_dialog_follows ||= GetInstArgs.argmap.fetch("root_dialog_follows", true)
    end

    def import_available?
      !!@import_available
    end
  end
end
