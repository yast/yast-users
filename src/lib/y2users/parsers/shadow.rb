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

require "date"
require "y2users/password"

module Y2Users
  module Parsers
    # Parses shadow style string and return passwords defined in it
    class Shadow
      # Mapping of attributes to index in shadow file
      SHADOW_MAPPING = {
        "username"           => 0,
        "value"              => 1,
        "last_change"        => 2,
        "minimum_age"        => 3,
        "maximum_age"        => 4,
        "warning_period"     => 5,
        "inactivity_period"  => 6,
        "account_expiration" => 7
      }.freeze

      # Parses the given string representing the content of a shadow file and returns a mapping of
      # username and password
      #
      # @param content [String]
      # @return [Hash<String, Password>]
      def parse(content)
        content.lines.each_with_object({}) do |line, res|
          # If the limit parameter (second parameter) of String#split is omitted, then the trailing
          # null fields are suppressed. If the limit is negative, then there is no limit to the
          # number of fields returned, and trailing null fields are not suppressed.
          values = line.chomp.split(":", -1)

          res[values[SHADOW_MAPPING["username"]]] = create_password(values)
        end
      end

    private

      # Creates a password from the values of a shadow line
      #
      # @param values [Array<String>]
      # @return [Password]
      def create_password(values)
        Password.create_encrypted(values[SHADOW_MAPPING["value"]]).tap do |password|
          password.aging = PasswordAging.new(values[SHADOW_MAPPING["last_change"]])
          password.minimum_age = values[SHADOW_MAPPING["minimum_age"]]
          password.maximum_age = values[SHADOW_MAPPING["maximum_age"]]
          password.warning_period = values[SHADOW_MAPPING["warning_period"]]
          password.inactivity_period = values[SHADOW_MAPPING["inactivity_period"]]
          password.account_expiration =
            AccountExpiration.new(values[SHADOW_MAPPING["account_expiration"]])
        end
      end
    end
  end
end
