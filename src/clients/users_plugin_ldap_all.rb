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

# File:
#	include/users/users_plugin_ldap_all.ycp
#
# Package:
#	Configuration of Users
#
# Summary:
#	This is part GUI of UsersPluginLDAPAll - plugin for editing all LDAP
#	user/group attributes.
#
# Authors:
#	Jiri Suchomel <jsuchome@suse.cz>
#
# $Id$
module Yast
  class UsersPluginLdapAllClient < Client
    def main
      Yast.import "UI"
      textdomain "users" # use own textdomain for new plugins

      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Report"
      Yast.import "Wizard"

      Yast.import "Ldap"
      Yast.import "LdapPopup"
      Yast.import "Users"
      Yast.import "UsersLDAP"
      Yast.import "UsersPluginLDAPAll" # plugin module

      @ret = nil
      @func = ""
      @config = {}
      @data = {}

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @config = Convert.convert(
            WFM.Args(1),
            :from => "any",
            :to   => "map <string, any>"
          )
        end
        if Ops.greater_than(Builtins.size(WFM.Args), 2) &&
            Ops.is_map?(WFM.Args(2))
          @data = Convert.convert(
            WFM.Args(2),
            :from => "any",
            :to   => "map <string, any>"
          )
        end
      end
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("users plugin started: LDAPAll")

      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("config=%1", @config)
      Builtins.y2debug("data=%1", @data)

      if @func == "Summary"
        @ret = UsersPluginLDAPAll.Summary(@config, {})
      elsif @func == "Name"
        @ret = UsersPluginLDAPAll.Name(@config, {})
      elsif @func == "Dialog"
        @caption = UsersPluginLDAPAll.Name(@config, {})
        @what = Ops.get_string(@config, "what", "user")
        @action = Ops.get_string(@data, "what", "")

        @tmp_data = {}
        @object_class = Convert.convert(
          Builtins.sort(Ops.get_list(@data, "objectClass", [])),
          :from => "list",
          :to   => "list <string>"
        )

        # helptext 1/3
        @help_text = Ops.add(
          Ops.add(
            _(
              "<p>\nHere, see the table of all allowed attributes for the current LDAP entry that were not set in previous dialogs.</p>"
            ),
            # helptext 1/3 (don't translate objectclass"),
            # %1 is list of values
            Builtins.sformat(
              _(
                "<p>\n" +
                  "The list of attributes is given by the value of \"objectClass\"\n" +
                  "(which is currently:\n" +
                  "<br>%1).\n" +
                  "</p>\n"
              ),
              Builtins.mergestring(@object_class, ",<br>")
            )
          ),
          # helptext 3/3
          _(
            "<p>\n" +
              "Edit each attribute using <b>Edit</b>. Some attributes \n" +
              "could be required, as defined in the user template in the <b>LDAP Client Module</b>.</p>\n"
          )
        )

        @items = []
        @used_attributes = []
        @new_attributes = []
        @modified = false

        # which LDAP keys should not be edited here
        # (either because they were edited before or it is to hard to edit
        # them (objectclass, DN)
        @do_not_show_keys = @what == "user" ?
          [
            "uid",
            "username",
            "uidNumber",
            "homeDirectory",
            # "givenName", "sn",
            "userPassword",
            "objectClass",
            "loginShell",
            "gidNumber",
            "shadowLastChange",
            "shadowWarning",
            "shadowInactive",
            "shadowExpire",
            "shadowMin",
            "shadowMax",
            "shadowFlag"
          ] :
          # and now for groups
          [
            "groupname",
            "gidNumber",
            "userPassword",
            "objectClass",
            "userlist",
            "cn",
            Ldap.member_attribute
          ]

        # keys in user's map which are not saved anywhere
        @internal_keys = @what == "user" ?
          UsersLDAP.GetUserInternal :
          UsersLDAP.GetGroupInternal
        # show only attributes allowed by schema
        @allowed_attrs = Ldap.GetObjectAttributes(@object_class)

        # do not allow editing of binary values (perl converts them to string)
        @binary_attrs = ["jpegPhoto", "userCertificate"]

        # generate table items from already existing values
        Builtins.foreach(@data) do |attr, val|
          next if Builtins.contains(@internal_keys, attr)
          next if Builtins.contains(@do_not_show_keys, attr)
          next if !Builtins.contains(@allowed_attrs, attr)
          next if Ops.is_map?(val) || val == nil
          value = []
          if Ops.is_list?(val)
            value = Convert.convert(val, :from => "any", :to => "list <string>")
          end
          if Builtins.contains(@binary_attrs, attr) || Ops.is_byteblock?(val) ||
              Ops.is_list?(val) && Ops.is_byteblock?(Ops.get(value, 0))
            Builtins.y2warning("binary value (%1) cannot be edited", attr)
            next
          elsif Ops.is_integer?(val)
            value = [Builtins.sformat("%1", val)]
            Ops.set(@data, attr, value)
          elsif Ops.is_string?(val)
            value = [Convert.to_string(val)]
            Ops.set(@data, attr, value)
          end
          @used_attributes = Builtins.add(@used_attributes, attr)
          @items = Builtins.add(
            @items,
            Item(Id(attr), attr, Builtins.mergestring(value, ","))
          )
        end

        # generate table items with empty values
        # (not set for this user/group yet)
        # we need to read available attributes from Ldap
        Builtins.foreach(@object_class) do |_class|
          Builtins.foreach(
            Convert.convert(
              Ldap.GetAllAttributes(_class),
              :from => "list",
              :to   => "list <string>"
            )
          ) do |at|
            # remove already used (uid, uidnumber, homedirectory etc.)
            if !Builtins.haskey(@data, at) &&
                !Builtins.contains(@do_not_show_keys, at)
              Ops.set(@data, at, [])
              @new_attributes = Builtins.add(@new_attributes, at)
              @items = Builtins.add(@items, Item(Id(at), at, ""))
            end
          end
        end

        @contents = HBox(
          HSpacing(1.5),
          VBox(
            VSpacing(0.5),
            Table(
              Id(:table),
              Opt(:notify),
              Header(
                # table header 1/2
                _("Attribute") + "  ",
                # table header 2/2
                _("Value")
              ),
              @items
            ),
            HBox(
              PushButton(Id(:edit), Opt(:key_F4), Label.EditButton),
              HStretch()
            ),
            VSpacing(0.5)
          ),
          HSpacing(1.5)
        )

        Wizard.CreateDialog
        Wizard.SetDesktopIcon("org.opensuse.yast.Users")

        # dialog caption
        Wizard.SetContentsButtons(
          _("Additional LDAP Settings"),
          @contents,
          @help_text,
          Label.CancelButton,
          Label.OKButton
        )

        Wizard.HideAbortButton

        if Builtins.size(@items) == 0
          UI.ChangeWidget(Id(:edit), :Enabled, false)
        end

        @ret = :next
        UI.SetFocus(Id(:table))
        begin
          @ret = UI.UserInput
          if @ret == :edit || @ret == :table
            @attr = Convert.to_string(UI.QueryWidget(Id(:table), :CurrentItem))
            @value = Ops.get_list(
              @tmp_data,
              @attr,
              Ops.get_list(@data, @attr, [])
            )
            @value = LdapPopup.EditAttribute(
              {
                "attr"   => @attr,
                "value"  => @value,
                "single" => Ldap.SingleValued(@attr)
              }
            )
            if @value ==
                Ops.get_list(@tmp_data, @attr, Ops.get_list(@data, @attr, []))
              @ret = :notnext
              next
            end
            UI.ChangeWidget(
              Id(:table),
              term(:Item, @attr, 1),
              Builtins.mergestring(@value, ",")
            )
            Ops.set(@tmp_data, @attr, @value)
          end
          if @ret == :next
            @err = UsersPluginLDAPAll.Check(
              @config,
              Convert.convert(
                Builtins.union(@data, @tmp_data),
                :from => "map",
                :to   => "map <string, any>"
              )
            )

            if @err != ""
              Report.Error(@err)
              @ret = :notnext
              next
            end

            break if @tmp_data == {}
            # if this plugin wasn't in default set, we must save its name
            if !Builtins.contains(
                Ops.get_list(@data, "plugins", []),
                "UsersPluginLDAPAll"
              )
              Ops.set(
                @tmp_data,
                "plugins",
                Builtins.add(
                  Ops.get_list(@tmp_data, "plugins", []),
                  "UsersPluginLDAPAll"
                )
              )
            end
            if Ops.get_string(@data, "what", "") == "edit_user"
              Users.EditUser(@tmp_data)
            elsif Ops.get_string(@data, "what", "") == "add_user"
              Users.AddUser(@tmp_data)
            elsif Ops.get_string(@data, "what", "") == "edit_group"
              Users.EditGroup(@tmp_data)
            elsif Ops.get_string(@data, "what", "") == "add_group"
              Users.AddGroup(@tmp_data)
            end
          end
        end until Ops.is_symbol?(@ret) &&
          Builtins.contains(
            [:next, :abort, :back, :cancel],
            Convert.to_symbol(@ret)
          )

        Wizard.CloseDialog
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = false
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("users plugin finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret)
    end
  end
end

Yast::UsersPluginLdapAllClient.new.main
