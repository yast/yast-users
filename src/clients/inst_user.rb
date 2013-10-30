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

# Module:      inst_user.ycp
#
# Authors:     Klaus Kaempf <kkaempf@suse.de>
#              Stefan Hundhammer <sh@suse.de>
#              Jiri Suchomel <jsuchome@suse.cz>
#
# Purpose:     Start user management module from within installation workflow
#
# $Id$
module Yast
  class InstUserClient < Client
    def main
      Yast.import "UI"

      textdomain "users"

      Yast.import "Autologin"
      Yast.import "Directory"
      Yast.import "FileUtils"
      Yast.import "GetInstArgs"
      Yast.import "Package"
      Yast.import "Label"
      Yast.import "Ldap"
      Yast.import "Progress"
      Yast.import "Users"
      Yast.import "UsersCache"
      Yast.import "UsersSimple"
      Yast.import "Wizard"

      Yast.include self, "users/wizards.rb"
      # create_users()
      Yast.include self, "users/routines.rb"

      @ret = :back
      @importing = false
      @users = []
      @user = {}

      if UsersSimple.UserCreationSkipped
        Builtins.y2milestone("preconfigured user already written...")
        return :auto
      end
      if !GetInstArgs.going_back
        Users.ReadSystemDefaults(false)
        UsersSimple.Read(false)
        Users.SetEncryptionMethod(UsersSimple.EncryptionMethod)
        @users = Convert.convert(
          UsersSimple.GetUsers,
          :from => "list",
          :to   => "list <map>"
        )
        @user = UsersSimple.GetUser
        if Ops.greater_than(Builtins.size(@users), 1) ||
            Ops.get(@user, "__imported") != nil
          Users.SetUsersForImport(@users)
          @importing = true
          @import_dir = Ops.add(Directory.vardir, "/imported/userdata/etc")
          Builtins.foreach(["/passwd", "/shadow", "/group"]) do |file|
            SCR.Execute(path(".target.remove"), Ops.add(@import_dir, file))
          end
        end
      end

      # what to call after inst_auth dialog
      @client = UsersSimple.AfterAuth

      # check if the user was configured in the 1st stage
      if !GetInstArgs.going_back && @client == "users" && @user != {} &&
          !@importing
        Builtins.y2milestone("user defined in 1st stage, let's save now...")
        @progress_orig = Progress.set(false)
        Users.Read

        # now, check if home directory exists and adapt uidnumber to its owner
        @home = Ops.get_string(@user, "home", "")
        if @home == "" && Ops.get_string(@user, "uid", "") != ""
          @home = Ops.add(
            Users.GetDefaultHome("local"),
            Ops.get_string(@user, "uid", "")
          )
        end
        if @home != "" && FileUtils.IsDirectory(@home) == true
          @stat = Convert.to_map(SCR.Read(path(".target.stat"), @home))
          @uid = Ops.get_integer(@stat, "uid", -1)
          Ops.set(@user, "uidNumber", @uid) if @uid != -1
        end
        @error = Users.AddUser(@user)
        @error = Users.CheckUser({}) if @error == ""
        if @error == "" && Users.CommitUser
          if UsersSimple.AutologinUsed
            Autologin.user = UsersSimple.GetAutologinUser
            Autologin.used = true
            Autologin.modified = true
          end
          @root_alias = UsersSimple.GetRootAlias
          Users.AddRootAlias(@root_alias) if @root_alias != ""
          @error = Users.Write
          UsersSimple.SetUser({})
        end
        if @error != ""
          Builtins.y2error("error while creating user: %1", @error)
        end
        Progress.set(@progress_orig)
        UsersSimple.RemoveUserData
        UsersSimple.SkipUserCreation(true)
        return :next
      end
      Wizard.CreateDialog if Mode.normal # for testing only

      if !GetInstArgs.going_back && @client == "users" &&
          UsersSimple.UsersWritten
        Builtins.y2milestone("users already written, going next")
        return :next
      end
      # dialog caption
      @caption = _("User Authentication Method")

      if !@importing
        Wizard.SetContents(
          @caption,
          Empty(),
          # help text (shown in the 'busy' situation)
          _("Initialization of module for configuration of authentication..."),
          GetInstArgs.enable_back,
          GetInstArgs.enable_next
        )
      end

      if @client != "users"
        # going back from next step, while kerberos was already configured
        if UsersSimple.KerberosConfiguration && GetInstArgs.going_back &&
            Package.Installed("yast2-kerberos-client")
          @ret = Convert.to_symbol(
            WFM.CallFunction("kerberos-client", WFM.Args)
          )
          return @ret if @ret == :next
        end

        @package = Builtins.sformat("yast2-%1-client", @client)
        # name of client to call
        @call_client = {
          "samba"     => "samba-client",
          "edir_ldap" => "linux-user-mgmt"
        }
        @package = "yast2-linux-user-mgmt" if @client == "edir_ldap"
        if !Package.InstallAllMsg(
            [@package],
            # popup label (%1 is package to install)
            Builtins.sformat(
              _("Package %1 is not installed.\nInstall it now?\n"),
              @package
            )
          )
          return :back
        end

        # when we go `back from kerberos, call previous client again
        @again = true
        while @again
          @again = false
          @ret = Convert.to_symbol(
            WFM.CallFunction(
              Ops.get_string(@call_client, @client, @client),
              WFM.Args
            )
          )

          # after nis/ldap/edit client was called, maybe call also kerberos
          if @ret == :next && UsersSimple.KerberosConfiguration &&
              Package.InstallAllMsg(
                ["yast2-kerberos-client"],
                # popup label (%1 is package to install)
                Builtins.sformat(
                  _("Package %1 is not installed.\nInstall it now?\n"),
                  "yast2-kerberos-client"
                )
              )
            @ret = Convert.to_symbol(
              WFM.CallFunction("kerberos-client", WFM.Args)
            )
            @again = true if @ret == :back
          end
        end

        if @ret == :next && @client == "ldap" && Ldap.initial_defaults_used
          # continue with users...
          UsersSimple.SetAfterAuth("users")
          Builtins.y2milestone(
            "calling users module to enable creating LDAP user..."
          )
        else
          # make it possible to skip authentication step (bnc#678650)
          if @ret == :abort || @ret == :cancel
            Builtins.y2milestone("called client aborted, skipping the step")
            @ret = :next
          end
          return @ret
        end
      end
      @import_u = Users.GetUsersForImport
      if Ops.greater_than(Builtins.size(@import_u), 0)
        if GetInstArgs.going_back
          Users.SetUsersForImport([])
          return :back
        end
        ReadDialog(false) # clear the cache from imported data
        Users.ResetCurrentUser
        Builtins.y2milestone("There are some users to import")

        create_users(@import_u)

        WriteDialog(false)
        @ret = :auto
      else
        # else run the users module
        Builtins.y2milestone(
          "Starting user management module with parameters %1",
          GetInstArgs.argmap
        )

        UsersCache.SetCurrentSummary("users")
        Users.SetStartDialog("user_inst_start")
        @ret = UsersSequence("user_inst_start")

        Builtins.y2milestone("User management module returned %1", @ret)
      end

      if @ret == nil
        Builtins.y2warning("UsersSequence returns null!")
        @ret = :auto
      end
      UsersSimple.RemoveUserData if @ret == :next
      Wizard.CloseDialog if Mode.normal
      @ret
    end
  end
end

Yast::InstUserClient.new.main
