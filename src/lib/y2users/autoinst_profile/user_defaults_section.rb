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
    # Represents a <user_defaults> element from a profile
    #
    #   <user_defaults>
    #     <group>100</group>
    #     <groups>wheel</groups>
    #     <expire>2021-05-01</expire>
    #     <home>/Users</home>
    #     <inactive>3</inactive>
    #     <no_groups config:type="boolean">false</no_groups>
    #     <shell>/usr/bin/fish</shell>
    #     <skel>/etc/skel</skel>
    #     <umask>022</umask>
    #   </user_defaults>
    #
    class UserDefaultsSection < ::Installation::AutoinstProfile::SectionWithAttributes
      def self.attributes
        [
          { name: :expire },
          { name: :group  },
          { name: :groups },
          { name: :home },
          { name: :inactive },
          { name: :no_groups },
          { name: :shell },
          { name: :skel },
          { name: :umask }
        ]
      end

      define_attr_accessors

      # @!attribute group
      #   @return [String,nil] Group ID
      #
      # @!attribute groups
      #   @return [String,nil] List of additional groups
      #
      # @!attribute home
      #   @return [String,nil] User's home directory prefix
      #
      # @!attribute expire
      #   @return [String,nil] Default expiration in date format (YYYY-MM-DD)
      #
      # @!attribute inactive
      #   @return [String,nil] Number of days after password expiration to disable the account
      #
      # @!attribute no_groups
      #   @return [Boolean,nil] Do not use secondary groups
      #
      # @!attribute shell
      #   @return [String,nil] Default shell
      #
      # @!attribute skel
      #   @return [String,nil] Location of the files to be used as skeleton
      #
      # @!attribute umask
      #   @return [String,nil] File creation mode mask for the home directory
    end
  end
end
