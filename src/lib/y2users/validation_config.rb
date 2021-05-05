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

module Y2Users
  # Class to configure the validation process of the classes in the Y2Users namespace.
  class ValidationConfig
    Yast.import "UsersSimple"
    Yast.import "ProductFeatures"

    # See {#ca_min_password_length}
    CA_MIN_LENGTH = 4
    private_constant :CA_MIN_LENGTH

    # Minimum length of a valid password
    def min_password_length
      Yast::UsersSimple.GetMinPasswordLength("local")
    end

    # Minimum length of the password for the root user if the CA constraints are
    # active
    #
    # @see #check_ca?
    def ca_min_password_length
      CA_MIN_LENGTH
    end

    # Maximum length of a valid password
    def max_password_length
      Yast::UsersSimple.GetMaxPasswordLength("local")
    end

    # Returns whether YaST should check CA constraints
    #
    # See installation control file: globals->root_password_ca_check
    #
    # @return [Boolean] whether to check the constraints
    def check_ca?
      !!Yast::ProductFeatures.GetBooleanFeature("globals", "root_password_ca_check")
    end
  end
end
