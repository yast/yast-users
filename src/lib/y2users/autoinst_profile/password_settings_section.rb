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

require "installation/autoinst_profile/section_with_attributes"

module Y2Users
  module AutoinstProfile
    # Represents the password settings in the profile
    #
    #   <password_settings>
    #     <expire>2021-05-01</expire>
    #     <inact>3</inact>
    #     <min>5</min>
    #     <max>180</max>
    #   </password_settings>
    #
    # @!attribute expire
    #   @return [String,nil] Account expiration in date format (YYYY-MM-DD)
    #
    # @!attribute flag
    #   @return [String,nil] `/etc/shadow` flag field
    #
    # @!attribute inact
    #   @return [String,nil] Number of days after password expiration to disable the account
    #
    # @!attribute max
    #   @return [String,nil] Maximum number of days a password is valid
    #
    # @!attribute min
    #   @return [String,nil] Grace period (in days) to change the password after it has expired
    #
    # @!attribute warn
    #   @return [String,nil] Number of days before password expiration to notify the user
    #
    # @!attribute last_change
    #   @todo How does it work? Which is the format? It is not documented. For now, it is assumed
    #     that it uses a string representing a date (YYYY-MM-DD) like the expire attribute.
    #   @return [String,nil]
    class PasswordSettingsSection < ::Installation::AutoinstProfile::SectionWithAttributes
      def self.attributes
        [
          { name: :expire, allow_blank: true },
          { name: :flag, allow_blank: true },
          { name: :inact, allow_blank: true },
          { name: :last_change, allow_blank: true },
          { name: :max, allow_blank: true },
          { name: :min, allow_blank: true },
          { name: :warn, allow_blank: true }
        ]
      end

      define_attr_accessors
    end
  end
end
