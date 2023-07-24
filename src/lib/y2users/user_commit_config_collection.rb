# Copyright (c) [2021-2023] SUSE LLC
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

require "y2users/collection"

module Y2Users
  # Collection of user commit configs
  #
  # @see UserCommitConfig
  class UserCommitConfigCollection < Collection
    # Constructor
    #
    # @param configs [Array<UserCommitConfig>]
    def initialize(configs = [])
      super
    end

    # Commit config for the given user
    #
    # @param value [String] username
    # @return [UserCommitConfig, nil] nil if the collection does not include a configuration for
    #   the given username
    def by_username(value)
      find { |c| c.username == value }
    end
  end
end
