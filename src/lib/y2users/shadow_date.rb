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

require "date"

module Y2Users
  # Class that represents a date which is expressed as the number of days since 1970-01-01.
  class ShadowDate
    # Constructor
    #
    # @param date [String, Date] date in the shadow format (numeric string) or as Date object
    def initialize(date)
      date = to_shadow_format(date) if date.is_a?(Date)

      @content = date
    end

    # String representing the date in the shadow format (number of days since 1970-01-01)
    #
    # @return [String]
    def to_s
      @content
    end

    # Converts the number of days into a date
    #
    # @return [Date]
    def to_date
      # We need to expand the days to seconds
      unix_time = @content.to_i * 24 * 60 * 60
      Date.strptime(unix_time.to_s, "%s")
    end

  private

    # Converts the given date to a string representing the number of days since 1970-01-01
    #
    # @param date [Date]
    # @return [String]
    def to_shadow_format(date)
      # We need to convert the seconds provided by "%s" to days
      (date.strftime("%s").to_i / (24 * 60 * 60)).to_s
    end
  end
end
