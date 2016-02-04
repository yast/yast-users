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

require "yast"
require "ui/installation_dialog"
require "users/dialogs/users_to_import"
require "users/ca_password_validator"
require "users/local_password"

module Yast
  # Dialog for creation of local users during first stage of installation
  # It stores the user(s) information in the UsersSimple module. The user(s)
  # will then be created by that module during inst_finish
  class InstUserFirstDialog < ::UI::InstallationDialog
    # Widgets to enable/disable depending on the selected action
    # (the first one receives the initial focus if applicable)
    WIDGETS = {
      new_user: [:full_name, :username, :pw1, :pw2, :root_pw, :autologin],
      import: [:choose_users, :import_qty_label],
      skip: []
    }
    private_constant :WIDGETS

    def initialize
      super
      import_yast_modules
      textdomain "users"

      @login_modified = false
      # do not open package progress wizard window
      @progress_orig = Progress.set(false)

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

      @users = UsersSimple.GetUsers
      init_action
      if action == :import
        @usernames_to_import = @users.map { |u| u["uid"] || "" }
      end
      if action == :new_user
        @user = @users.first
      end
      @user ||= {}
      init_user_attributes
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

    def next_handler
      case action
      when :new_user
        return unless process_new_user_form

        create_new_user
      when :import
        return unless process_import_form

        import_users
      when :skip
        clean_users_info
      end

      super
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

    def help_text
      help = _(
        "<p>\nUse one of the available options to add local users to the system.\n" \
        "Local users are stored in <i>/etc/passwd</i> and <i>/etc/shadow</i>.\n</p>\n"
      ) +
        "<p>\n<b>" + _("Create new user") + "</b>\n</p>\n" +
      _(
        "<p>\nEnter the <b>User's Full Name</b>, <b>Username</b>, and <b>Password</b> to\n" \
        "assign to this user account.\n</p>\n") +
      _(
        "<p>\nWhen entering a password, distinguish between uppercase and\n" \
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

    # Sets the initial value for the action selection
    # Requires @users to be already set
    def init_action
      @action = case @users.size
      when 0
        # New user is the default option
        GetInstArgs.going_back ? :skip : :new_user
      when 1
        @users.first["__imported"] ? :import : :new_user
      else
        :import
      end
    end

    def dialog_title
      import_available? ? _("Local Users") : _("Local User")
    end

    def title_icon
      "yast-users"
    end

    def create_dialog
      super
      refresh
      set_focus
      true
    end

    def close_dialog
      super
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
      WIDGETS.values.flatten.each do |w|
        UI.ChangeWidget(Id(w), :Enabled, WIDGETS[action].include?(w))
      end
    end

    def set_focus
      widget = WIDGETS[action].first
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
        UI.QueryWidget(Id(:autologin), :Value) ? @username : ""
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
      create_users = @usernames_to_import.map do |name|
        u = @importable_users.fetch(name, {})
        u["__imported"] = true
        u["encrypted"] = true
        u
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

    def dialog_content
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
            # TRANSLATORS: radio button
            _("&Create New User"),
            action == :new_user
          )
        ),
        VSpacing(0.3),
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
              # TRANSLATORS: radio button
              _("&Import User Data from a Previous Installation"),
              action == :import
            )
          ),
          VSpacing(0.3),
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
          # TRANSLATORS: radio button
          _("&Skip User Creation"),
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
