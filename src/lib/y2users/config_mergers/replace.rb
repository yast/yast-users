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

require "y2users/config_mergers/base"

module Y2Users
  module ConfigMergers
    # Helper class to merge users and groups of two configs
    class Replace < Base
      def merge_element(config, element)
        current_element = find_element(config, element)

        config.detach(current_element) if current_element

        config.attach(element.clone)
      end

      def find_element(config, element)
        elements = case element
          when User
            element.users
          when Group
            element.groups
          else
            raise "Element #{element} not valid. It must be an User or Group".
          end

        elements.find { |e| e.name == element.name }
      end
    end
  end
end
