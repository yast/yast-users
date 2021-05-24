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

require "y2users/config_element_collection"

module Y2Users
  # Collection of groups
  class GroupsCollection < ConfigElementCollection
    # Constructor
    #
    # @param groups [Array<Group>]
    def initialize(groups = [])
      super
    end

    # Generates a new collection with the groups whose gid is the given gid
    #
    # @param value [Integer]
    # @return [GroupsCollection]
    def by_gid(value)
      groups = select { |g| g.gid == value }

      self.class.new(groups)
    end

    # Group with the given name
    #
    # @param value [String]
    # @return [Group, nil] nil if the collection does not include a group with the given name
    def by_name(value)
      find { |g| g.name == value }
    end
  end
end
