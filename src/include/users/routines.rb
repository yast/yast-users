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

# File:	include/users/wizards.ycp
# Package:	Configuration of users and groups
# Summary:	Wizards definitions
# Authors:	Johannes Buchhold <jbuch@suse.de>,
#          Jiri Suchomel <jsuchome@suse.cz>
#
# $Id$
module Yast
  module UsersRoutinesInclude
    def initialize_users_routines(include_target)
      Yast.import "Mode"

      textdomain "users"
    end

    # check if this is installation stage -
    # adding user during firstboot should be same as during 2nd stage
    def installation
      Stage.cont || Stage.firstboot
    end

    # helper function: return the 'any' value as integer
    def GetInt(value, default_value)
      value = deep_copy(value)
      return default_value if value == nil
      return Convert.to_integer(value) if Ops.is_integer?(value)
      if Ops.is_string?(value) && !value.empty?
        return value.to_i
      end
      default_value
    end

    # helper function: return the 'any' value as string
    def GetString(value, default_value)
      value = deep_copy(value)
      return default_value if value == nil
      Builtins.sformat("%1", value)
    end


    # Split cn (fullname) in forename and surname.
    # @param [Symbol] what `surname or `forename
    # @param [String] cn fullname
    # @param type user type
    # @return [String] selected part of user name
    def SplitFullName(what, cn)
      cn = "" if cn == nil

      # if cn is to be substituted, do not try to resolve givenName/sn
      return "" if Builtins.issubstring(cn, "%")

      strs = Builtins.splitstring(cn, " ")
      i = 1
      sn = ""
      givenName = ""

      Builtins.foreach(strs) do |str|
        if Ops.less_than(i, Builtins.size(strs))
          if givenName == ""
            givenName = str
          else
            givenName = Ops.add(Ops.add(givenName, " "), str)
          end
        else
          sn = str
        end
        i = Ops.add(i, 1)
      end
      return sn if what == :sn
      return givenName if what == :givenName

      nil
    end

    # if the user has log on system
    def UserLogged(name)
      out = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat("ps --no-headers -u %1", name)
        )
      )
      proc = Ops.get_string(out, "stdout", "")
      Builtins.size(proc) != 0 && !Mode.config
    end
  end

  # create users from a list
  def create_users(users)
    users.each do |user|
      # check if default group exists
      if user.has_key?("gidNumber")
        g = Users.GetGroup(GetInt(Ops.get(user, "gidNumber"), -1), "")
        if g.empty?
          g = Users.GetGroupByName(user["groupname"]),
          if g.empty?
            user = Builtins.remove(user, "gidNumber")
          else
            user["gidNumber"] = g["gidNumber"]
          end
        end
      end

      error = Users.AddUser(user)

      if error.empty?
        # empty hash means the user added by Users.AddUser call before
        error = Users.CheckUser({})
      end

      if error.empty?
        Users.CommitUser
      else
        Builtins.y2error("error while adding user: #{error}")
        Users.ResetCurrentUser
      end
    end
  end

  # setup ALL users (included root user, autologin, root aliases,...)
  # Return: true if there has been added a user
  def setup_all_users
    ret = false

    # disable UI (progress)
    old_gui = Users.GetGUI
    Users.SetGUI(false)

    # Users.Read has to be called in order to initialize the user hash
    # in the Users module. This is needed for establishing
    # the system users (espl. the root user). (bnc#893725)
    Users.Read
    Users.ResetCurrentUser
    # resetting Autologin settings
    Autologin.Disable

    users = UsersSimple.GetUsers

    if !users.empty?

      Builtins.y2milestone("There are #{users.size} users to import")
      create_users(users)

      if UsersSimple.AutologinUsed
        Autologin.user = UsersSimple.GetAutologinUser
        Autologin.Use(true)
      end

      root_alias = UsersSimple.GetRootAlias
      Users.AddRootAlias(root_alias) unless root_alias.empty?
      ret = true
    end
    Users.SetGUI(old_gui)
    ret
  end

end
