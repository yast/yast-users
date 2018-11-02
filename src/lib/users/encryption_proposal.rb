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
  # Minimal proposal displaying only the password encryption method
  class EncryptionProposal < ::Installation::ProposalClient
    include Yast::I18n
    include Yast::Logger

    def initialize
      Yast.import "Wizard"
      textdomain "users"
    end

    def make_proposal(_attrs)
      # TRANSLATORS: summary line. Second %s is the name of the method
      text = _("Encryption Method: <a href=%s>%s</a>") %
        ["users--encryption", ::Users::EncryptionMethod.current.label]
      {
        "links"        => ["users--encryption"],
        "raw_proposal" => [text]
      }
    end

    def ask_user(param)
      args = {
        "enable_back" => true,
        "enable_next" => param.fetch("has_next", false),
        "going_back"  => true
      }
      begin
        Yast::Wizard.OpenAcceptDialog
        result = WFM.CallFunction("users_encryption_method", [args])
      ensure
        Yast::Wizard.CloseDialog
      end
      log.info "Returning from users_encryption ask_user with #{result}"
      { "workflow_sequence" => result }
    end

    def description
      {
        "id"              => "users_encryption",
        # TRANSLATORS: rich text label
        "rich_text_title" => _("Password Encryption Type"),
        "menu_titles"     => [
          # TRANSLATORS: menu button label
          { "id" => "users--encryption", "title" => _("Password &Encryption Type") }
        ]
      }
    end
  end
end
