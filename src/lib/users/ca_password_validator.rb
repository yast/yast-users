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
Yast.import "ProductFeatures"

module Users
  # Validator to check if a password fulfills the requirements to
  # generate CAs (see FATE#300438)
  class CAPasswordValidator
    MIN_LENGTH = 4
    private_constant :MIN_LENGTH

    include Yast::I18n

    def initialize
      textdomain "users"
    end

    # Returns whether YaST should check CA constraints
    #
    # See installation control file: globals->root_password_ca_check
    #
    # @return [Boolean] whether to check the constraints
    def enabled?
      !!Yast::ProductFeatures.GetBooleanFeature("globals", "root_password_ca_check")
    end

    # List of errors found for a given password
    #
    # The errors are localized and ready to be displayed to the user
    #
    # @param passwd [String] password to check
    # @return [Array<String>] errors or empty array if no errors are found or
    #       validation is disabled
    def errors_for(passwd)
      if !enabled? || passwd.size >= MIN_LENGTH
        []
      else
        [
          _(
            "If you intend to create certificates,\n" \
            "the password should have at least %s characters."
          ) % MIN_LENGTH
        ]
      end
    end

    # Localized help text about CA constraints
    #
    # @return [String] html text or empty string if validation is disabled
    def help_text
      if enabled?
        _(
          "<p>If you intend to use this password for creating certificates,\n" \
          "it has to be at least %s characters long.</p>"
        ) % MIN_LENGTH
      else
        ""
      end
    end
  end
end
