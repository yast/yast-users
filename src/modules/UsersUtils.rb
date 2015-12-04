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

require "yast"

module Yast
  class UsersUtilsClass < Module
    # Minimal length of password that can be used for CA (FATE#300438)
    # See also installation control file: globals->root_password_ca_check
    MIN_PASSWORD_LENGTH_CA = 4

    def main
      textdomain "users"

      Yast.import "ProductFeatures"
    end

    # Returns whether Users module should check CA constraints
    # @return [Boolean] whether to check them
    def check_ca_constraints?
      if @check_ca_constraints.nil?
        @check_ca_constraints = ProductFeatures.GetBooleanFeature(
          "globals", "root_password_ca_check"
        ) == true
      end

      @check_ca_constraints
    end
  end

  UsersUtils = UsersUtilsClass.new
  UsersUtils.main
end
