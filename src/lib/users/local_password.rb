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
require "users/ca_password_validator"

module Users
  # Password for a local user
  #
  # This class is used to validate the correctness of a password by checking
  # some security requirements that the password must fulfill.
  # The class only checks for non-fatal errors. If a password is considered
  # invalid, it still can be used if the user decides to ignore the warnings.
  class LocalPassword
    Yast.import "UsersSimple"
    include Yast::I18n
    include Yast::Logger

    attr_reader :plain, :uid, :also_for_root

    def initialize(uid: "root", also_for_root: false, plain: "")
      textdomain "users"

      @uid = uid
      @also_for_root = also_for_root
      self.plain = plain
    end

    # Setter for the plain-text version of the password
    def plain=(value)
      unset_validated
      @plain = value
    end

    # Checks if the password fulfills the security requirements
    # @return [Boolean] true whether #plain is a valid password
    def valid?
      errors.empty?
    end

    # List of errors found in the password, ready to be displayed to the user
    # @return [Array<String>] localized errors
    def errors
      validate unless validated
      @errors
    end

    # Validator used to check CA restrictions
    # @return [CAPasswordValidator] instance of the CA validator
    def ca_validator
      @ca_validator ||= CAPasswordValidator.new
    end

  private

    attr_accessor :validated
    attr_writer :errors

    def unset_validated
      @errors = []
      @validated = false
    end

    def for_root?
      uid == "root" || also_for_root
    end

    def validate
      validate_strength
      validate_ca_constraints if for_root?
      @validated = true
    end

    def validate_strength
      if !Yast::UsersSimple.LoadCracklib
        log.error "loading cracklib failed, not used for pw check"
        Yast::UsersSimple.UseCrackLib(false)
      end

      begin
        @errors += call_check_password_ui
      ensure
        Yast::UsersSimple.UnLoadCracklib
      end
    end

    def call_check_password_ui
      args_for_cpui = {
        "uid"          => uid,
        "userPassword" => plain,
        "type"         => uid == "root" ? "system" : "local"
      }
      if uid != "root"
        args_for_cpui["root"] = also_for_root
      end
      Yast::UsersSimple.CheckPasswordUI(args_for_cpui)
    end

    def validate_ca_constraints
      return unless ca_validator.enabled?
      @errors += ca_validator.errors_for(plain)
    end
  end
end
