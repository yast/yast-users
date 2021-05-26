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
    # Represents a <group> element from a groups list
    #
    #   <group>
    #     <groupname>users</groupname>
    #     <userlist>jane,john</userlist>
    #     <gid>100</gid>
    #   </group>
    #
    # @!attribute groupname
    #   @return [String,nil] Group name
    #
    # @!attribute gid
    #   @return [String,nil] Group ID
    #
    # @!attribute group_password
    #   @return [String,nil] Group password. See #encrypted.
    #
    # @!attribute encrypted
    #   @return [Boolean,nil] Whether the group password is encrypted or not
    class GroupSection < ::Installation::AutoinstProfile::SectionWithAttributes
      def self.attributes
        [
          { name: :groupname },
          { name: :gid },
          { name: :group_password },
          { name: :encrypted },
          { name: :userlist }
        ]
      end

      define_attr_accessors
    end
  end
end
