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

require "y2users/validation_config"

module Y2Users
  # Mixin to centralize some help texts
  #
  # This may disappear in the future, but it's needed during the process of
  # moving stuff to the Y2Users namespace
  module HelpTexts
    include Yast::I18n
    Yast.import "UsersSimple"

    # Needed to be able to call textdomain below
    extend Yast::I18n

    def self.included(_mod)
      # Needed to prevent the automatic checks (rake check:pot) from complaining
      textdomain "users"
    end

    # Configuration of the validation process
    #
    # @return [Y2Users::ValidationConfig]
    def validation_config
      @validation_config ||= Y2Users::ValidationConfig.new
    end

    # Text describing the characters accepted as part of a password
    #
    # @return [String] formatted and localized text
    def valid_password_text
      Yast::UsersSimple.ValidPasswordHelptext
    end

    # Text about the CA constraints, if applicable
    #
    # @return [String] formatted and localized text if feature is enabled, empty string otherwise
    def ca_password_text
      return "" unless validation_config.check_ca?

      format(
        _(
          "<p>If you intend to use this password for creating certificates,\n" \
          "it has to be at least %s characters long.</p>"
        ),
        validation_config.ca_min_password_length
      )
    end
  end
end
