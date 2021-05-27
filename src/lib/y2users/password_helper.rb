# Copyright (c) [2021] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "y2users"
require "y2users/users_simple"

Yast.import "UI"
Yast.import "Popup"
Yast.import "Report"

module Y2Users
  # Mixin for holding helper methods related to the user password.
  #
  # To be used by UI components like widgets and dialogs since methods might take care of querying
  # an input value, reporting an error to the user, setting the focus, etc.
  module PasswordHelper
    # Needed to be able to call textdomain below
    extend Yast::I18n

    def self.included(_mod)
      textdomain "users"
    end

    # Checks whether the entered password is acceptable, reporting fatal problems to the user and
    # asking for confirmation for the non-fatal ones
    #
    # @param user [Y2Users::User]
    # @return [Boolean]
    def valid_password_for?(user)
      issues = user.password_issues
      return true if issues.empty?

      Yast::UI.SetFocus(Id(:pw1))

      fatal = issues.find(&:fatal?)
      if fatal
        Yast::Report.Error(fatal.message)
        return false
      end

      message = issues.map(&:message).join("\n\n") + "\n\n" + _("Really use this password?")
      Yast::Popup.YesNo(message)
    end
  end
end
