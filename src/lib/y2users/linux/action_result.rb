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

require "y2issues/list"

module Y2Users
  module Linux
    # Result of performing an action
    #
    # An ActionResult stores whether performing the action was successful and the list of generated
    # issues.
    class ActionResult
      # @return [Y2Issues::List] list of issues while performing the action
      attr_reader :issues

      # Constructor
      #
      # @param success [Boolean] see #success?
      # @param issues [Y2Issues::List, nil] see #issues
      def initialize(success, issues = nil)
        @success = success
        @issues = issues || Y2Issues::List.new
      end

      # Whether the action was successful
      #
      # @return [Boolean]
      def success?
        @success
      end
    end
  end
end
