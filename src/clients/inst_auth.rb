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

# File:	installation/general/inst_auth.ycp
# Package:	Users configuration
# Summary:	Ask for user authentication method
# Authors:	Arvin Schnell <arvin@suse.de>
#		Michal Svec <msvec@suse.cz>
#
# $Id$
module Yast
  class InstAuthClient < Client
    def main
      Yast.import "UI"

      textdomain "users"

      Yast.import "Directory"
      Yast.import "FileUtils"
      Yast.import "GetInstArgs"
      Yast.import "Label"
      Yast.import "Ldap"
      Yast.import "NetworkInterfaces"
      Yast.import "NetworkService"
      Yast.import "Package"
      Yast.import "Popup"
      Yast.import "Users"
      Yast.import "UsersCache"
      Yast.import "UsersSimple"
      Yast.import "Wizard"

      #----------------------------------------- main body ----------------------

      # first check if some settings were configured in first stage
      if !GetInstArgs.going_back
        Users.ReadSystemDefaults(false)
        UsersSimple.Read(false)
        if UsersSimple.AfterAuth != "users" || UsersSimple.GetUser != {}
          Users.SetKerberosConfiguration(UsersSimple.KerberosConfiguration)
          Users.SetAfterAuth(UsersSimple.AfterAuth)
          Builtins.y2milestone("skipping authentication dialog...")
          return :next
        end
      end

      # check if LDAP/Kerberos are available
      UsersSimple.CheckNetworkMethodsAvailability

      # Check if lan is configured
      @net_devices = NetworkInterfaces.ListDevicesExcept("dialup")
      Builtins.y2debug("net_devices: %1", @net_devices)

      @found = Ops.greater_than(Builtins.size(@net_devices), 0) ||
        NetworkService.is_network_manager

      if !@found && Builtins.size(Ldap.initial_defaults) == 0
        Builtins.y2milestone(
          "network not available: no network based authentization"
        )
        UsersSimple.SetAfterAuth("users")
        return :auto
      end

      @import_available = false
      @import_dir = Ops.add(Directory.vardir, "/imported/userdata/etc")
      @base_dir = Users.GetBaseDirectory
      @user_names = []
      @to_import = []

      if FileUtils.Exists(@import_dir)
        if FileUtils.Exists(Ops.add(@import_dir, "/passwd")) &&
            FileUtils.Exists(Ops.add(@import_dir, "/shadow"))
          @import_available = true
        end
      end

      if @import_available
        Users.SetBaseDirectory(@import_dir)
        @err = Users.ReadLocal
        if @err != ""
          Builtins.y2warning("Error during reading: %1", @err)
        else
          UsersCache.Read
          @user_names = UsersCache.GetUsernames("local")
        end
        if Ops.less_than(Builtins.size(@user_names), 1)
          Builtins.y2milestone("No users to import")
          @import_available = false
          Builtins.foreach(["/passwd", "/shadow", "/group"]) do |file|
            SCR.Execute(path(".target.remove"), Ops.add(@import_dir, file))
          end
        end
        Users.SetBaseDirectory(@base_dir)
      end

      # caption for dialog "User Authentication Method"
      @caption = _("User Authentication Method")

      # help text for dialog "User Authentication Method" 1/3
      @help = _(
        "<p>\n" +
          "<b>Authentication</b><br>\n" +
          "Select the authentication method to use for users on your system.\n" +
          "</p>"
      ) +
        # helptext 2/3
        _(
          "<p>Select <b>Local</b> to authenticate users only by using the local files <i>/etc/passwd</i> and <i>/etc/shadow</i>.</p>"
        )

      if @import_available
        # optional helptext 2.5/3 (local users continued)
        @help = Ops.add(
          @help,
          _(
            "If you have a previous installation or alternative system, it is possible to create users based on this source. To do so, select <b>Read User Data from a Previous Installation</b>. This option uses an existing or creates a new home directory for each user in the location specified for this installation."
          )
        )
      end

      @button_labels = {
        # radiobutton to select ldap user auth.
        "ldap"      => _("&LDAP"),
        # radiobutton to select nis user auth.
        "nis"       => _("N&IS"),
        # radiobutton to select samba user auth.
        "samba-old" => _("&Samba"),
        # radiobutton to select samba user auth.
        "samba"     => _(
          "&Windows Domain"
        ),
        # radiobutton to select local user auth.
        "users"     => _(
          "L&ocal (/etc/passwd)"
        ),
        # radiobutton to select local user auth.
        "edir_ldap" => _(
          "eDirectory LDAP"
        )
      }

      @available_clients = ["users", "ldap"]

      if @found
        @available = false
        Builtins.foreach(
          {
            "nis"       => "yast2-nis-client",
            "samba"     => "yast2-samba-client",
            "edir_ldap" => "yast2-linux-user-mgmt"
          }
        ) do |client, package|
          next if @available == nil
          @available = Package.Installed(package) || Package.Available(package)
          if @available == true
            @available_clients = Builtins.add(@available_clients, client)
          end
        end
      end


      if Builtins.contains(@available_clients, "nis")
        if Builtins.contains(@available_clients, "samba")
          @help = Ops.add(
            @help,
            # helptext 3/3 -- nis & samba & ldap avialable
            _(
              "<p>If you are using a NIS or LDAP server to store user data or if you want\n" +
                "to authenticate users against an NT server, choose the appropriate value. Then\n" +
                "press <b>Next</b> to continue with configuration of your client.</p>"
            )
          )
        else
          @help = Ops.add(
            @help,
            # helptext 3/3 -- nis & ldap avialable
            _(
              "<p>If you are using a NIS or LDAP server to store user data, choose the\nappropriate value. Then press <b>Next</b> to continue with configuration of your client.</p>"
            )
          )
        end
      else
        if Builtins.contains(@available_clients, "samba")
          @help = Ops.add(
            @help,
            # helptext 3/3 -- samba &ldap available
            _(
              "<p>If you are using an LDAP server to store user data or if you want to\n" +
                "authenticate users against an NT server, choose the appropriate value. Then\n" +
                "press <b>Next</b> to continue with configuration of your client.</p>"
            )
          )
        else
          @help = Ops.add(
            @help,
            # helptext 3/3 -- only ldap available
            _(
              "<p>If you are using an LDAP server to store user data, choose the\nappropriate value. Then press <b>Next</b> to continue with configuration of your client.</p>"
            )
          )
        end
      end

      # helptext: additional kerberos support
      @help = Ops.add(
        @help,
        _(
          "<p>Check <b>Set Up Kerberos Authentication</b> to configure Kerberos after configuring the user data source.</p>"
        )
      )


      @buttons = VBox(VSpacing(0.5))

      @display_info = UI.GetDisplayInfo
      @text_mode = Ops.get_boolean(@display_info, "TextMode", false)

      @import_checkbox = Left(
        CheckBox(
          Id(:import_ch),
          # check box label
          _("&Read User Data from a Previous Installation")
        )
      )

      # button label
      @import_button = PushButton(Id(:import), _("&Choose"))

      Builtins.foreach(@available_clients) do |client|
        if client == "users" && @import_available
          @buttons = Builtins.add(
            @buttons,
            VBox(
              Left(
                RadioButton(
                  Id(client),
                  Opt(:notify),
                  Ops.get_string(@button_labels, client, "")
                )
              ),
              HBox(
                HSpacing(3),
                @text_mode ?
                  VBox(@import_checkbox, Left(@import_button)) :
                  HBox(@import_checkbox, @import_button)
              )
            )
          )
        else
          @buttons = Builtins.add(
            @buttons,
            Left(
              RadioButton(
                Id(client),
                Opt(:notify),
                Ops.get_string(@button_labels, client, "")
              )
            )
          )
        end
      end

      @buttons = Builtins.add(@buttons, VSpacing(0.5))

      # set LDAP for default, if ldap-server was configured:
      if Ops.greater_than(Builtins.size(Ldap.initial_defaults), 0)
        UsersSimple.SetAfterAuth("ldap")
      end

      @contents = VBox(
        VStretch(),
        HBox(
          HStretch(),
          VBox(
            # frame title for authentication methods
            Frame(
              _("Authentication Method"),
              RadioButtonGroup(Id(:method), @buttons)
            ),
            VSpacing(),
            # check box label
            Left(
              CheckBox(
                Id(:krb),
                _("Set Up &Kerberos Authentication"),
                UsersSimple.KerberosConfiguration
              )
            )
          ),
          HStretch()
        ),
        VStretch()
      )

      Wizard.SetDesktopIcon("users")
      Wizard.SetContents(
        @caption,
        @contents,
        @help,
        GetInstArgs.enable_back,
        GetInstArgs.enable_next
      )

      @after_client = UsersSimple.AfterAuth
      # select and enable to correct buttons
      Builtins.foreach(@available_clients) do |client|
        UI.ChangeWidget(Id(client), :Value, @after_client == client)
      end
      UI.ChangeWidget(
        Id(:krb),
        :Enabled,
        @after_client != "users" && @after_client != "samba"
      )

      @ret = nil
      begin
        @ret = Wizard.UserInput

        if @ret == :abort
          break if Popup.ConfirmAbort(:incomplete)
        elsif @ret == :help
          Wizard.ShowHelp(@help)
        end
        if @ret == :next && @import_available && @to_import == [] &&
            UI.QueryWidget(Id(:import_ch), :Value) == true
          # force selecting when only checkbox is checked
          @selected = choose_to_import(@user_names, @to_import)
          if @selected != nil
            @to_import = deep_copy(@selected)
          else
            @ret = :notnext
            next
          end
        end
        if @ret == :import
          @selected = choose_to_import(@user_names, @to_import)
          @to_import = deep_copy(@selected) if @selected != nil
          UI.ChangeWidget(
            Id(:import_ch),
            :Value,
            Ops.greater_than(Builtins.size(@to_import), 0)
          )
        end
        if Ops.is_string?(@ret)
          if @import_available
            UI.ChangeWidget(Id(:import_ch), :Enabled, @ret == "users")
            UI.ChangeWidget(Id(:import), :Enabled, @ret == "users")
          end
          UI.ChangeWidget(
            Id(:krb),
            :Enabled,
            @ret != "users" && @ret != "samba"
          )
        end
      end until @ret == :next || @ret == :back

      @method = Convert.to_string(UI.QueryWidget(Id(:method), :CurrentButton))
      UsersSimple.SetAfterAuth(@method)

      if @ret == :next && @method == "users" && @to_import != []
        UsersCache.SetUserType("local")
        @users_to_import = Builtins.maplist(@to_import) do |name|
          Users.SelectUserByName(name)
          u = Users.GetCurrentUser
          deep_copy(u)
        end
        Users.SetUsersForImport(@users_to_import)
      end

      if @ret == :next
        if @method == "users" || @method == "samba"
          UsersSimple.SetKerberosConfiguration(false)
        else
          UsersSimple.SetKerberosConfiguration(
            Convert.to_boolean(UI.QueryWidget(Id(:krb), :Value))
          )
        end
      end

      # remove the data with users information
      Builtins.foreach(["/passwd", "/shadow", "/group"]) do |file|
        SCR.Execute(path(".target.remove"), Ops.add(@import_dir, file))
      end if @import_available

      Convert.to_symbol(@ret) 

      # EOF
    end

    # Helper function
    # Ask user which users to import
    def choose_to_import(all, selected)
      all = deep_copy(all)
      selected = deep_copy(selected)
      items = Builtins.maplist(all) do |u|
        Item(Id(u), u, Builtins.contains(selected, u))
      end
      all_checked = Builtins.size(all) == Builtins.size(selected) &&
        Ops.greater_than(Builtins.size(all), 0)
      vsize = Ops.add(Builtins.size(all), 3)
      vsize = 15 if Ops.greater_than(vsize, 15)

      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          VSpacing(vsize),
          VBox(
            HSpacing(50),
            # selection box label
            MultiSelectionBox(Id(:userlist), _("&Select Users to Read"), items),
            # check box label
            Left(
              CheckBox(
                Id(:all),
                Opt(:notify),
                _("Select or Deselect &All"),
                all_checked
              )
            ),
            HBox(
              PushButton(Id(:ok), Opt(:default, :key_F10), Label.OKButton),
              PushButton(Id(:cancel), Opt(:key_F9), Label.CancelButton)
            )
          )
        )
      )

      ret = nil
      while true
        ret = UI.UserInput
        if ret == :all
          ch = Convert.to_boolean(UI.QueryWidget(Id(:all), :Value))
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
        selected = Convert.convert(
          UI.QueryWidget(Id(:userlist), :SelectedItems),
          :from => "any",
          :to   => "list <string>"
        )
      end
      UI.CloseDialog
      ret == :ok ? selected : nil
    end
  end
end

Yast::InstAuthClient.new.main
