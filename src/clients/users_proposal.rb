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

# File:		users_proposal.ycp
# Author:		Jiri Suchomel <jsuchome@suse.cz>
# Purpose:		Proposal for user and root setting
#
# $Id$
module Yast
  class UsersProposalClient < Client
    def main
      textdomain "users"

      Yast.import "HTML"
      Yast.import "UsersSimple"
      Yast.import "Wizard"

      @func = Convert.to_string(WFM.Args(0))
      @param = Convert.to_map(WFM.Args(1))
      @ret = {}

      @auth2label = {
        # authentication type
        "ldap"      => _("LDAP"),
        # authentication type
        "nis"       => _("NIS"),
        # authentication type
        "samba"     => _("Samba (Windows Domain)"),
        # authentication type
        "edir_ldap" => _("eDirectory LDAP")
      }

      @encoding2label = {
        # encryption type
        "des"    => _("DES"),
        # encryption type
        "md5"    => _("MD5"),
        # encryption type
        "sha256" => _("SHA-256"),
        # encryption type
        "sha512" => _("SHA-512")
      }


      if @func == "MakeProposal"
        @force_reset = Ops.get_boolean(@param, "force_reset", false)

        @root_proposal = UsersSimple.GetRootPassword != "" ?
          # summary label <%1>-<%2> are HTML tags, leave untouched
          Builtins.sformat(
            _("<%1>Root Password<%2> set"),
            "a href=\"users--root\"",
            "/a"
          ) :
          Builtins.sformat(
            _("<%1>Root Password<%2> not set"),
            "a href=\"users--root\"",
            "/a"
          )

        @ahref = "a href=\"users--user\""
        # summary label <%1>-<%2> are HTML tags, leave untouched
        @prop = Builtins.sformat(_("No <%1>user<%2> configured"), @ahref, "/a")
        @auth_method = UsersSimple.AfterAuth
        @users = Convert.convert(
          UsersSimple.GetUsers,
          :from => "list",
          :to   => "list <map>"
        )
        @user = Ops.get(@users, 0, {})
        if @auth_method != "users"
          # summary line: <%1>-<%2> are HTML tags, leave untouched,
          # % is LDAP/NIS etc.
          @prop = Builtins.sformat(
            _("<%1>Authentication method<%2>: %3"),
            @ahref,
            "/a",
            Ops.get_string(@auth2label, @auth_method, @auth_method)
          )
          if UsersSimple.KerberosConfiguration
            # summary line: <%1>-<%2> are HTML tags, leave untouched,
            # % is LDAP/NIS etc.
            @prop = Builtins.sformat(
              _("<%1>Authentication method<%2>: %3 and Kerberos."),
              @ahref,
              "/a",
              Ops.get_string(@auth2label, @auth_method, @auth_method)
            )
          end
        elsif Ops.greater_than(Builtins.size(@users), 1) ||
            Ops.get(@user, "__imported") != nil
          @to_import = Builtins.maplist(@users) do |u|
            Ops.get_string(u, "uid", "")
          end
          # summary line, %3 are user names (comma separated)
          # <%1>,<%2> are HTML tags, leave untouched,
          @prop = Builtins.sformat(
            _("<%1>Users<%2> %3 selected for import"),
            @ahref,
            "/a",
            Builtins.mergestring(@to_import, ",")
          )
          if Builtins.size(@to_import) == 1
            # summary line,  <%1>,<%2> are HTML tags, %3 user name
            @prop = Builtins.sformat(
              _("<%1>User<%2> %3 will be imported."),
              @ahref,
              "/a",
              Ops.get(@to_import, 0, "")
            )
          end
        elsif Ops.get_string(@user, "uid", "") != ""
          # summary line: <%1>-<%2> are HTML tags, leave untouched,
          # %3 is login name
          @prop = Builtins.sformat(
            _("<%1>User<%2> %3 configured"),
            @ahref,
            "/a",
            Ops.get_string(@user, "uid", "")
          )
          if Ops.get_string(@user, "cn", "") != ""
            # summary line: <%1>-<%2> are HTML tags, leave untouched,
            # %3 is full name, %4 login name
            @prop = Builtins.sformat(
              _("<%1>User<%2> %3 (%4) configured"),
              @ahref,
              "/a",
              Ops.get_string(@user, "cn", ""),
              Ops.get_string(@user, "uid", "")
            )
          end
        end
        @rest = ""
        # only show in summary if non-default method is used
        if UsersSimple.EncryptionMethod != "sha512"
          # summary line
          @rest = Builtins.sformat(
            _("Password Encryption Method: %1"),
            Ops.get(@encoding2label, UsersSimple.EncryptionMethod, "")
          )
        end
        @ret = {
          "preformatted_proposal" => @rest == "" ?
            HTML.List([@prop, @root_proposal]) :
            HTML.List([@prop, @root_proposal, @rest]),
          "language_changed"      => false,
          "links"                 => ["users--user", "users--root"]
        }
      elsif @func == "Description"
        @ret = {
          # rich text label
          "rich_text_title" => _("User Settings"),
          "menu_titles"     => [
            # menu button label
            { "id" => "users--user", "title" => _("&User") },
            # menu button label
            { "id" => "users--root", "title" => _("&Root Password") }
          ],
          "id"              => "users"
        }
      elsif @func == "AskUser"
        Wizard.OpenAcceptDialog
        @args = {
          "enable_back" => true,
          "enable_next" => Ops.get_boolean(@param, "has_next", false)
        }
        @result = :back
        if Ops.get_string(@param, "chosen_id", "") == "users--root"
          UsersSimple.SkipRootPasswordDialog(false) # do not skip now...
          @result = Convert.to_symbol(
            WFM.CallFunction("inst_root_first", [@args])
          )
        else
          Ops.set(@args, "root_dialog_follows", false)
          @result = Convert.to_symbol(
            WFM.CallFunction("inst_user_first", [@args])
          )
        end

        Wizard.CloseDialog

        @ret = { "workflow_sequence" => @result }
        Builtins.y2debug(
          "Returning from users_proposal AskUser() with: %1",
          @ret
        )
      end
      deep_copy(@ret)
    end
  end
end

Yast::UsersProposalClient.new.main
