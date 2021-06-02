# Copyright (c) [2016-2021] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "ui/installation_dialog"
require "users/dialogs/users_to_import"
require "y2users"
require "y2users/users_simple"
require "y2users/help_texts"
require "y2users/password_helper"
require "users/users_database"
require "tmpdir"

module Yast
  # Dialog for creation of local users during first stage of installation
  # It stores the user(s) information in the UsersSimple module. The user(s)
  # will then be created by that module during inst_finish
  # rubocop:disable Metrics/ClassLength
  class InstUserFirstDialog < ::UI::InstallationDialog
    include Y2Users::PasswordHelper

    # Widgets to enable/disable depending on the selected action
    # (the first one receives the initial focus if applicable)
    WIDGETS = {
      new_user: [:full_name, :username, :pw1, :pw2, :root_pw, :autologin],
      import:   [:choose_users, :import_qty_label],
      skip:     []
    }.freeze
    private_constant :WIDGETS

    # @return [Symbol] Action selected by the user. Possible values are
    #     :new_user, :import (only possible during installation) and :skip.
    attr_reader :action

    def initialize
      super
      import_yast_modules
      textdomain "users"

      @login_modified = false
      # do not open package progress wizard window
      @progress_orig = Progress.set(false)

      init_action
      init_user_attributes

      # names of imported users selected for writing
      @usernames_to_import = (action == :import) ? users.map(&:name) : []
    end

    def run
      if !enable_local_users?
        reset
        # Fate #326447: Allow system role to default to no local user
        return :auto
      end
      super
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
      imported = UsersToImportDialog.new(importable_users.map(&:name), @usernames_to_import).run
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
      InstUserFirstHelp.new(import_available?).text
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
      Yast.import "ProductFeatures"
      Yast.import "Autologin"
    end

    # Check if creating local users is enabled (default) or disabled in the
    # control.xml file during the installation.
    #
    # @return Boolean
    def enable_local_users?
      ProductFeatures::GetBooleanFeatureWithFallback("globals", "enable_local_users", true)
    end

    # Reset things to properly support switching between a system role with
    # local users and one without: Clear any user already entered including his
    # password and make sure the password of this user will not be used as the
    # root password, but the root password dialog will be shown.
    def reset
      @users_config = nil
      @password = nil
      @use_pw_for_root = false
      clean_users_info
    end

    def init_focus
      widget = WIDGETS[action].first
      UI.SetFocus(Id(widget)) if widget
    end

    # Initializes the instance variables used to configure a new user
    def init_user_attributes
      new_user = (action == :new_user) ? user : nil
      @username = new_user&.name || ""
      @full_name = new_user&.full_name || ""
      @password = new_user&.password&.value&.content || ""

      init_autologin
      init_pw_for_root
    end

    # Sets the initial default value for autologin
    def init_autologin
      @autologin = users_config.login? ? users_config.login.autologin? : false
      # The autologin value from the control file is used only when opening the dialog for first
      # time (i.e., when the user is not attached yet). Note that in general (e.g., when going back
      # during the installation), the user is already attached to a config, see {#user}.
      return if user.attached? || @autologin

      @autologin = true if ProductFeatures.GetBooleanFeature("globals", "enable_autologin") == true
      Builtins.y2debug("autologin default value: %1", @autologin)
    end

    # Sets the initial default value for root pw checkbox
    def init_pw_for_root
      @use_pw_for_root = root_password_matches?
      return if user.attached? || @use_pw_for_root

      if ProductFeatures.GetBooleanFeature("globals", "root_password_as_first_user") == true
        @use_pw_for_root = true
      end

      Builtins.y2debug("root_pw default value: %1", @use_pw_for_root)
    end

    # Sets the initial value for the action selection
    def init_action
      @action = case users.size
      when 0
        # New user is the default option
        GetInstArgs.going_back ? :skip : :new_user
      when 1
        user_imported? ? :import : :new_user
      else
        :import
      end
    end

    # Config object holding the users and passwords to create
    #
    # @return [Y2Users::Config]
    def users_config
      @users_config ||= Y2Users::UsersSimple::Reader.new.read
    end

    # All users to be created
    #
    # @return [Array<Y2Users::User>]
    def users
      users_config.users.reject(&:root?)
    end

    # User to be created, useful during the :new_user action in which {#users}
    # is known to contain only one element
    #
    # @return [Y2Users::User]
    def user
      @user ||= users.first || Y2Users::User.new("")
    end

    # Root users for which is possible to define the password during the :new_user action
    #
    # @return [Y2Users::User]
    def root_user
      @root_user ||= users_config.users.root
    end

    # Checks whether the information entered for the user is valid, reporting the problem to
    # the user otherwise
    #
    # @param target_user [Y2Users::User]
    # @return [Boolean]
    def valid_user?(target_user)
      issue = target_user.issues(skip: [:password]).first
      if issue
        Yast::Report.Error(issue.message)
        focus_on(issue.location)
        return false
      end

      true
    end

    # Whether chosen password if valid or not
    #
    # Note that validations are performed over a copy of
    #
    #   * {#root_user} when using the same password for root
    #   * {#user} when not
    #
    # @param password [Y2Users::Password] the password to be validated
    # @return [Boolean] true when given a valid password; false otherwise
    def valid_password?(password)
      target_user = @use_pw_for_root ? root_user : user
      user_to_validate = target_user.copy
      user_to_validate.password = password

      valid_password_for?(user_to_validate)
    end

    # Sets the UI focus in the widget corresponding to the given issue location
    #
    # @param location [Y2Issues::Location]
    def focus_on(location)
      id = (location.path == "name") ? :username : :full_name
      Yast::UI.SetFocus(Id(id))
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
      init_focus
      true
    end

    def close_dialog
      super
      Progress.set(@progress_orig)
    end

    # Whether {#user} is the result of importing a user from another system
    #
    # Note that imported users contain all the relevant information while non-imported users that
    # are created during the install process doesn't even have an uid yet at this point.
    #
    # @return [Boolean]
    def user_imported?
      importable_users.include?(user)
    end

    # Users database that was imported from a different system (done during pre_install)
    #
    # @return [::Users::UserDatabase, nil] nil if there are no users to be imported
    def importing_database
      ::Users::UsersDatabase.all.first
    end

    # Users from a different system that can be imported into the new installation
    #
    # @return [Array<Y2Users::User>]
    def importable_users
      importing_database&.users || []
    end

    # Whether the password of root and the new user are equal
    #
    # @return [Boolean]
    def root_password_matches?
      value = root_user&.password&.value
      return false unless value&.plain?

      value.content == @password
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
        enable = WIDGETS[action].include?(w)
        enable = false if w == :autologin && enable && !Autologin.supported?
        UI.ChangeWidget(Id(w), :Enabled, enable)
      end
    end

    def action=(value)
      @action = value
      refresh
    end

    def process_new_user_form
      @use_pw_for_root = UI.QueryWidget(Id(:root_pw), :Value)

      target_user = user.copy

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

      @full_name = UI.QueryWidget(Id(:full_name), :Value)

      target_user.name = @username
      target_user.gecos = [@full_name].compact

      return false unless valid_user?(target_user)

      # password checks
      pw1 = UI.QueryWidget(Id(:pw1), :Value)
      pw2 = UI.QueryWidget(Id(:pw2), :Value)

      if pw1 != pw2
        # TRANSLATORS: error popup
        Report.Error(_("The passwords do not match.\nTry again."))
        return false
      end

      password = Y2Users::Password.create_plain(pw1)

      return false unless valid_password?(password)

      target_user.password = password

      @autologin = UI.QueryWidget(Id(:autologin), :Value)

      update_users_config(target_user)

      true
    end

    # Updates the config according to the form values
    #
    # @param target_user [Y2Users::User] the user for updating the configuration
    def update_users_config(target_user)
      user.name     = target_user.name
      user.gecos    = target_user.gecos
      user.password = target_user.password
      users_config.attach(user) unless user.attached?

      root_user.password = target_user.password if @use_pw_for_root

      autologin_user = @autologin ? user : nil
      users_config.login ||= Y2Users::Login.new
      users_config.login.autologin_user = autologin_user
    end

    # Writes the new user into Yast::UserSimple at the end of the process
    def create_new_user
      Y2Users::UsersSimple::Writer.new(users_config).write
      UsersSimple.SkipRootPasswordDialog(@use_pw_for_root)
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
      true
    end

    def import_users
      config = importing_database.filtered_config(@usernames_to_import)
      clean_users_info
      Y2Users::UsersSimple::Writer.new(config).write
    end

    def clean_users_info
      UsersSimple.SkipRootPasswordDialog(false)

      # Writes an empty config, containing only the root user if needed
      config = Y2Users::Config.new
      config.attach(root_user.copy) unless root_dialog_follows

      Y2Users::UsersSimple::Writer.new(config).write

      # Invalidates previous config
      @users_config = nil
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
          @password.nil? ? "" : @password
        ),
        Password(
          Id(:pw2),
          Opt(:hstretch),
          Label.ConfirmPassword,
          @password.nil? ? "" : @password
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
        Left(autologin_checkbox)
      ]
    end

    def autologin_checkbox
      # checkbox label
      label = _("&Automatic Login")

      if Autologin.supported?
        CheckBox(Id(:autologin), label, @autologin)
      else
        @autologin = false
        CheckBox(Id(:autologin), Opt(:disabled), label, false)
      end
    end

    def import_qty_widget
      qty = @usernames_to_import.size
      msg = if qty == 0
        _("No users selected")
      else
        n_("%d user will be imported", "%d users will be imported", qty)
      end
      Label(Id(:import_qty_label), msg % qty)
    end

    # indication that client was called directly from proposal
    def root_dialog_follows
      @root_dialog_follows ||= GetInstArgs.argmap.fetch("root_dialog_follows", true)
    end

    def import_available?
      !!importing_database
    end
  end
  # rubocop:enable Metrics/ClassLength

  # Helper class to generate the help text for {InstUserFirstDialog}
  class InstUserFirstHelp
    include Y2Users::HelpTexts

    # Constructor
    #
    # @param import [Boolean] value for {#import?}
    def initialize(import)
      textdomain "users"

      @import = import
    end

    # Full text to display in the help of the form
    #
    # @return [String] formatted and localized text
    def text
      intro + new_user + import_users + skip
    end

  private

    # Whether the form offers the possibility of importing users from a previous installation
    #
    # @return [Boolean]
    def import?
      !!@import
    end

    # @return [String] formatted and localized text
    def intro
      _(
        "<p>\nUse one of the available options to add local users to the system.\n" \
        "Local users are stored in <i>/etc/passwd</i> and <i>/etc/shadow</i>.\n</p>\n"
      )
    end

    # @return [String] formatted and localized text
    def new_user
      "<p>\n<b>" + _("Create new user") + "</b>\n</p>\n" +
        _(
          "<p>\nEnter the <b>User's Full Name</b>, <b>Username</b>, and <b>Password</b> to\n" \
          "assign to this user account.\n</p>\n"
        ) +
        _(
          "<p>\nWhen entering a password, distinguish between uppercase and\n" \
          "lowercase. Passwords should not contain any accented characters or umlauts.\n</p>\n"
        ) +
        password_format +
        _(
          "<p>\nTo ensure that the password was entered correctly,\n" \
          "repeat it exactly in a second field. Do not forget your password.\n" \
          "</p>\n"
        ) +
        username_format +
        _(
          "<p>Check <b>Use this password for system administrator</b> if the " \
          "same password as entered for the first user should be used for root.</p>"
        ) +
        _(
          "<p>\nThe username and password created here are needed to log in " \
          "and work with your Linux system. With <b>Automatic Login</b> enabled, " \
          "the login procedure is skipped. This user is logged in automatically.</p>\n"
        )
    end

    # @return [String] formatted and localized text
    def import_users
      return "" unless import?

      "<p>\n<b>" + _("Import User Data from a Previous Installation") + "</b>\n</p>\n" +
        _(
          "<p>\nA previous Linux installation with local users has been detected.\n" \
          "The information there can be used to create users in the system being installed.\n" \
          "Use the <b>Choose Users</b> button to select some users. Their basic information will" \
          "\nbe imported.\n</p>\n"
        )
    end

    # @return [String] formatted and localized text
    def skip
      "<p>\n<b>" + _("Skip User Creation") + "</b>\n</p>\n" +
        _(
          "<p>\nSometimes root is the only needed local user, like in network environments\n" \
          "with an authentication server. Select this option to proceed without creating\n" \
          "a local user.\n</p>\n"
        )
    end

    # Explanation of the format the password must follow in order to be valid
    #
    # @return [String] formatted and localized text
    def password_format
      # TRANSLATORS: %{min} and %{max} will be replaced by numbers
      format(
        _("<p>\nThe password length should be between %{min}\n and %{max} characters.\n</p>\n"),
        min: validation_config.min_password_length,
        max: validation_config.max_password_length
      ) + valid_password_text + ca_password_text
    end

    # Explanation of the format the user name must follow in order to be valid
    #
    # @return [String] formatted and localized text
    def username_format
      _(
        "<p>\nFor the <b>Username</b> use only letters (no accented characters), digits, and "\
        "<tt>._-</tt>.\n" \
        "Do not use uppercase letters in this entry unless you know what you are doing.\n" \
        "Usernames have stricter restrictions than passwords. You can redefine the\n" \
        "restrictions in the /etc/login.defs file. Read its man page for information.\n" \
        "</p>\n"
      )
    end
  end
end
