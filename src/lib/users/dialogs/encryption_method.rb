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

require "yast"
require "ui/installation_dialog"
require "users/encryption_method"
Yast.import "UsersSimple"

module Yast
  # This dialog allows the user to select an encryption method for all user passwords
  class EncryptionMethodDialog < ::UI::InstallationDialog
    def initialize
      super
      textdomain "users"
    end

    def next_handler
      id = UI.QueryWidget(Id(:encryption_method), :CurrentButton)
      method = ::Users::EncryptionMethod.new(id)
      method.set_as_current
      super
    end

    def help_text
      help = _("<p>Choose a password encryption method for local and system users.</p>")
      # TRANSLATORS: %s is the name of the recommended encryption method
      help += _(
        "<p><b>%s</b> is the current standard hash method. Using other " \
        "algorithms is not recommended unless needed for compatibility purposes.</p>"
      ) % ::Users::EncryptionMethod.default.label
      help
    end

  protected

    def dialog_content
      VBox(
        VStretch(),
        HSquash(
          RadioButtonGroup(
            Id(:encryption_method),
            VBox(*method_widgets)
          )
        ),
        VStretch()
      )
    end

    def method_widgets
      ::Users::EncryptionMethod.all.each_with_object([]) do |meth, res|
        res << Left(RadioButton(Id(meth.id), meth.label, meth.current?))
        # Let's add some vertical space after each widget
        res << VSpacing(1)
      end
    end

    def dialog_title
      _("Password Encryption Type")
    end

    def title_icon
      "yast-users"
    end
  end
end
