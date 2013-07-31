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

# File:	clients/users.ycp
# Package:	Configuration of users and groups
# Summary:	Main file
# Authors:	Jiri Suchomel <jsuchome@suse.cz>
#
# $Id$
#
# Main file for users and groups configuration. Uses all other files.
module Yast
  class UsersClient < Client
    def main
      Yast.import "UI"

      textdomain "users"

      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Users module started")
      Builtins.y2useritem("User and Group Management module started")

      Yast.import "CommandLine"
      Yast.import "Ldap"
      Yast.import "Mode"
      Yast.import "Users"
      Yast.import "UsersCache"

      Yast.include self, "users/wizards.rb"
      Yast.include self, "users/cmdline.rb"

      @start_dialog = "summary"

      @ret = nil
      @arg = 0
      @possible_start_dialogs = [
        "user_add",
        "group_add",
        "summary",
        "user_inst_start",
        "users",
        "groups"
      ]
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
      UsersCache.SetCurrentSummary("users")

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
        Users.SetStartDialog(@start_dialog)
        @ret = UsersSequence(@start_dialog)
        Builtins.y2milestone("Users module finished with %1", @ret)
        Builtins.y2milestone("----------------------------------------")
        return deep_copy(@ret)
      end

      # else parse arguments in cmdline
      Builtins.y2milestone("Starting with arguments: %1", WFM.Args)

      # the command line description map
      @cmdline = {
        "id"         => "users",
        # translators: command line help text for Users module
        "help"       => _(
          "User configuration module"
        ),
        "guihandler" => fun_ref(method(:UsersGUI), "boolean ()"),
        "initialize" => fun_ref(method(:UsersRead), "boolean ()"),
        "finish"     => fun_ref(method(:UsersWrite), "boolean ()"),
        "actions"    => {
          "list"   => {
            "handler"         => fun_ref(
              method(:UsersListHandler),
              "boolean (map <string, any>)"
            ),
            # translators: command line help text for list action
            "help"            => _(
              "List of available users"
            ),
            "options"         => ["non_strict"],
            # help text for unknown parameter name
            "non_strict_help" => _(
              "User parameters that should be listed"
            )
          },
          "show"   => {
            "handler" => fun_ref(method(:UserShowHandler), "boolean (map)"),
            # translators: command line help text for show action
            "help"    => _(
              "Show information of selected user"
            )
          },
          "add"    => {
            "handler"         => fun_ref(
              method(:UserAddHandler),
              "boolean (map <string, any>)"
            ),
            # translators: command line help text for ad action
            "help"            => _(
              "Add new user"
            ),
            "options"         => ["non_strict"],
            # help text for unknown parameter name
            "non_strict_help" => _(
              "Additional (LDAP) user parameters"
            )
          },
          "edit"   => {
            "handler"         => fun_ref(
              method(:UserEditHandler),
              "boolean (map <string, any>)"
            ),
            # translators: command line help text for ad action
            "help"            => _(
              "Edit an existing user"
            ),
            "options"         => ["non_strict"],
            # help text for unknown parameter name
            "non_strict_help" => _(
              "Additional (LDAP) user parameters"
            )
          },
          "delete" => {
            "handler" => fun_ref(
              method(:UserDeleteHandler),
              "boolean (map <string, any>)"
            ),
            # translators: command line help text for delete action
            "help"    => _(
              "Delete an existing user (home directory is not removed)"
            )
          }
        },
        "options"    => {
          "local"         => {
            # translators: command line help text for list local option
            "help" => _(
              "List of local users"
            )
          },
          "system"        => {
            # translators: command line help text for list system option
            "help" => _(
              "List of system users"
            )
          },
          "ldap"          => {
            # translators: command line help text for list ldap option
            "help" => _(
              "List of LDAP users"
            )
          },
          "nis"           => {
            # translators: command line help text for list nis option
            "help" => _(
              "List of NIS users"
            )
          },
          "uid"           => {
            # translators: command line help text for uid option
            "help" => _(
              "UID of the user"
            ),
            "type" => "string"
          },
          "gid"           => {
            # translators: command line help text for add/gid option
            "help" => _(
              "GID of user's default group"
            ),
            "type" => "string"
          },
          "username"      => {
            # translators: command line help text for username option
            "help" => _(
              "Login name of the user"
            ),
            "type" => "string"
          },
          "cn"            => {
            # translators: command line help text for add option
            "help" => _(
              "Full name of the user"
            ),
            "type" => "string"
          },
          "shell"         => {
            # translators: command line help text for shell option
            "help" => _(
              "Login shell of the user"
            ),
            "type" => "string"
          },
          "home"          => {
            # translators: command line help text for home option
            "help" => _(
              "Home directory of the user"
            ),
            "type" => "string"
          },
          "no_home"       => {
            # translators: command line help text for add + create_home option
            "help" => _(
              "Do not create home directory for new user"
            )
          },
          "delete_home"   => {
            # translators: command line help text for delete_home option
            "help" => _(
              "Also delete user's home directory"
            )
          },
          "password"      => {
            # translators: command line help text for add option
            "help" => _(
              "Password of the user"
            ),
            "type" => "string"
          },
          "grouplist"     => {
            # translators: command line help text for home option
            "help" => _(
              "List of groups of which the user is a member (separated by commas)"
            ),
            "type" => "string"
          },
          "type"          => {
            # translators: command line help text for show option
            "help" => _(
              "Type of the user (local, system, nis, ldap)"
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
          "new_username"  => {
            # translators: command line help text for new_username option
            "help" => _(
              "New login name of the user"
            ),
            "type" => "string"
          },
          "new_uid"       => {
            # translators: command line help text for new_uid option
            "help" => _(
              "New UID of the user"
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
          "show"   => ["uid", "username", "type"],
          "add"    => [
            "username",
            "uid",
            "cn",
            "password",
            "home",
            "no_home",
            "shell",
            "gid",
            "grouplist",
            "type",
            "ldap_password",
            "batchmode"
          ],
          "edit"   => [
            "username",
            "uid",
            "cn",
            "password",
            "home",
            "shell",
            "gid",
            "grouplist",
            "new_username",
            "new_uid",
            "type",
            "ldap_password",
            "batchmode"
          ],
          "delete" => [
            "username",
            "uid",
            "delete_home",
            "type",
            "ldap_password",
            "batchmode"
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

Yast::UsersClient.new.main
