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
require "y2users/autoinst_profile/group_section"

module Y2Users
  module AutoinstProfile
    # Thin object oriented layer on top of the <groups> section of the
    # AutoYaST profile.
    class GroupsSection < ::Installation::AutoinstProfile::SectionWithAttributes
      attr_accessor :entries

      class << self
        # Returns the list of group sections
        #
        # @param hashes [Array<Hash>] Array of hashes from the profile
        # @return [Array<GroupSection>] List of group sections
        def new_from_hashes(hashes)
          entries = hashes.map { |e| GroupSection.new_from_hashes(e) }
          new(entries)
        end
      end

      def initialize(entries = [])
        @entries = entries
      end

      # Returns the parent section
      #
      # This method only exist to conform to other sections API (like classes
      # derived from Installation::AutoinstProfile::SectionWithAttributes).
      #
      # @return [nil]
      def parent
        nil
      end
    end
  end
end
