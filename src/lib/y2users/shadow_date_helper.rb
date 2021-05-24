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
  # Mixin for converting the strings used to represent dates in the shadow file
  module ShadowDateHelper
    # Converts a string representing the number of days since 1970-01-01 into a date
    #
    # @param string [String]
    # @return [Date]
    def shadow_string_to_date(string)
      # We need to expand the days to seconds
      unix_time = string.to_i * 24 * 60 * 60
      Date.strptime(unix_time.to_s, "%s")
    end

    # Converts a date to a string representing the number of days since 1970-01-01
    #
    # @param date [Date]
    # @return [String
    def date_to_shadow_string(date)
      # We need to convert the seconds provided by "%s" to days
      date.strftime("%s").to_i / (24 * 60 * 60)
    end
  end
end
