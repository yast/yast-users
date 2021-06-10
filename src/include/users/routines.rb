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

require "shellwords"

module Yast
  module UsersRoutinesInclude
    def initialize_users_routines(include_target)
      Yast.import "Mode"
      Yast.import "Autologin"

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
      out = SCR.Execute(
        path(".target.bash_output"),
        "/usr/bin/ps --no-headers -u #{name.shellescape}"
      )
      output = Ops.get_string(out, "stdout", "")
      Builtins.size(output) != 0 && !Mode.config
    end
  end
end
