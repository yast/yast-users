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

require "y2users"
require "y2users/users_simple"
require "y2users/help_texts"
require "users/local_password"

Yast.import "Popup"
Yast.import "Report"
Yast.import "UsersSimple"

module Users
  # The widget contains 2 password input fields
  # to type and retype the password
  class PasswordWidget < CWM::CustomWidget
    class << self
      attr_accessor :approved_pwd
    end

    include Y2Users::HelpTexts

    # If `little_space` is `false` (the default), the widget will
    # use a vertical layout, and include a "don't forget this" label.
    #
    # If `little_space` is `true`, the helpful label is omitted
    # and the password fields are laid out horizontally.
    # @param focus [Boolean] if set, then widget set focus to first password input field
    def initialize(little_space: false, focus: false, allow_empty: false)
      textdomain "users"
      @little_space = little_space
      @focus = focus
      @allow_empty = allow_empty
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
      return if current_password.empty?

      Yast::UI.ChangeWidget(Id(:pw1), :Value, current_password)
      Yast::UI.ChangeWidget(Id(:pw2), :Value, current_password)
    end

    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/PerceivedComplexity
    def validate
      password1 = Yast::UI.QueryWidget(Id(:pw1), :Value)
      password2 = Yast::UI.QueryWidget(Id(:pw2), :Value)
      return true if allow_empty? && password1.empty?

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

      root_user.password = Y2Users::Password.create_plain(password1)

      # do not ask again if already approved (bsc#1025835)
      return true if self.class.approved_pwd == password1

      return false unless valid_password?

      self.class.approved_pwd = password1

      true
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/PerceivedComplexity

    def store
      return if allow_empty? && empty?

      password1 = Yast::UI.QueryWidget(Id(:pw1), :Value)
      root_user.password = Y2Users::Password.create_plain(password1)
    end

    # rubocop:disable Metrics/MethodLength
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

      helptext << valid_password_text

      # help text, continued 4
      helptext << _(
        "<p>\n" \
        "Do not forget this \"root\" password.\n" \
        "</p>"
      )

      helptext << ca_password_text
    end
    # rubocop:enable Metrics/MethodLength

  private

    # Determines whether the widget is empty or not
    #
    # @return [Boolean]
    def empty?
      pw1 = Yast::UI.QueryWidget(Id(:pw1), :Value)
      pw2 = Yast::UI.QueryWidget(Id(:pw2), :Value)
      pw1.to_s.empty? && pw2.to_s.empty?
    end

    # Determines whether is allowed to do not fill the password
    #
    # @note In that case, the password will not be validated or stored if it is left empty.
    #
    # @return [Boolean]
    def allow_empty?
      @allow_empty
    end

    # Config object holding the users and passwords to create
    #
    # @return [Y2Users::Config]
    def users_config
      return @users_config if @users_config

      @users_config = Y2Users::Config.new
      Y2Users::UsersSimple::Reader.new.read_to(@users_config)
      @users_config
    end

    # Root users for which is possible to define the password during the :new_user action
    #
    # @return [Y2Users::User]
    def root_user
      @root_user ||= users_config.users.find(&:root?)
    end

    # Current password value for root_user
    #
    # @return [String]
    def current_password
      pwd = root_user&.password&.value&.content
      pwd.to_s
    end

    # Checks whether the entered password is acceptable, reporting fatal problems to the user and
    # asking for confirmation for the non-fatal ones
    #
    # @return [Boolean]
    def valid_password?
      issues = root_user.password_issues
      return true if issues.empty?

      Yast::UI.SetFocus(Id(:pw1))

      fatal = issues.find(&:fatal?)
      if fatal
        Yast::Report.Error(fatal.message)
        return false
      end

      message = issues.map(&:message).join("\n\n") + "\n\n" + _("Really use this password?")
      Yast::Popup.YesNo(message)
    end
  end
end
