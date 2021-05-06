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

require "abstract_method"

module Y2Users
  module ConfigMergers
    # Helper class to merge users and groups of two configs
    class Base
      # Constructor
      #
      # @param lhs [Config] Left Hand Size config
      # @param rhs [Config] Right Hand Size config
      def initialize(lhs, rhs)
        @lhs = lhs
        @rhs = rhs
      end

      def merge
        elements = rhs.users + rhs.groups

        elements.each { |e| merge_element(lhs, e) }
      end

    private

      # @return [Config] Left Hand Size config
      attr_reader :lhs

      # @return [Config] Right Hand Size config
      attr_reader :rhs

      abstract_method :merge_element
    end
  end
end
