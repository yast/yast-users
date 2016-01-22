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
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------
require "users/ca_password_validator"
require "users/local_password"

module Yast
  # This library provides a simple dialog for setting new password for the
  # system adminitrator (root) including checking quality of the password
  # itself. The new password is not stored here, just set in UsersSimple module
  # and stored later during inst_finish.
  class InstRootFirstDialog
    include Yast::Logger
    include Yast::I18n
    include Yast::UIShortcuts

    def run
      Yast.import "UI"
      Yast.import "GetInstArgs"
      Yast.import "Mode"
      Yast.import "Popup"
      Yast.import "Report"
      Yast.import "UsersSimple"
      Yast.import "Wizard"

      textdomain "users"

      return :auto unless root_password_dialog_needed?

      # We do not need to create a wizard dialog in installation, but it's
      # helpful when testing all manually on a running system
      Wizard.CreateDialog if separate_wizard_needed?

      create_ui
      ret = handle_ui

      Wizard.CloseDialog if separate_wizard_needed?

      ret
    end

  private

    # Returns a UI widget-set for the dialog
    def root_password_ui
      current_password = UsersSimple.GetRootPassword || ""

      VBox(
        VStretch(),
        HSquash(
          VBox(
            # advise users to remember their new password
            Left(Label(_("Do not forget what you enter here."))),
            VSpacing(0.8),
            Password(
              Id(:pw1),
              Opt(:hstretch),
              # Label: get password for user root
              _("&Password for root User"),
              current_password
            ),
            VSpacing(0.8),
            Password(
              Id(:pw2),
              Opt(:hstretch),
              # Label: get same password again for verification
              _("Con&firm Password"),
              current_password
            ),
            VSpacing(2.4),
            # text entry label
            InputField(Opt(:hstretch), _("&Test Keyboard Layout"))
          )
        ),
        VStretch()
      )
    end

    # Returns help for the dialog
    def root_password_help
      # help text ( explain what the user "root" is and does ) 1
      helptext = _(
        "<p>\n" \
        "Unlike normal users of the system, who write texts, create\n" \
        "graphics, or browse the Internet, the user \"root\" exists on\n" \
        "every system and is called into action whenever\n" \
        "administrative tasks need to be performed. Only log in as root\n" \
        "when you need to be the system administrator.\n" \
        "</p>\n"
      ).dup <<

      # help text, continued 2
      _(
        "<p>\n" \
        "Because the root user is equipped with extensive permissions, the password\n" \
        "for \"root\" should be chosen carefully. A combination of letters and numbers\n" \
        "is recommended. To ensure that the password was entered correctly,\n" \
        "reenter it in a second field.\n" \
        "</p>\n"
      ) <<

      # help text, continued 3
      _(
        "<p>\n" \
        "All the rules for user passwords apply to the \"root\" password:\n" \
        "Distinguish between uppercase and lowercase. A password should have at\n" \
        "least 5 characters and, as a rule, not contain any accented letters or umlauts.\n" \
        "</p>\n"
      )

      helptext = helptext + UsersSimple.ValidPasswordHelptext

      # help text, continued 4
      helptext << _(
        "<p>\n" \
        "Do not forget this \"root\" password.\n" \
        "</p>"
      )

      helptext << ::Users::CAPasswordValidator.new.help_text

      helptext
    end

    # Sets the wizard dialog contents
    def create_ui
      Wizard.SetTitleIcon("yast-users")

      Wizard.SetContents(
        # Title for root-password dialogue
        _("Password for the System Administrator \"root\""),
        root_password_ui,
        root_password_help,
        GetInstArgs.enable_back || Mode.normal,
        GetInstArgs.enable_next || Mode.normal
      )
    end

    # Handles user's input and returns symbol what to do next
    # @return [Symbol] :next, :back or :abort
    def handle_ui
      begin
        UI.SetFocus(Id(:pw1))
        ret = Wizard.UserInput

        if ret == :abort || ret == :cancel
          if Popup.ConfirmAbort(:incomplete)
            ret = :abort
          else
            ret = :try_again
            next
          end
        end

        ret = :next if ret == :accept # from proposal

        if ret == :next
          password_1 = Convert.to_string(UI.QueryWidget(Id(:pw1), :Value))
          password_2 = Convert.to_string(UI.QueryWidget(Id(:pw2), :Value))

          if validate_password(password_1, password_2)
            UsersSimple.SetRootPassword(password_1)
          else
            ret = :try_again
          end
        end
      end until ret == :next || ret == :back || ret == :abort

      ret
    end

    # Validates whether password1 and password2 match and are valid
    def validate_password(password_1, password_2)
      if password_1 != password_2
        # report misspellings of the password
        Popup.Message(_("The passwords do not match.\nTry again."))
        return false
      end

      if password_1.empty?
        Popup.Error(_("No password entered.\nTry again."))
        return false
      end

      error = UsersSimple.CheckPassword(password_1, "local")

      if error != ""
        Report.Error(error)
        return false
      end

      passwd = ::Users::LocalPassword.new(username: "root", plain: password_1)
      # User can confirm using "invalid" password confirming all the errors
      if !passwd.valid?
        errors = passwd.errors + [_("Really use this password?")]
        return false unless Popup.YesNo(errors.join("\n\n"))
      end

      return true
    end

    # Returns whether we need/ed to create new UI Wizard
    def separate_wizard_needed?
      Mode.normal
    end

    # Returns whether we need to run this dialog
    def root_password_dialog_needed?
      if UsersSimple.RootPasswordDialogSkipped
        log.info "root password was set with first user, skipping"
        return false
      end

      true
    end
  end
end
