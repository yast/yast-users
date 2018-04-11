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
#  groups.ycp
# Module:
#  Configuration of the users and groups stettings
#
# Summary:
#  Main file.
#
# Authors:
#	Jiri Suchomel <jsuchome@suse.cz>
#
# $Id$
#
# Just a shortcut to invoke groups management

module Yast
  class GroupsClient < Client
    def main
      Yast.import "UI"

      textdomain "users"

      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Users module started")
      Builtins.y2useritem("User and Group Management module started")

      Yast.import "CommandLine"
      Yast.import "Mode"
      Yast.import "Users"
      Yast.import "UsersCache"
      Yast.import "UsersDialogsFlags"

      Yast.include self, "users/wizards.rb"
      Yast.include self, "users/cmdline.rb"

      @start_dialog = "summary"
      @ret = nil
      @arg = 0
      @possible_start_dialogs = ["group_add", "summary", "users", "groups"]
      # do not pass arguments to cmd-line interpreter
      @no_cmdline = false

      while Ops.less_than(@arg, Builtins.size(WFM.Args))
        @a = WFM.Args(@arg)
        if Ops.is_string?(@a) && Builtins.contains(@possible_start_dialogs, @a)
          @start_dialog = Convert.to_string(WFM.Args(@arg))
          @no_cmdline = true
        end
        @arg = Ops.add(@arg, 1)
      end

      # default for this client
      UsersCache.SetCurrentSummary("groups")

      if @start_dialog == "users" || @start_dialog == "groups"
        UsersCache.SetCurrentSummary(@start_dialog)
        @start_dialog = "summary"
      end

      if @no_cmdline
        Builtins.y2milestone(
          "Starting with %1 - test mode: %2",
          @start_dialog,
          Mode.test
        )
        UsersDialogsFlags.assign_start_dialog(@start_dialog)
        @ret = UsersSequence(@start_dialog)
        Builtins.y2milestone("Users module finished with %1", @ret)
        Builtins.y2milestone("----------------------------------------")
        return deep_copy(@ret)
      end

      # else parse arguments in cmdline
      Builtins.y2milestone("Starting with arguments: %1", WFM.Args)


      # the command line description map
      @cmdline = {
        "id"         => "groups",
        # translators: command line help text for Users module
        "help"       => _(
          "Group configuration module"
        ),
        "guihandler" => fun_ref(method(:UsersGUI), "boolean ()"),
        "initialize" => fun_ref(method(:UsersRead), "boolean ()"),
        "finish"     => fun_ref(method(:UsersWrite), "boolean ()"),
        "actions"    => {
          "list"   => {
            "handler"         => fun_ref(
              method(:GroupsListHandler),
              "boolean (map <string, string>)"
            ),
            # translators: command line help text for list action
            "help"            => _(
              "List of available groups"
            ),
            "options"         => ["non_strict"],
            # help text for unknown parameter name
            "non_strict_help" => _(
              "User parameters that should be listed"
            )
          },
          "show"   => {
            "handler" => fun_ref(method(:GroupShowHandler), "boolean (map)"),
            # translators: command line help text for show action
            "help"    => _(
              "Show information of selected group"
            )
          },
          "delete" => {
            "handler" => fun_ref(
              method(:GroupDeleteHandler),
              "boolean (map <string, any>)"
            ),
            # translators: command line help text for delete action
            "help"    => _(
              "Delete an existing group"
            )
          },
          "add"    => {
            "handler"         => fun_ref(
              method(:GroupAddHandler),
              "boolean (map <string, any>)"
            ),
            # translators: command line help text for ad action
            "help"            => _(
              "Add new group"
            ),
            "options"         => ["non_strict"],
            # help text for unknown parameter name
            "non_strict_help" => _(
              "Additional (LDAP) group parameters"
            )
          },
          "edit"   => {
            "handler"         => fun_ref(
              method(:GroupEditHandler),
              "boolean (map <string, any>)"
            ),
            # translators: command line help text for ad action
            "help"            => _(
              "Edit an existing group"
            ),
            "options"         => ["non_strict"],
            # help text for unknown parameter name
            "non_strict_help" => _(
              "Additional (LDAP) group parameters"
            )
          }
        },
        "options"    => {
          "local"         => {
            # translators: command line help text for list local option
            "help" => _(
              "List of local groups"
            )
          },
          "system"        => {
            # translators: command line help text for list system option
            "help" => _(
              "List of system groups"
            )
          },
          "ldap"          => {
            # translators: command line help text for list ldap option
            "help" => _(
              "List of LDAP groups"
            )
          },
          "nis"           => {
            # translators: command line help text for list nis option
            "help" => _(
              "List of NIS groups"
            )
          },
          "gid"           => {
            # translators: command line help text for show uid option
            "help" => _(
              "GID of the group"
            ),
            "type" => "string"
          },
          "groupname"     => {
            # translators: command line help text for groupname option
            "help" => _(
              "Name of the group"
            ),
            "type" => "string"
          },
          "password"      => {
            # translators: command line help text for 'password' option
            "help" => _(
              "Password of the group"
            ),
            "type" => "string"
          },
          "userlist"      => {
            # translators: command line help text for 'user' option
            "help" => _(
              "List of group members, usually usernames, separated by commas. The list of LDAP user DNs must be separated by colons."
            ),
            "type" => "string"
          },
          "new_groupname" => {
            # translators: command line help text for new_groupname option
            "help" => _(
              "New group name"
            ),
            "type" => "string"
          },
          "new_gid"       => {
            # translators: command line help text for new_gid option
            "help" => _(
              "New GID of the group"
            ),
            "type" => "string"
          },
          "type"          => {
            # translators: command line help text for show option
            "help" => _(
              "Type of the group (local, system, nis, ldap)"
            ),
            "type" => "string"
          },
          "ldap_password" => {
            # translators: command line help text for ldap_password option
            "help" => _(
              "Password for LDAP server"
            ),
            "type" => "string"
          },
          "batchmode"     => {
            # translators: command line help text for batchmode option
            "help" => _(
              "Do not ask for missing data; return error instead."
            )
          }
        },
        "mappings"   => {
          "list"   => ["local", "system", "ldap", "nis"],
          # + "custom"
          "show"   => ["gid", "groupname", "type"],
          "delete" => ["groupname", "gid", "type", "ldap_password"],
          "add"    => [
            "groupname",
            "gid",
            "password",
            "userlist",
            "type",
            "ldap_password"
          ],
          "edit"   => [
            "groupname",
            "gid",
            "password",
            "new_gid",
            "userlist",
            "new_groupname",
            "type",
            "ldap_password"
          ]
        }
      }

      @ret = CommandLine.Run(@cmdline)

      Builtins.y2useritem("User and Group Management module finished")
      Builtins.y2milestone("Users module finished with %1", @ret)
      Builtins.y2milestone("----------------------------------------")
      deep_copy(@ret)
    end
  end
end

Yast::GroupsClient.new.main
