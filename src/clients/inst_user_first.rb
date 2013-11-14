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
module Yast
  class InstUserFirstClient < Client

    # minimal pw length for CA-management (F#300438)
    MIN_PW_LEN_CA = 4

    def main
      Yast.import "UI"
      Yast.import "GetInstArgs"
      Yast.import "Label"
      Yast.import "Mode"
      Yast.import "Popup"
      Yast.import "Package"
      Yast.import "ProductControl"
      Yast.import "ProductFeatures"
      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "UsersSimple"
      Yast.import "Wizard"

      textdomain "users"

      @text_mode = UI.TextMode

      @check_CA_constraints = ProductFeatures.GetBooleanFeature(
        "globals",
        "root_password_ca_check"
      ) == true

      # full info about imported users
      @imported_users = {}
      # user names of imported users
      @user_names = []
      # names of imported users selected for writing
      @to_import = []

      # if importing users from different partition is possible
      @import_available = UsersSimple.ImportAvailable

      if !GetInstArgs.going_back && @import_available
        @imported_users = UsersSimple.GetImportedUsers("local")
        @user_names = @imported_users.keys

        if @user_names.empty?
          Builtins.y2milestone("No users to import")
          @import_available = false
        end
      end

      # do not open package progress wizard window
      @progress_orig = Progress.set(false)

      @encryption_method = UsersSimple.EncryptionMethod

      # radiobutton label
      @button_label = _("L&ocal (/etc/passwd)")

      @encoding2label = {
        # encryption type
        "des"    => _("DES"),
        # encryption type
        "md5"    => _("MD5"),
        # encryption type
        "sha256" => _("SHA-256"),
        # encryption type
        "sha512" => _("SHA-512")
      }

      @import_checkbox = Left(
        CheckBox(
          Id(:import_ch),
          # check box label
          _("&Read User Data from a Previous Installation")
        )
      )

      # button label
      @import_button = PushButton(Id(:import), _("&Choose"))

      @buttons = VBox(
        VSpacing(0.5),

        VBox(
          Left(
            RadioButton(
              Id("users"),
              Opt(:notify),
              @button_label
            )
          ),
          @import_available ?
            HBox(
              HSpacing(3),
              @text_mode ?
                VBox(@import_checkbox, Left(@import_button)) :
                HBox(@import_checkbox, @import_button)
            )
          :
            Empty()
        ),

        VSpacing(0.5)
      )

      @auth_term = VBox(
        Frame(
          _("Authentication Method"),
          RadioButtonGroup(Id(:auth_method), @buttons)
        )
      )

      # frame label
      @encryption_term = Frame(
        _("Password Encryption Type"),
        RadioButtonGroup(
          Id(:encryption_method),
          VBox(
            VSpacing(0.5),
            # Radio button label: password encryption type
            Left(RadioButton(Id("des"), _("&DES"))),
            # Radio button label: password encryption type
            Left(RadioButton(Id("md5"), _("&MD5"))),
            # Radio button label: password encryption type
            Left(RadioButton(Id("sha256"), _("SHA-&256"))),
            # Radio button label: password encryption type
            Left(RadioButton(Id("sha512"), _("SHA-&512"))),
            VSpacing(0.5)
          )
        )
      )

      # help text for dialog "User Authentication Method" 1/2
      @auth_help = _("<p><b>Authentication</b><br></p>") <<
        # help text for dialog "User Authentication Method" 2/2
        _("<p>Select <b>Local</b> to authenticate users only by using the " +
          "local files <i>/etc/passwd</i> and <i>/etc/shadow</i>.</p>")

      # Help text for password expert dialog
      @encryption_help = _("<p>Choose a password encryption method for local and system users.</p>") <<
        # Help text for password expert dialog
        _("<p><b>SHA-512</b> is the current standard hash method. Using other " +
          "algorithms is not recommended unless needed for compatibility purposes.</p>")

      @users = UsersSimple.GetUsers
      @user = {}

      if @users.size > 1
        @to_import = @users.map { |u| u["uid"] || "" }
      elsif @users.size == 1
        if @users.first["__imported"] != nil
          @to_import = [@users.first.fetch("uid", "")]
        else
          @user = @users.first
        end
      end

      @user_type = @user.fetch("type", "local")
      @username = @user.fetch("uid", "")
      @cn = @user.fetch("cn", "")
      @password = @user["userPassword"]

      @autologin = UsersSimple.AutologinUsed
      # set the initial default value for autologin
      if @user.empty? && !@autologin
        if ProductFeatures.GetBooleanFeature("globals", "enable_autologin") == true
          @autologin = true
        end
        Builtins.y2debug("autologin default value: %1", @autologin)
      end

      @use_pw_for_root = UsersSimple.GetRootPassword == @password
      # set the initial default value for root pw checkbox
      if @user == {} && !@use_pw_for_root
        if ProductFeatures.GetBooleanFeature(
            "globals",
            "root_password_as_first_user"
          ) == true
          @use_pw_for_root = true
        end
        Builtins.y2debug("root_pw default value: %1", @use_pw_for_root)
      end

      # indication that client was called directly from proposal
      @root_dialog_follows = GetInstArgs.argmap.fetch("root_dialog_follows", true)

      # this user gets root's mail
      @root_mail = !@username.empty? && UsersSimple.GetRootAlias == @username

      @fields = VBox(
        InputField(
          Id(:cn),
          Opt(:notify, :hstretch),
          # text entry
          _("User's &Full Name"),
          @cn
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
      )

      @optionbox = VBox(
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
      )
      @contents = HBox(
        HCenter(
          HSquash(
            VBox(
              VStretch(),
              @fields,
              VSpacing(0.2),
              @optionbox,
              VSpacing(),
              ReplacePoint(Id(:rp_status), get_status_term),
              VStretch()
            )
          )
        )
      )

      Wizard.CreateDialog if Mode.normal # for testing only
      Wizard.SetTitleIcon("yast-users")
      # dialog caption
      Wizard.SetContents(
        _("Create New User"),
        @contents,
        main_help,
        GetInstArgs.enable_back,
        GetInstArgs.enable_next || Mode.normal
      )

      widgets = [:cn, :username, :pw1, :pw2, :root_pw, :root_mail, :autologin]

      widgets.each do |w|
        UI.ChangeWidget(Id(w), :Enabled, @to_import.empty?)
      end

      UI.SetFocus(Id(:cn))

      @login_modified = false
      @ret = :back
      while true
        @ret = UI.UserInput

        if @ret == :change && ExpertDialog()
          # show correct values now
          UI.ReplaceWidget(Id(:rp_status), get_status_term)

          widgets.each do |w|
            UI.ChangeWidget(Id(w), :Enabled, @to_import.empty?)
          end
          Wizard.RestoreHelp(main_help)
        end

        if @ret == :cn
          @uname = UI.QueryWidget(Id(:username), :Value)
          @login_modified = false if @login_modified && @uname.empty? # reenable suggestion

          if !@login_modified
            # get the first part
            @full = UI.QueryWidget(Id(:cn), :Value).split(" ", 2).first
            @full = UsersSimple.Transliterate(@full)
            UI.ChangeWidget(
              Id(:username),
              :Value,
              Builtins.tolower(
                Builtins.filterchars(@full, UsersSimple.ValidLognameChars)
              )
            )
          end
        end

        @login_modified = true if @ret == :username
        @ret = :next if @ret == :accept # from proposal

        if @ret == :next
          @error = ""
          # map returned from Check*UI functions
          @error_map = {}
          # map with id's of confirmed questions
          @ui_map = {}

          # username checks
          @username = UI.QueryWidget(Id(:username), :Value)

          if @username.empty?
            # when 2nd stage is enabled, there will be inst_auth anyway
            if !Mode.live_installation &&
                ProductControl.GetUseAutomaticConfiguration == false ||
                # yes-no popup headline
                Popup.YesNoHeadline(
                  _("Empty User Login"),
                  # yes-no popup contents
                  _("Leaving the user name empty only makes sense\n" +
                    "in a network environment with an authentication server.\n" +
                    "Leave it empty?")
                )
              break
            else
              next
            end
          end

          if !valid_username?
            UI.SetFocus(Id(:username))
            next
          end

          # full name checks
          @cn = UI.QueryWidget(Id(:cn), :Value)
          @error = UsersSimple.CheckFullname(@cn)
          if !@error.empty?
            Report.Error(@error)
            UI.SetFocus(Id(:cn))
            next
          end

          if !valid_password?
            UI.SetFocus(Id(:pw1))
            next
          end

          # set UID if home directory is found on future home partition
          @password = UI.QueryWidget(Id(:pw1), :Value)
        end
        break if [:back, :abort, :cancel, :next].include?(@ret)
      end

      if @ret == :next
        UsersSimple.SetAfterAuth("users")
        UsersSimple.SetKerberosConfiguration(false)
        if !@to_import.empty?
          create_users = []

          @to_import.each do |name|
            u = @imported_users.fetch(name, {})
            u["__imported"] = true
            create_users << u
          end

          UsersSimple.SetUsers(create_users)
          UsersSimple.SkipRootPasswordDialog(false)
          UsersSimple.SetRootPassword("") if @root_dialog_follows
          UsersSimple.SetAutologinUser("")
          UsersSimple.SetRootAlias("")
        elsif !@username.empty?
          # save the first user data
          @user_map = {
            "uid"          => @username,
            "userPassword" => @password,
            "cn"           => @cn
          }
          UsersSimple.SetUsers([@user_map])
          UsersSimple.SkipRootPasswordDialog(@use_pw_for_root)
          if @root_dialog_follows || @use_pw_for_root
            UsersSimple.SetRootPassword(@use_pw_for_root ? @password : "")
          end

          UsersSimple.SetAutologinUser(
            UI.QueryWidget(Id(:autologin), :Value) == true ? @username : ""
          )
          UsersSimple.SetRootAlias(
            UI.QueryWidget(Id(:root_mail), :Value) == true ? @username : ""
          )
        end
        UsersSimple.UnLoadCracklib if @use_pw_for_root
      elsif @ret == :back
        # reset to defaults
        UsersSimple.SetAutologinUser("")
        UsersSimple.SetRootAlias("")
        UsersSimple.SetRootPassword("")
        UsersSimple.SetUsers([])
      end

      Wizard.CloseDialog if Mode.normal
      Progress.set(@progress_orig)
      @ret
    end

    # help text for main add user dialog
    def main_help
      # help text for main add user dialog
      help = _("<p>\nEnter the <b>User's Full Name</b>, <b>Username</b>, and <b>Password</b> to\n" +
        "assign to this user account.\n</p>\n") <<
        # help text for main add user dialog
        _("<p>\nWhen entering a password, distinguish between uppercase and\n" +
          "lowercase. Passwords should not contain any accented characters or umlauts.\n</p>\n") <<
        # help text %1 is encryption type, %2,%3 numbers
        Builtins.sformat(
          _("<p>\nWith the current password encryption (%1), the password length should be between\n" +
            " %2 and %3 characters.\n</p>"),
          @encoding2label.fetch(@encryption_method, @encryption_method),
          UsersSimple.GetMinPasswordLength("local"),
          UsersSimple.GetMaxPasswordLength("local")
        ) <<
        UsersSimple.ValidPasswordHelptext

      if @check_CA_constraints
        # additional help text about password
        help << (_("<p>If you intend to use this password for creating certificates,\n" +
          "it has to be at least %s characters long.</p>") % MIN_PW_LEN_CA)
      end

      # help text for main add user dialog
      help << _("<p>\nTo ensure that the password was entered correctly,\n" +
        "repeat it exactly in a second field. Do not forget your password.\n" +
        "</p>\n") <<
        # help text for main add user dialog
        _("<p>\nFor the <b>Username</b> use only letters (no accented characters), digits, and <tt>._-</tt>.\n" +
          "Do not use uppercase letters in this entry unless you know what you are doing.\n" +
          "Usernames have stricter restrictions than passwords. You can redefine the\n" +
          "restrictions in the /etc/login.defs file. Read its man page for information.\n" +
          "</p>\n") <<
        # help text for main add user dialog
        _("<p>Check <b>Use this password for system administrator</b> if the " +
          "same password as entered for the first user should be used for root.</p>") <<
        # help text for main add user dialog
        _("<p>\nThe username and password created here are needed to log in " +
          "and work with your Linux system. With <b>Automatic Login</b> enabled, " +
          "the login procedure is skipped. This user is logged in automatically.</p>\n") <<
        # help text for main add user dialog
        _( "<p>\nHave mail for root forwarded to this user by checking <b>Receive System Mail</b>.</p>\n")
    end

    # Helper function: ask user which users to import
    def choose_to_import(all, selected)
      items = all.map {|u| Item(Id(u), u, selected.include?(u))}
      all_checked = !all.empty? && all.size == selected.size
      vsize = [all.size, 15].max

      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          VSpacing(vsize),
          VBox(
            HSpacing(50),
            MultiSelectionBox(
              Id(:userlist),
              # selection box label
              _("&Select Users to Read"),
              items
            ),
            Left(
              CheckBox(
                Id(:all),
                Opt(:notify),
                # check box label
                _("Select or Deselect &All"),
                all_checked
              )
            ),
            HBox(
              PushButton(Id(:ok), Opt(:default), Label.OKButton),
              PushButton(Id(:cancel), Label.CancelButton)
            )
          )
        )
      )

      ret = nil
      while true
        ret = UI.UserInput
        if ret == :all
          ch = UI.QueryWidget(Id(:all), :Value)
          if ch != all_checked
            UI.ChangeWidget(Id(:userlist), :Items, Builtins.maplist(all) do |u|
              Item(Id(u), u, ch)
            end)
            all_checked = ch
          end
        end
        break if ret == :ok || ret == :cancel
      end

      if ret == :ok
        selected_users = UI.QueryWidget(Id(:userlist), :SelectedItems)
      end

      UI.CloseDialog
      ret == :ok ? selected_users : nil
    end

    # Dialog for expert user settings: authentication method as well
    # as password encryption (see fate 302980)
    # @return true if user accepted expert settings
    def ExpertDialog
      contents = HBox(
        HWeight(1, HBox()),
        HWeight(
          9,
          HBox(
            VBox(
              VStretch(),
              @auth_term,
              VSpacing(),
              @encryption_term,
              VStretch()
            )
          )
        ),
        HWeight(1, HBox())
      )

      Wizard.OpenAcceptDialog
      Wizard.SetContents(
        _("Expert Settings"),
        contents,
        @auth_help + @encryption_help,
        true,
        true
      )

      UI.ChangeWidget(Id(:auth_method), :CurrentButton, "users")
      UI.ChangeWidget(Id(:encryption_method), :CurrentButton, @encryption_method)

      if !@to_import.empty?
        UI.ChangeWidget(Id(:import_ch), :Value, true)
      end

      retval = :cancel
      while true
        retval = UI.UserInput
        if retval == :import
          selected = choose_to_import(@user_names, @to_import)
          @to_import = deep_copy(selected) if selected != nil
          UI.ChangeWidget(
            Id(:import_ch),
            :Value,
            !@to_import.empty?
          )
        end

        if retval == :accept && @import_available && @to_import.empty? &&
            UI.QueryWidget(Id(:import_ch), :Value)
          # force selecting when only checkbox is checked
          selected = choose_to_import(@user_names, @to_import)
          if selected != nil
            @to_import = deep_copy(selected)
          else
            retval = :notnext
            next
          end
        end
        break if retval == :cancel || retval == :accept || retval == :back
      end

      if retval == :accept
        @encryption_method = UI.QueryWidget(Id(:encryption_method), :CurrentButton)
        UsersSimple.SetEncryptionMethod(@encryption_method)
      end
      Wizard.CloseDialog
      retval == :accept
    end

    # build the term with current user configuration status
    def get_status_term
      # summary label
      auth_line = _("The authentication method is local /etc/passwd.")

      # summary label
      details_line = _("The password encryption method is %s.") %
        @encoding2label.fetch(@encryption_method, @encryption_method)

      imported_term = Empty()

      if !@to_import.empty?
        # summary label, %s is a single user name or multiple usernames (comma separated)
        imported = n_("User %s will be imported.", "Users %s will be imported.", @to_import.size) % @to_import.join(",")

        if @text_mode
          auth_line << "<br>" << imported
        else
          imported_term = Left(Label(imported))
        end
      end

      status = @text_mode ?
        RichText(auth_line + "<br>" + details_line) :
        VBox(Left(Label(auth_line)), imported_term, Left(Label(details_line)))

      button = HBox(
        # pushbutton label
        Right(PushButton(Id(:change), _("&Change...")))
      )

      @text_mode ?
        VBox(status, button) :
        # frame label
        Frame(
          _("Summary"),
          HBox(HSpacing(0.2), VBox(status, button, VSpacing(0.2)))
        )
    end

    def valid_username?
      error = UsersSimple.CheckUsernameLength(@username)
      if !error.empty?
        Report.Error(error)
        return false
      end

      error = UsersSimple.CheckUsernameContents(@username, "")
      if !error.empty?
        Report.Error(error)
        return false
      end

      error = UsersSimple.CheckUsernameConflicts(@username)
      if !error.empty?
        Report.Error(error)
        return false
      end

      return true
    end

    def valid_password?
      # password checks
      pw1 = UI.QueryWidget(Id(:pw1), :Value)
      pw2 = UI.QueryWidget(Id(:pw2), :Value)

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

      if !UsersSimple.LoadCracklib
        Builtins.y2error("loading cracklib failed, not used for pw check")
        UsersSimple.UseCrackLib(false)
      end

      errors = UsersSimple.CheckPasswordUI(
        { "uid" => @username, "userPassword" => pw1, "type" => "local" }
      )

      @use_pw_for_root = UI.QueryWidget(Id(:root_pw), :Value)
      if @use_pw_for_root && @check_CA_constraints && pw1.size < MIN_PW_LEN_CA
        # yes/no popup question, %s is a number
        errors << (_("If you intend to create certificates,\n" +
          "the password should have at least %s characters.") % MIN_PW_LEN_CA)
      end

      if !errors.empty?
        message = errors.join("\n\n") + "\n\n" + _("Really use this password?")
        if !Popup.YesNo(message)
          @ret = :notnext
          return false
        end
      end

      return true
    end

  end
end

Yast::InstUserFirstClient.new.main
