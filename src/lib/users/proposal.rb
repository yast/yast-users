# Copyright (c) 2016 SUSE LLC.
#  All Rights Reserved.

#  This program is free software; you can redistribute it and/or
#  modify it under the terms of version 2 or 3 of the GNU General
#  Public License as published by the Free Software Foundation.

#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
#  GNU General Public License for more details.

#  You should have received a copy of the GNU General Public License
#  along with this program; if not, contact SUSE LLC.

#  To contact SUSE about this file by physical or electronic mail,
#  you may find current contact information at www.suse.com

require "installation/proposal_client"
require "users/encryption_method"

module Users
  # Default proposal for the users YaST module
  class Proposal < ::Installation::ProposalClient
    include Yast::I18n
    include Yast::Logger

    def initialize
      Yast.import "Wizard"
      Yast.import "Mode"
      textdomain "users"
    end

    def make_proposal(_attrs)
      if Mode.auto
        {
          "preformatted_proposal" => HTML.List([users_ay]),
          "language_changed"      => false,
          "links"                 => []
        }
      else
        {
          "preformatted_proposal" => HTML.List([users_proposal, root_proposal, encrypt_proposal]),
          "language_changed"      => false,
          "links"                 => ["users--user", "users--root", "users--encryption"]
        }
      end
    end

    def ask_user(param)
      args = {
        "enable_back" => true,
        "enable_next" => param.fetch("has_next", false),
        "going_back"  => true
      }

      Wizard.OpenAcceptDialog

      case param["chosen_id"]
      when "users--root"
        UsersSimple.SkipRootPasswordDialog(false) # do not skip now...
        client = "inst_root_first"
      when "users" || "users--user"
        args["root_dialog_follows"] = false
        client = "inst_user_first"
      when "users--encryption"
        client = "users_encryption_method"
      else
        raise "Unknown action id: #{param['chosen_id']}"
      end

      result = WFM.CallFunction(client, [args])

      Wizard.CloseDialog

      log.info "Returning from users proposal ask_user with #{result}"
      { "workflow_sequence" => result }
    end

    def description
      menu = []
      id = ""

      if !Mode.auto
        menu = [ # menu button label
          { "id" => "users--user", "title" => _("&User") },
          # menu button label
          { "id" => "users--root", "title" => _("&Root Password") },
          # menu button label
          { "id" => "users--encryption", "title" => _("Password &Encryption Type") }]
        id = "users"
      end

      {
        "id"              => id,
        # rich text label
        "rich_text_title" => _("User Settings"),
        "menu_titles"     => menu
      }
    end

  private

    def users_ay
      export = Users.Export()
      ret = _("Number of defined users/groups:")
      ret += "<ul>\n<li>" + format(_("Users: %d"), export["users"].count()) + "</li>\n"
      ret += "<li>" + format(_("Groups: %d"), export["groups"].count()) + "</li></ul>"
      ret
    end

    def root_proposal
      msg = if UsersSimple.GetRootPassword != ""
        # TRANSLATORS: summary label <%1>-<%2> are HTML tags, leave untouched
        _("<%1>Root Password<%2> set")
      else
        # TRANSLATORS: summary label <%1>-<%2> are HTML tags, leave untouched
        _("<%1>Root Password<%2> not set")
      end
      Builtins.sformat(msg, "a href=\"users--root\"", "/a")
    end

    def users_proposal
      href = "\"users--user\""
      ahref = "a href=#{href}"
      # summary label <%1>-<%2> are HTML tags, leave untouched
      prop = Builtins.sformat(_("No <%1>user<%2> configured"), ahref, "/a")
      users = UsersSimple.GetUsers
      user = users.first || {}
      if users.size > 1 || !user["__imported"].nil?
        # TRANSLATORS: summary line, %d is the number of users
        prop = format(
          n_(
            "<a href=%s>%d user</a> will be imported", "<a href=%s>%d users</a> will be imported",
            users.size
          ), href, users.size
        )
      elsif user.fetch("uid", "") != ""
        # TRANSLATORS: summary line: <%1>-<%2> are HTML tags, leave untouched,
        # %3 is login name
        prop = Builtins.sformat(
          _("<%1>User<%2> %3 configured"),
          ahref,
          "/a",
          user.fetch("uid", "")
        )
        if user.fetch("cn", "") != ""
          # summary line: <%1>-<%2> are HTML tags, leave untouched,
          # %3 is full name, %4 login name
          prop = Builtins.sformat(
            _("<%1>User<%2> %3 (%4) configured"),
            ahref,
            "/a",
            user.fetch("cn", ""),
            user.fetch("uid", "")
          )
        end
      end

      prop
    end

    def encrypt_proposal
      # TRANSLATORS: summary line. Second %s is the name of the method
      format(_("Password Encryption Method: <a href=%s>%s</a>"),
        "users--encryption", ::Users::EncryptionMethod.current.label)
    end
  end
end
