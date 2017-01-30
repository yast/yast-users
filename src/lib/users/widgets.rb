# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2016 SUSE LINUX GmbH, Nuernberg, Germany.
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

require "yast"
require "cwm/widget"

require "users/ca_password_validator"
require "users/local_password"

Yast.import "Popup"
Yast.import "Report"
Yast.import "UsersSimple"

module Users
  # The widget contains 2 password input fields
  # to type and retype the password
  class PasswordWidget < CWM::CustomWidget
    # If `little_space` is `false` (the default), the widget will
    # use a vertical layout, and include a "don't forget this" label.
    #
    # If `little_space` is `true`, the helpful label is omitted
    # and the password fields are laid out horizontally.
    # @param focus [Boolean] if set, then widget set focus to first password input field
    def initialize(little_space: false, focus: false)
      textdomain "users"
      @little_space = little_space
      @focus = focus
    end

    def contents
      pw1 = Password(
        Id(:pw1),
        Opt(:hstretch),
        # Label: get password for user root
        _("&Password for root User")
      )
      pw2 = Password(
        Id(:pw2),
        Opt(:hstretch),
        # Label: get same password again for verification
        _("Con&firm Password")
      )

      if @little_space
        HBox(
          pw1,
          HSpacing(1),
          pw2
        )
      else
        VBox(
          # advise users to remember their new password
          Left(Label(_("Do not forget what you enter here."))),
          VSpacing(0.8),
          pw1,
          VSpacing(0.8),
          pw2
        )
      end
    end

    def init
      # focus on first password, so user can immediately write. Also does not
      # break openQA current test
      Yast::UI.SetFocus(Id(:pw1)) if @focus
      current_password = Yast::UsersSimple.GetRootPassword
      return if !current_password || current_password.empty?

      Yast::UI.ChangeWidget(Id(:pw1), :Value, current_password)
      Yast::UI.ChangeWidget(Id(:pw2), :Value, current_password)
    end

    def validate
      password1 = Yast::UI.QueryWidget(Id(:pw1), :Value)
      password2 = Yast::UI.QueryWidget(Id(:pw2), :Value)
      if password1 != password2
        # report misspellings of the password
        Yast::Popup.Message(_("The passwords do not match.\nTry again."))
        Yast::UI.SetFocus(Id(:pw2))
        return false
      end

      if password1.empty?
        Yast::Popup.Error(_("No password entered.\nTry again."))
        Yast::UI.SetFocus(Id(:pw1))
        return false
      end

      error = Yast::UsersSimple.CheckPassword(password1, "local")

      if error != ""
        Yast::Report.Error(error)
        Yast::UI.SetFocus(Id(:pw1))
        return false
      end

      passwd = ::Users::LocalPassword.new(username: "root", plain: password1)
      # User can confirm using "invalid" password confirming all the errors
      if !passwd.valid?
        errors = passwd.errors + [_("Really use this password?")]
        Yast::UI.SetFocus(Id(:pw1))
        return false unless Yast::Popup.YesNo(errors.join("\n\n"))
      end

      return true
    end

    def store
      password1 = Yast::UI.QueryWidget(Id(:pw1), :Value)
      Yast::UsersSimple.SetRootPassword(password1)
    end

    def help
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

      helptext << Yast::UsersSimple.ValidPasswordHelptext

      # help text, continued 4
      helptext << _(
        "<p>\n" \
        "Do not forget this \"root\" password.\n" \
        "</p>"
      )

      helptext << ::Users::CAPasswordValidator.new.help_text
    end
  end
end
