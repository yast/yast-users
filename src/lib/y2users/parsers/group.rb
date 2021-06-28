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

require "y2users/group"

module Y2Users
  module Parsers
    # Parses group style string and return groups defined in it
    class Group
      # Mapping of attributes to index in group file
      GROUP_MAPPING = {
        "name"   => 0,
        "passwd" => 1,
        "gid"    => 2,
        "users"  => 3
      }.freeze

      # Parses content and returns groups defined there.
      # @param content [String]
      # @return [Array<Y2Users::Group>]
      def parse(content)
        content.lines.map do |line|
          values = line.chomp.split(":")
          group = Y2Users::Group.new(values[GROUP_MAPPING["name"]])
          group.gid = values[GROUP_MAPPING["gid"]]
          group.users_name = values[GROUP_MAPPING["users"]].to_s.split(",")
          group
        end
      end
    end
  end
end
