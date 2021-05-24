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
require "y2users/shadow_date_helper"

module Y2Users
  module Parsers
    # Parses shadow style string and return passwords defined in it
    class Shadow
      include ShadowDateHelper

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

      # Parses content and returns mapping of username and password there.
      # @param content [String]
      # @return [Hash<String, Y2Users::Password>]
      def parse(content)
        content.lines.each_with_object({}) do |line, res|
          values = line.chomp.split(":")

          res[values[SHADOW_MAPPING["username"]]] = parse_values(values)
        end
      end

    private

      def parse_values(values)
        max_age = values[SHADOW_MAPPING["maximum_age"]]
        inactivity_period = values[SHADOW_MAPPING["inactivity_period"]]
        expiration = parse_account_expiration(values[SHADOW_MAPPING["account_expiration"]])
        password_value = PasswordEncryptedValue.new(values[SHADOW_MAPPING["value"]])
        password = Password.new(password_value)
        password.aging = parse_aging(values[SHADOW_MAPPING["last_change"]])
        password.minimum_age = values[SHADOW_MAPPING["minimum_age"]].to_i
        password.maximum_age = max_age&.to_i
        password.warning_period = values[SHADOW_MAPPING["warning_period"]].to_i
        password.inactivity_period = inactivity_period&.to_i
        password.account_expiration = expiration
        password
      end

      def parse_aging(value)
        return nil unless value

        PasswordAging.new(value)
      end

      def parse_account_expiration(value)
        return nil if !value || value.empty?

        shadow_string_to_date(value)
      end
    end
  end
end
