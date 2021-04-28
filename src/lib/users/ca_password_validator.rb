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
require "y2users/validation_config"

module Users
  # Validator to check if a password fulfills the requirements to
  # generate CAs (see FATE#300438)
  #
  # NOTE: very likely this class will be merged into Y2Users::PasswordValidator
  class CAPasswordValidator
    include Yast::I18n

    def initialize
      textdomain "users"
    end

    # List of errors found for a given password
    #
    # The errors are localized and ready to be displayed to the user
    #
    # @param passwd [String] password to check
    # @return [Array<String>] errors or empty array if no errors are found or
    #       validation is disabled
    def errors_for(passwd)
      if !config.check_ca? || passwd.size >= config.ca_min_password_length
        []
      else
        [
          _(
            "If you intend to create certificates,\n" \
            "the password should have at least %s characters."
          ) % config.ca_min_password_length
        ]
      end
    end

  private

    # Configuration of the validation process
    #
    # @return [Y2Users::ValidationConfig]
    def config
      @config ||= Y2Users::ValidationConfig.new
    end
  end
end
