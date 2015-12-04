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
# Dialog for setting root's password during 1st stage of the installation
# Authors:     Jiri Suchomel <jsuchome@suse.cz>
#
# $Id$
module Yast
  class InstRootFirstClient < Client
    def main
      Yast.import "UI"
      textdomain "users"

      Yast.import "GetInstArgs"
      Yast.import "Mode"
      Yast.import "Popup"
      Yast.import "ProductFeatures"
      Yast.import "Report"
      Yast.import "UsersSimple"
      Yast.import "UsersUtils"
      Yast.import "Wizard"

      if UsersSimple.RootPasswordDialogSkipped
        Builtins.y2milestone("root password was set with first user, skipping")
        return :auto
      end

      # Title for root-password dialogue
      @title = _("Password for the System Administrator \"root\"")

      @password = UsersSimple.GetRootPassword
      @password = "" if @password == nil

      @contents = VBox(
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
              @password
            ),
            VSpacing(0.8),
            Password(
              Id(:pw2),
              Opt(:hstretch),
              # Label: get same password again for verification
              _("Con&firm Password"),
              @password
            ),
            VSpacing(2.4),
            # text entry label
            InputField(Opt(:hstretch), _("&Test Keyboard Layout"))
          )
        ),
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

      @helptext = Ops.add(@helptext, UsersSimple.ValidPasswordHelptext)

      # help text, continued 5/5
      @helptext = Ops.add(
        @helptext,
        _(
          "<p>\n" +
            "Do not forget this \"root\" password.\n" +
            "</p>"
        )
      )

      if UsersUtils.check_ca_constraints?
        @helptext = Ops.add(
          @helptext,
          Builtins.sformat(
            # additional help text about password
            _(
              "<p>If you intend to use this password for creating certificates,\nit has to be at least %1 characters long.</p>"
            ),
            UsersUtilsClass::MIN_PASSWORD_LENGTH_CA
          )
        )
      end

      Wizard.CreateDialog if Mode.normal # for testing only

      Wizard.SetTitleIcon("yast-users")
      Wizard.SetContents(
        @title,
        @contents,
        @helptext,
        GetInstArgs.enable_back || Mode.normal,
        GetInstArgs.enable_next || Mode.normal
      )

      @ret = nil
      begin
        UI.SetFocus(Id(:pw1)) if @ret != :abort
        @ret = Convert.to_symbol(Wizard.UserInput)

        if @ret == :abort || @ret == :cancel
          if Popup.ConfirmAbort(:incomplete)
            return :abort
          else
            @ret = :notnext
            next
          end
        end
        @ret = :next if @ret == :accept # from proposal

        if @ret == :next
          @pw1 = Convert.to_string(UI.QueryWidget(Id(:pw1), :Value))
          @pw2 = Convert.to_string(UI.QueryWidget(Id(:pw2), :Value))

          if @pw1 != @pw2
            # report misspellings of the password
            Popup.Message(_("The passwords do not match.\nTry again."))
            @ret = :notnext
            next
          end

          if @pw1.empty?
            Popup.Error(_("No password entered.\nTry again."))
            @ret = :notnext
            next
          end

          @error = UsersSimple.CheckPassword(@pw1, "local")
          if @error != ""
            Report.Error(@error)
            @ret = :notnext
            UI.SetFocus(Id(:pw1))
            next
          end
          # map returned from CheckPasswordUI functions
          @error_map = {}
          # map with id's of confirmed questions
          @ui_map = {}
          @failed = false

          if !UsersSimple.LoadCracklib
            Builtins.y2error("loading cracklib failed, not used for pw check")
            UsersSimple.UseCrackLib(false)
          end

          @errors = UsersSimple.CheckPasswordUI(
            { "uid" => "root", "userPassword" => @pw1, "type" => "system" }
          )

          if UsersUtils.check_ca_constraints? && @pw1.size < UsersUtilsClass::MIN_PASSWORD_LENGTH_CA
            @errors = Builtins.add(
              @errors,
              Builtins.sformat(
                # yes/no popup question, %1 is a number
                _(
                  "If you intend to create certificates,\nthe password should have at least %1 characters."
                ),
                UsersUtilsClass::MIN_PASSWORD_LENGTH_CA
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

          UsersSimple.SetRootPassword(@pw1)
          UsersSimple.UnLoadCracklib
        end
      end until @ret == :next || @ret == :back || @ret == :abort

      Wizard.CloseDialog if Mode.normal
      @ret
    end
  end
end
