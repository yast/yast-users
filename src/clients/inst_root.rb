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

# File:	clients/inst_root.ycp
# Package:	Configuration of users and groups
# Summary:
# Displays two input fields to get the root password from the user.
# Plausibility checks executed:
#
#   - password must be given
#   - first and second entry must match
#   - length of password >= 5, and <= maximum for current encryption
#   - only certain characters allowed
#
# After all the password is crypted and written into the user_settings.
#
# Authors:     Klaus Kämpf <kkaempf@suse.de>
#
# $Id$
module Yast
  class InstRootClient < Client
    def main
      Yast.import "UI"
      textdomain "users"

      Yast.import "GetInstArgs"
      Yast.import "Label"
      Yast.import "Mode"
      Yast.import "Popup"
      Yast.import "ProductFeatures"
      Yast.import "Report"
      Yast.import "Security" # Perl module (Users.pm) donesn't call constructor...
      Yast.import "Stage"
      Yast.import "Users"
      Yast.import "UsersCache"
      Yast.import "UsersSimple"
      Yast.import "Wizard"

      Yast.include self, "users/widgets.rb"

      # e.g. during firstboot, root pw may be set from first user setup (bnc#599287)
      if !GetInstArgs.going_back && Users.GetRootPassword != ""
        Builtins.y2milestone("root password already set, skipping")
        return :auto
      end

      Users.ReadSystemDefaults(false)
      UsersSimple.Read(true)

      @check_CA_constraints = ProductFeatures.GetBooleanFeature(
        "globals",
        "root_password_ca_check"
      )

      # minimal pw length for CA-management (F#300438)
      @pw_min_CA = 4

      @valid_password_chars = Users.ValidPasswordChars

      @this_is_for_real = !Mode.test

      @encryptionMethod = UsersSimple.EncryptionMethod

      @pw = ""
      if GetInstArgs.going_back && Users.GetRootPassword != nil
        @pw = Users.GetRootPassword
      end

      # Title for root-password dialogue
      @title = _("Password for the System Administrator \"root\"")

      @contents = VBox(
        VStretch(),
        HSquash(
          VBox(
            # advise user to remember his new password
            Label(_("Do not forget what you enter here.")),
            VSpacing(0.8),
            Password(
              Id(:pw1),
              Opt(:hstretch),
              # Label: get password for user root
              _("&Password for root User"),
              @pw
            ),
            VSpacing(0.8),
            Password(
              Id(:pw2),
              Opt(:hstretch),
              # Label: get same password again for verification
              _("Con&firm Password"),
              @pw
            ),
            VSpacing(2.4),
            # text entry label
            InputField(Opt(:hstretch), _("&Test Keyboard Layout"))
          )
        ),
        VSpacing(2),
        # push button
        PushButton(Id(:expert), Opt(:key_F7), _("E&xpert Options...")),
        VStretch()
      )

      # help text ( explain what the user "root" is and does ) 1/5
      @helptext = _(
        "<p>\n" +
          "Unlike normal users of the system, who write texts, create\n" +
          "graphics, or browse the Internet, the user \"root\" exists on\n" +
          "every system and is called into action whenever\n" +
          "administrative tasks need to be performed. Only log in as root\n" +
          "when you need to be the system administrator.\n" +
          "</p>\n"
      )

      # help text, continued 2/5
      @helptext = Ops.add(
        @helptext,
        _(
          "<p>\n" +
            "Because the root user is equipped with extensive permissions, the password\n" +
            "for \"root\" should be chosen carefully. A combination of letters and numbers\n" +
            "is recommended. To ensure that the password was entered correctly,\n" +
            "reenter it in a second field.\n" +
            "</p>\n"
        )
      )

      # help text, continued 3/5
      @helptext = Ops.add(
        @helptext,
        _(
          "<p>\n" +
            "All the rules for user passwords apply to the \"root\" password:\n" +
            "Distinguish between uppercase and lowercase. A password should have at\n" +
            "least 5 characters and, as a rule, not contain any accented letters or umlauts.\n" +
            "</p>\n"
        )
      )

      @helptext = Ops.add(@helptext, Users.ValidPasswordHelptext)

      # help text, continued 5/5
      @helptext = Ops.add(
        @helptext,
        _(
          "<p>\n" +
            "Do not forget this \"root\" password.\n" +
            "</p>"
        )
      )

      if @check_CA_constraints
        @helptext = Ops.add(
          @helptext,
          Builtins.sformat(
            # additional help text about password
            _(
              "<p>If you intend to use this password for creating certificates,\nit has to be at least %1 characters long.</p>"
            ),
            @pw_min_CA
          )
        )
      end

      # help text for 'test keyboard layout' entry'
      @helptext = Ops.add(
        @helptext,
        _(
          "<p>To check whether your current keyboard layout is correct, try entering text into the <b>Test Keyboard Layout</b> field.</p>"
        )
      )

      Wizard.CreateDialog if Mode.normal # for testing only
      Wizard.SetDesktopIcon("users")
      Wizard.SetContents(
        @title,
        @contents,
        @helptext,
        GetInstArgs.enable_back || Mode.normal,
        GetInstArgs.enable_next || Mode.normal
      )


      @ret = nil
      begin
        UI.SetFocus(Id(:pw1)) if @ret != :expert && @ret != :abort
        @ret = Convert.to_symbol(Wizard.UserInput)

        if @ret == :abort || @ret == :cancel
          if Popup.ConfirmAbort(:incomplete)
            return :abort
          else
            @ret = :notnext
            next
          end
        end

        if @ret == :expert
          @encryptionMethod = EncryptionPopup()
          Users.SetEncryptionMethod(@encryptionMethod)

          if Convert.to_string(UI.QueryWidget(Id(:pw1), :Value)) == ""
            UI.SetFocus(Id(:pw1))
          else
            Wizard.SetFocusToNextButton
          end
        end
        if @ret == :next
          @pw1 = Convert.to_string(UI.QueryWidget(Id(:pw1), :Value))
          @pw2 = Convert.to_string(UI.QueryWidget(Id(:pw2), :Value))

          if @this_is_for_real && @pw1 != @pw2
            # report misspellings of the password
            Popup.Message(_("The passwords do not match.\nTry again."))
            @ret = :notnext
            next
          end

          if @this_is_for_real
            UsersCache.SetUserType("system")
            Users.SetEncryptionMethod(@encryptionMethod)
            if @pw1 == ""
              # report if user forgot to enter a password
              Popup.Message(_("No password entered.\nTry again."))
              @ret = :notnext
              next
            end

            if Builtins.findfirstnotof(
                @pw1,
                Ops.add(@valid_password_chars, "\\")
              ) != nil
              Popup.Message(Users.ValidPasswordMessage)
              # Invalidate old password
              UI.ChangeWidget(Id(:pw1), :Value, "")
              UI.ChangeWidget(Id(:pw2), :Value, "")
              @ret = :notnext
              next
            end

            @errors = UsersSimple.CheckPasswordUI(
              { "uid" => "root", "userPassword" => @pw1, "type" => "system" }
            )

            if @check_CA_constraints &&
                Ops.less_than(Builtins.size(@pw1), @pw_min_CA)
              @errors = Builtins.add(
                @errors,
                Builtins.sformat(
                  # yes/no popup question, %1 is a number
                  _(
                    "If you intend to create certificates,\nthe password should have at least %1 characters."
                  ),
                  @pw_min_CA
                )
              )
            end

            if @errors != []
              @message = Ops.add(
                Ops.add(
                  Builtins.mergestring(@errors, "\n\n"),
                  # last part of message popup
                  "\n\n"
                ),
                _("Really use this password?")
              )
              if !Popup.YesNo(@message)
                @ret = :notnext
                next
              end
            end

            Users.WriteSecurity
            Builtins.y2milestone("encrypting with %1", @encryptionMethod)

            Users.SetRootPassword(@pw1)

            if !Users.WriteRootPassword &&
                Popup.YesNo(
                  # Error msg (yes/no)
                  _(
                    "The root password could not be set.\n" +
                      "You might not be able to log in.\n" +
                      "Try setting it again?\n"
                  )
                )
              Users.SetRootPassword("")
              UI.ChangeWidget(Id(:pw1), :Value, "")
              UI.ChangeWidget(Id(:pw2), :Value, "")
              @ret = :notnext
              next
            end
          end
        end
      end until @ret == :next || @ret == :back || @ret == :abort

      Wizard.CloseDialog if Mode.normal
      @ret
    end
  end
end

Yast::InstRootClient.new.main
