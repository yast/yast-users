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
    # Represents a <login_settings> element from a profile
    #
    #   <login_settings>
    #     <autologin_user>suse</autologin_user>
    #     <password_less_login config:type="boolean">false</password_less_login>
    #   </login_settings>
    #
    class LoginSettingsSection < ::Installation::AutoinstProfile::SectionWithAttributes
      def self.attributes
        [
          { name: :password_less_login },
          { name: :autologin_user }
        ]
      end

      define_attr_accessors

      # @!attribute password_less_login
      #   @return [Boolean,nil] Enables password-less login
      #
      # @!attribute autologin_user
      #   @return [String,nil] Enables autologin for the given user
    end
  end
end
