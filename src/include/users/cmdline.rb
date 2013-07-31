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
  module UsersCmdlineInclude
    def initialize_users_cmdline(include_target)
      textdomain "users"

      Yast.import "CommandLine"
      Yast.import "Ldap"
      Yast.import "Users"
      Yast.import "UsersCache"
      Yast.import "UsersLDAP"
      Yast.import "UsersSimple"
      Yast.import "Report"
    end

    # --------------------------------------------------------------------------
    # --------------------------------- helper functions -----------------------

    # set LDAP admin password and read LDAP users and groups
    def bind_and_read_LDAP(options)
      options = deep_copy(options)
      pw = Ops.get_string(options, "ldap_password", "")
      if Users.LDAPAvailable && Users.LDAPNotRead
        if Ldap.bind_pass == nil
          if pw == "" && !Builtins.haskey(options, "batchmode")
            # password entering label
            pw = CommandLine.PasswordInput(_("LDAP Server Password:"))
          end
          Ldap.SetBindPassword(pw) 
          # TODO check bind...
        end
        error = UsersLDAP.ReadSettings
        if error != ""
          CommandLine.Print(error)
          return false
        end
        error = Users.ReadLDAPSet("Users")
        if error != ""
          CommandLine.Print(error)
          return false
        end
      end
      true
    end

    def convert_keys(input)
      input = deep_copy(input)
      ret = {}
      keys = {
        "username"                   => "uid",
        "password"                   => "userPassword",
        "home"                       => "homeDirectory",
        "shell"                      => "loginShell",
        "fullname"                   => "cn",
        "gid"                        => "gidNumber",
        "uid"                        => "uidNumber",
        "no_home"                    => "create_home",
        "groupname"                  => "cn",
        "new_username"               => "uid",
        "new_groupname"              => "cn",
        "new_uid"                    => "uidNumber",
        "new_gid"                    => "gidNumber",
        UsersLDAP.GetMemberAttribute => "userlist"
      }
      Builtins.foreach(input) do |key, value|
        new_key = Ops.get_string(keys, key, key)
        value = false if new_key == "create_home"
        if new_key == "gidNumber" && value != "" &&
            (Builtins.haskey(input, "username") || Builtins.haskey(input, "uid"))
          # check group existence!
          if !UsersCache.GIDExists(Builtins.tointeger(Convert.to_string(value)))
            next
          end
        end
        if new_key == "grouplist" && Ops.is_string?(value)
          value = Builtins.listmap(
            Builtins.splitstring(Convert.to_string(value), ",")
          ) { |g| { g => 1 } }
        end
        if new_key == "userlist" && Ops.is_string?(value)
          sep = ","
          if Builtins.issubstring(Convert.to_string(value), "=") #for DN
            sep = ":"
          end
          value = Builtins.listmap(
            Builtins.splitstring(Convert.to_string(value), sep)
          ) { |u| { u => 1 } }
        end
        next if new_key == "ldap_password"
        if key == "username" && Builtins.haskey(input, "new_username") ||
            key == "uid" && Builtins.haskey(input, "new_uid") ||
            key == "groupname" && Builtins.haskey(input, "new_groupname") ||
            key == "gid" && Builtins.haskey(input, "new_gid")
          next
        end
        Ops.set(ret, new_key, value)
      end
      deep_copy(ret)
    end

    # --------------------------------------------------------------------------
    # --------------------------------- cmd-line handlers for users ------------

    # List users
    # @return [Boolean] false
    def UsersListHandler(options)
      options = deep_copy(options)
      sets = []
      attributes = []
      amap = {}
      Builtins.foreach(options) do |key, val|
        if Builtins.contains(["local", "system", "ldap", "nis"], key)
          sets = Builtins.add(sets, key)
        else
          #	    attributes	= (list<string>) union (attributes, [type]);
          Ops.set(amap, key, val)
        end
      end
      sets = ["local"] if sets == []
      attributes = Builtins.maplist(convert_keys(amap)) { |k, val| k }
      if !Builtins.contains(attributes, "uid")
        attributes = Builtins.prepend(attributes, "uid")
      end

      Builtins.foreach(sets) do |type|
        if type == "nis" && Users.NISAvailable && Users.NISNotRead
          Users.ReadNewSet("nis")
        end
        if type == "ldap" && Users.LDAPAvailable && Users.LDAPNotRead
          Ldap.SetAnonymous(true)
          Users.ReadNewSet("ldap")
        end
        Builtins.foreach(
          Convert.convert(
            Users.GetUsers("uid", type),
            :from => "map",
            :to   => "map <string, map>"
          )
        ) do |uname, user|
          out = ""
          # FIXME when using convert_keys, the order is broken...
          Builtins.foreach(attributes) do |attr|
            if Builtins.haskey(user, attr)
              if Ops.is_string?(Ops.get(user, attr))
                out = Ops.add(Ops.add(out, Ops.get_string(user, attr, "")), " ")
              end
              if Ops.is_map?(Ops.get(user, attr))
                out = Ops.add(
                  Ops.add(
                    out,
                    Builtins.mergestring(
                      Builtins.maplist(Ops.get_map(user, attr, {})) { |k, v| k },
                      ","
                    )
                  ),
                  " "
                )
              end
            end
          end
          CommandLine.Print(out)
        end
      end
      false # do not call Write...
    end

    # Show one user information
    # @return [Boolean] false
    def UserShowHandler(options)
      options = deep_copy(options)
      user = {}
      uid = Builtins.tointeger(
        Ops.get_string(
          options,
          "uidNumber",
          Ops.get_string(options, "uid", "-1")
        )
      )
      username = Ops.get_string(options, "username", "")

      type = Ops.get_string(options, "type", "local")

      if type == "nis" && Users.NISAvailable && Users.NISNotRead
        Users.ReadNewSet("nis")
      end
      if type == "ldap" && Users.LDAPAvailable && Users.LDAPNotRead
        Ldap.SetAnonymous(true)
        Users.ReadNewSet("ldap")
      end

      if uid != -1 && uid != nil
        user = Users.GetUser(uid, "")
      elsif username != ""
        user = Users.GetUserByName(username, "")
      end
      if user == {}
        # error message
        CommandLine.Print(_("There is no such user."))
        return false
      end

      out = ""
      keys = {
        # label shown at command line (user attribute)
        "cn"            => _(
          "Full Name:"
        ),
        # label shown at command line (user attribute)
        "uid"           => _(
          "Login Name:"
        ),
        # label shown at command line (user attribute)
        "homeDirectory" => _(
          "Home Directory:"
        ),
        # label shown at command line (user attribute)
        "loginShell"    => _(
          "Login Shell:"
        ),
        # label shown at command line (user attribute)
        "uidNumber"     => _(
          "UID:"
        ),
        # label shown at command line (user attribute)
        "groupname"     => _(
          "Default Group:"
        ),
        # label shown at command line (user attribute)
        "grouplist"     => _(
          "List of Groups:"
        )
      }
      Builtins.foreach(user) do |key, value|
        key = Ops.get_string(keys, key, "")
        next if key == ""
        svalue = Builtins.sformat("%1", value)
        if Ops.is_map?(value)
          svalue = Builtins.mergestring(
            Builtins.maplist(
              Convert.convert(value, :from => "any", :to => "map <string, any>")
            ) { |k, v| k },
            ","
          )
        end
        CommandLine.Print(Builtins.sformat("%1\n\t%2", key, svalue))
      end

      false # do not call Write...
    end

    # Add user
    # @return [Boolean] false
    def UserAddHandler(options)
      options = deep_copy(options)
      if Ops.get_string(options, "username", "") == ""
        # error message
        CommandLine.Print(_("Enter a user name."))
        return false
      end

      user = convert_keys(options)
      type = Ops.get_string(user, "type", "local")
      if type == "ldap"
        return false if !bind_and_read_LDAP(options)
        if !Builtins.haskey(user, "sn")
          Ops.set(user, "sn", Ops.get_string(user, "uid", ""))
        end
      end

      Users.ResetCurrentUser

      if !Builtins.haskey(user, "userPassword") &&
          !Builtins.haskey(user, "batchmode")
        pw = ""
        i = 0
        while true
          # question on command line
          pw = CommandLine.PasswordInput(_("Password for New User:"))
          p2 = CommandLine.PasswordInput(
            # question on command line
            _("Confirm the password:")
          )
          if pw != p2
            if Ops.less_than(i, 2)
              # error message
              CommandLine.Print(_("Passwords do not match. Try again."))
              i = Ops.add(i, 1)
            else
              # error message
              CommandLine.Print(_("Passwords do not match. Exiting."))
              return false
            end
          else
            break
          end
        end
        Ops.set(user, "userPassword", pw)
      end
      error = UsersSimple.CheckPassword(
        Ops.get_string(user, "userPassword", ""),
        type
      )

      if error != ""
        CommandLine.Print(error)
        return false
      end

      error = Users.AddUser(user)

      if error != ""
        CommandLine.Print(error)
        return false
      end

      if Ops.get_string(user, "type", "local") == "ldap"
        Users.SubstituteUserValues
      end

      error = Users.CheckUser({})
      if error != ""
        CommandLine.Print(error)
        return false
      end

      Users.CommitUser
    end

    # Delete user
    # @return [Boolean] false
    def UserDeleteHandler(options)
      options = deep_copy(options)
      uid = Builtins.tointeger(
        Ops.get_string(
          options,
          "uidNumber",
          Ops.get_string(options, "uid", "-1")
        )
      )
      username = Ops.get_string(options, "username", "")
      delete_home = Builtins.haskey(options, "delete_home")

      type = Ops.get_string(options, "type", "local")
      return false if !bind_and_read_LDAP(options) if type == "ldap"
      if uid != -1 && uid != nil
        Users.SelectUser(uid)
      elsif username != ""
        Users.SelectUserByName(username)
        u = Users.GetCurrentUser
        if Ops.is_integer?(Ops.get(u, "uidNumber"))
          uid = Ops.get_integer(u, "uidNumber", -1)
        elsif Ops.is_string?(Ops.get(u, "uidNumber"))
          uid = Builtins.tointeger(Ops.get_string(u, "uidNumber", "-1"))
        end
      end
      if Users.GetCurrentUser == {}
        # error message
        CommandLine.Print(_("There is no such user."))
        return false
      end
      # if the user has log on system
      out = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat("ps --no-headers -u %1", uid)
        )
      )
      if Builtins.size(Ops.get_string(out, "stdout", "")) != 0
        # error popup
        Report.Error(
          _(
            "You can not delete this user, because the user is present.\nPlease log off the user first."
          )
        )
        return false
      end
      Users.DeleteUser(delete_home) && Users.CommitUser
    end

    # Edit user
    # @return [Boolean] false
    def UserEditHandler(options)
      options = deep_copy(options)
      uid = Builtins.tointeger(
        Ops.get_string(
          options,
          "uidNumber",
          Ops.get_string(options, "uid", "-1")
        )
      )
      username = Ops.get_string(options, "username", "")

      type = Ops.get_string(options, "type", "local")
      return false if !bind_and_read_LDAP(options) if type == "ldap"
      if uid != -1 && uid != nil
        Users.SelectUser(uid)
      elsif username != ""
        Users.SelectUserByName(username)
      end
      user = Users.GetCurrentUser
      if user == {}
        # error message
        CommandLine.Print(_("There is no such user."))
        return false
      end

      changes = convert_keys(options)
      if type == "ldap" && !Builtins.haskey(changes, "dn")
        Ops.set(changes, "dn", Ops.get_string(user, "dn", "")) 
        # for username changes...
      end
      error = Users.EditUser(
        Convert.convert(changes, :from => "map", :to => "map <string, any>")
      )
      if error != ""
        CommandLine.Print(error)
        return false
      end
      error = Users.CheckUser({})
      if error != ""
        CommandLine.Print(error)
        return false
      end
      Users.CommitUser
    end


    # --------------------------------------------------------------------------
    # --------------------------------- cmd-line handlers for groups -----------

    # List groups
    # @return [Boolean] false
    def GroupsListHandler(options)
      options = deep_copy(options)
      sets = []
      attributes = []
      amap = {}
      Builtins.foreach(options) do |key, val|
        if Builtins.contains(["local", "system", "ldap", "nis"], key)
          sets = Builtins.add(sets, key)
        else
          Ops.set(amap, key, val)
        end
      end
      sets = ["local"] if sets == []

      attributes = Builtins.maplist(convert_keys(amap)) { |k, val| k }
      if !Builtins.contains(attributes, "cn")
        attributes = Builtins.prepend(attributes, "cn")
      end
      if Builtins.contains(attributes, "userlist")
        attributes = Builtins.add(attributes, UsersLDAP.GetMemberAttribute)
      end

      Builtins.foreach(sets) do |type|
        if type == "nis" && Users.NISAvailable && Users.NISNotRead
          Users.ReadNewSet("nis")
        end
        if type == "ldap" && Users.LDAPAvailable && Users.LDAPNotRead
          Ldap.SetAnonymous(true)
          Users.ReadNewSet("ldap")
        end
        Builtins.foreach(
          Convert.convert(
            Users.GetGroups("cn", type),
            :from => "map",
            :to   => "map <string, map>"
          )
        ) do |name, group|
          out = ""
          Builtins.foreach(attributes) do |attr|
            if Builtins.haskey(group, attr)
              if Ops.is_string?(Ops.get(group, attr))
                out = Ops.add(
                  Ops.add(out, Ops.get_string(group, attr, "")),
                  " "
                )
              end
              if Ops.is_map?(Ops.get(group, attr))
                out = Ops.add(
                  Ops.add(
                    out,
                    Builtins.mergestring(
                      Builtins.maplist(Ops.get_map(group, attr, {})) { |k, v| k },
                      ","
                    )
                  ),
                  " "
                )
              end
            end
          end
          CommandLine.Print(out)
        end
      end
      false # do not call Write...
    end

    # Show one group information
    # @return [Boolean] false
    def GroupShowHandler(options)
      options = deep_copy(options)
      group = {}
      gid = Builtins.tointeger(
        Ops.get_string(
          options,
          "gidNumber",
          Ops.get_string(options, "gid", "-1")
        )
      )
      groupname = Ops.get_string(options, "groupname", "")

      type = Ops.get_string(options, "type", "local")

      if type == "nis" && Users.NISAvailable && Users.NISNotRead
        Users.ReadNewSet("nis")
      end
      if type == "ldap" && Users.LDAPAvailable && Users.LDAPNotRead
        Ldap.SetAnonymous(true)
        Users.ReadNewSet("ldap")
      end

      if gid != -1 && gid != nil
        group = Users.GetGroup(gid, "")
      elsif groupname != ""
        group = Users.GetGroupByName(groupname, "")
      end
      if group == {}
        # error message
        CommandLine.Print(_("There is no such group."))
        return false
      end

      out = ""
      keys = {
        # label shown at command line (user attribute)
        "cn"                         => _(
          "Group Name:"
        ),
        # label shown at command line (user attribute)
        "gidNumber"                  => _(
          "GID:"
        ),
        # label shown at command line (user attribute)
        "userlist"                   => _(
          "List of Members:"
        ),
        # label shown at command line (user attribute)
        UsersLDAP.GetMemberAttribute => _(
          "List of Members:"
        )
      }
      Builtins.foreach(group) do |key, value|
        key = Ops.get_string(keys, key, "")
        next if key == ""
        svalue = Builtins.sformat("%1", value)
        if Ops.is_map?(value)
          svalue = Builtins.mergestring(
            Builtins.maplist(
              Convert.convert(value, :from => "any", :to => "map <string, any>")
            ) { |k, v| k },
            ","
          )
        end
        CommandLine.Print(Builtins.sformat("%1\n\t%2", key, svalue))
      end

      false # do not call Write...
    end

    # Delete group
    # @return [Boolean] false
    def GroupDeleteHandler(options)
      options = deep_copy(options)
      gid = Builtins.tointeger(
        Ops.get_string(
          options,
          "gidNumber",
          Ops.get_string(options, "gid", "-1")
        )
      )
      groupname = Ops.get_string(
        options,
        "cn",
        Ops.get_string(options, "groupname", "")
      )

      type = Ops.get_string(options, "type", "local")
      return false if !bind_and_read_LDAP(options) if type == "ldap"
      if gid != -1 && gid != nil
        Users.SelectGroup(gid)
      elsif groupname != ""
        Users.SelectGroupByName(groupname)
      end
      if Users.GetCurrentGroup == {}
        # error message
        CommandLine.Print(_("There is no such group."))
        return false
      end
      Users.DeleteGroup && Users.CommitGroup
    end

    # Add group
    # @return [Boolean] false
    def GroupAddHandler(options)
      options = deep_copy(options)
      if Ops.get_string(options, "groupname", "") == ""
        # error message
        CommandLine.Print(_("Enter a group name."))
        return false
      end

      group = convert_keys(options)
      type = Ops.get_string(group, "type", "local")
      return false if !bind_and_read_LDAP(options) if type == "ldap"
      member_attr = type == "ldap" ? UsersLDAP.GetMemberAttribute : "userlist"
      if Builtins.haskey(group, "userlist")
        if type == "ldap"
          Ops.set(group, member_attr, Ops.get_map(group, "userlist", {}))
          group = Builtins.remove(group, "userlist")
        end
      else
        Ops.set(group, member_attr, {})
      end

      Users.ResetCurrentGroup
      error = Users.AddGroup(group)

      if error != ""
        CommandLine.Print(error)
        return false
      end

      if Ops.get_string(group, "type", "local") == "ldap"
        Users.SubstituteGroupValues
      end

      error = Users.CheckGroup({})
      if error != ""
        CommandLine.Print(error)
        return false
      end
      Users.CommitGroup
    end

    # Edit group
    # @return [Boolean] false
    def GroupEditHandler(options)
      options = deep_copy(options)
      gid = Builtins.tointeger(
        Ops.get_string(
          options,
          "gidNumber",
          Ops.get_string(options, "gid", "-1")
        )
      )
      groupname = Ops.get_string(
        options,
        "cn",
        Ops.get_string(options, "groupname", "")
      )

      type = Ops.get_string(options, "type", "local")
      return false if !bind_and_read_LDAP(options) if type == "ldap"
      if gid != -1 && gid != nil
        Users.SelectGroup(gid)
      elsif groupname != ""
        Users.SelectGroupByName(groupname)
      end
      group = Users.GetCurrentGroup
      if group == {}
        # error message
        CommandLine.Print(_("There is no such group."))
        return false
      end

      changes = convert_keys(options)
      if type == "ldap" && !Builtins.haskey(changes, "dn")
        Ops.set(changes, "dn", Ops.get_string(group, "dn", "")) 
        # for groupname changes...
      end
      if type == "ldap" && Builtins.haskey(changes, "userlist")
        Ops.set(
          changes,
          UsersLDAP.GetMemberAttribute,
          Ops.get_map(changes, "userlist", {})
        )
        changes = Builtins.remove(changes, "userlist")
      end
      error = Users.EditGroup(
        Convert.convert(changes, :from => "map", :to => "map <string, any>")
      )
      if error != ""
        CommandLine.Print(error)
        return false
      end
      error = Users.CheckGroup({})
      if error != ""
        CommandLine.Print(error)
        return false
      end
      Users.CommitGroup
    end

    # --------------------------------------------------------------------------
    # --------------------------------- common cmd-line handlers ---------------


    def UsersRead
      Users.SetGUI(false)
      Users.Read == ""
    end

    def UsersWrite
      Users.SetGUI(false)
      error = Users.Write
      if error != ""
        CommandLine.Print(error)
        return false
      end
      true
    end

    def UsersGUI
      UsersSequence(Users.GetStartDialog) == :next
    end
  end
end
