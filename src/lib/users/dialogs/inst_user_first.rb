# Copyright (c) [2016-2022] SUSE LLC
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
require "yast2/execute"
require "ui/installation_dialog"
require "users/dialogs/users_to_import"
require "y2users"
require "y2users/help_texts"
require "y2users/password_helper"
require "y2users/username"
require "users/users_database"
require "tmpdir"
require "pathname"

module Yast
  # Dialog for the creation of local users during the installation
  #
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

    # Constructor
    #
    # @param config [Y2Users::Config] Config where the changes are reflected (it is modified).
    # @param user [Y2Users::User] User to work on. If no user is given, then a new user is created.
    def initialize(config, user: nil)
      super()
      import_yast_modules
      textdomain "users"

      @config = config
      # The dialog does not support to have both at the same time, imported users and a new user.
      @user = user unless imported_users?

      # NOTE: the only way to know if the user is going to be created or edited is through
      # {Y2Users::ConfigElement#attached?} method BEFORE the #user method attaches it to the current
      # #config for validation purposes. See #editing_user?
      @editing_user = !!user&.attached?

      @login_modified = false
      # do not open package progress wizard window
      @progress_orig = Progress.set(false)

      init_action
      init_user_attributes
      init_autologin
      init_pw_for_root

      @usernames_to_import = imported_users.map(&:name)
    end

    def run
      # Fate #326447: Allow system role to default to no local user
      return :auto unless enable_local_users?

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
      success = case action
      when :new_user
        new_user_action
      when :import
        import_action
      when :skip
        skip_action
      end

      super if success
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

    attr_reader :config

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
      Yast.import "Progress"
      Yast.import "Report"
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

    def init_focus
      widget = WIDGETS[action].first
      UI.SetFocus(Id(widget)) if widget
    end

    # Sets the initial value for the action selection
    def init_action
      @action = if imported_users?
        :import
      elsif editing_user?
        :new_user
      else
        # New user is the default option
        GetInstArgs.going_back ? :skip : :new_user
      end
    end

    # Initializes the instance variables used to configure a new user
    def init_user_attributes
      @username = user.name || ""
      @full_name = user.full_name || ""
      @password = user.password_content || ""
    end

    # Sets the initial default value for autologin
    def init_autologin
      @autologin = config.login? ? config.login.autologin? : false
      # The autologin value from the control file is used only when opening the dialog for first
      # time, see {#editing_user?}.
      return if editing_user? || @autologin

      @autologin = true if ProductFeatures.GetBooleanFeature("globals", "enable_autologin") == true
      Builtins.y2debug("autologin default value: %1", @autologin)
    end

    # Sets the initial default value for root pw checkbox
    def init_pw_for_root
      @use_pw_for_root = root_password_matches?
      # Initial status of the "user password for root" option, see {#update_root_password}.
      @initial_use_pw_for_root = @use_pw_for_root

      # The the control file setting is used only when opening the dialog for first time, see
      # {#editing_user?}.
      return if editing_user? || @use_pw_for_root

      if ProductFeatures.GetBooleanFeature("globals", "root_password_as_first_user") == true
        @use_pw_for_root = true
      end

      Builtins.y2debug("root_pw default value: %1", @use_pw_for_root)
    end

    # User to work on
    #
    # @return [Y2Users::User]
    def user
      @user ||= Y2Users::User.new("")

      config.attach(@user) unless @user.attached?

      @user
    end

    # Root user for which is possible to define the password during the :new_user action
    #
    # @return [Y2Users::User]
    def root_user
      @root_user ||= config.users.root || Y2Users::User.create_root

      config.attach(@root_user) unless @root_user.attached?

      @root_user
    end

    # Whether the user is being edited
    #
    # It is considered that the user is going to be edited if it was not attached to a configuration
    # when the dialog was initialized
    #
    # @return [Boolean]
    def editing_user?
      @editing_user
    end

    # Checks whether the current information of the user is valid, reporting the problem otherwise
    #
    # @return [Boolean]
    def valid_user?
      issue = user.issues(skip: [:password]).first

      return true unless issue

      Yast::Report.Error(issue.message)
      focus_on(issue.location)

      false
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

    # Whether there are imported user
    #
    # @return [Boolean]
    def imported_users?
      imported_users.any?
    end

    # Imported users from the current config
    #
    # Note that imported users contain all the relevant information while non-imported users that
    # are created during the install process doesn't even have an uid yet at this point.
    #
    # @return [Array<Y2Users::User>]
    def imported_users
      @imported_users = config.users.select { |u| importable_users.any?(u) }
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

    # Returns a copy of the given user with sanitized data
    #
    # It removes the information about the group if the group is not included in the current config.
    #
    # @param user [Y2Users::User]
    # @return [Y2Users::User]
    def sanitized_user(user)
      user.copy.tap do |u|
        group = config.groups.by_gid(u.gid).first
        u.gid = nil unless group
      end
    end

    # Whether the password of root and the new user are equal
    #
    # @return [Boolean]
    def root_password_matches?
      value = root_user&.password&.value
      return false unless value&.plain?

      value.content == @password
    end

    # Proposes the username based on the entered full name
    #
    # @see Y2Users::Username.generate_from
    def propose_login
      full_name = UI.QueryWidget(Id(:full_name), :Value)
      login = Y2Users::Username.generate_from(full_name)

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

    # Action for the new user option
    #
    # Processes the form and performs the actions needed
    #
    # @return [Boolean] whether everything was ok
    def new_user_action
      return false unless process_new_user_form

      perform_new_user

      true
    end

    # Action for the import option
    #
    # Processes the form and performs the actions needed
    #
    # @return [Boolean] whether everything was ok
    def import_action
      return false unless process_import_form

      perform_import

      true
    end

    # Action for the skip option
    #
    # Processes the form and performs the actions needed
    #
    # @return [Boolean] whether everything was ok
    def skip_action
      return false unless process_skip_form

      perform_skip

      true
    end

    def process_new_user_form
      @use_pw_for_root = UI.QueryWidget(Id(:root_pw), :Value)

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

      user.name = @username
      user.gecos = [@full_name].compact
      # In case of editing an existing user, the home should be updated in order to keep the home
      # path as /home/new_username.
      update_home

      return false unless valid_user?

      return false unless process_password

      @autologin = UI.QueryWidget(Id(:autologin), :Value)

      true
    end

    # Updates the user home path if needed
    def update_home
      return if !user.home&.path || user.home.path.empty?

      home_path = Pathname.new(user.home.path)

      return if user.name == home_path.basename.to_s

      user.home.path = home_path.dirname.join(user.name).to_s
    end

    # Processes the password for the user
    #
    # Errors could be reported.
    #
    # @return [Boolean] if the password was correctly assigned to the user
    def process_password
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

      user.password = password
      true
    end

    def perform_new_user
      remove_imported_users
      update_root_password
      configure_login
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

      @autologin = false
      @use_pw_for_root = false

      true
    end

    def perform_import
      remove_user
      remove_imported_users
      configure_login
      update_root_password

      imported_users = importing_database.filtered_config(@usernames_to_import).users.all
      imported_users = imported_users.map { |u| sanitized_user(u) }

      config.attach(imported_users)
    end

    def process_skip_form
      @autologin = false
      @use_pw_for_root = false

      true
    end

    def perform_skip
      remove_user
      remove_imported_users
      configure_login
      update_root_password
    end

    def remove_user
      config.detach(user)
    end

    def remove_imported_users
      config.detach(imported_users) if imported_users?
    end

    # Configures the login options
    def configure_login
      autologin_user = @autologin ? user : nil
      config.login ||= Y2Users::LoginConfig.new
      config.login.autologin_user = autologin_user
    end

    # Updates the root password according to the selected form options
    #
    # The user password is copied to root when the option "use password for root" is selected in
    # the form. Otherwise, there are two cases where the root password should be invalidated:
    #
    # * When the option "use password for root" was deselected, see {#use_pw_for_root_modified?}.
    # * When the new user password matches with the current root password.
    def update_root_password
      if @use_pw_for_root
        root_user.password = user.password.copy
      elsif use_pw_for_root_modified? || root_password_matches?
        root_user.password = nil
      end
    end

    # Whether the status of the "use password for root" option in the new user form was modified
    #
    # @return [Boolean]
    def use_pw_for_root_modified?
      @initial_use_pw_for_root != @use_pw_for_root
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
