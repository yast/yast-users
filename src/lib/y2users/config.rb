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

module Y2Users
  # Holds references to elements of user configuration like users or groups.
  # TODO: write example
  class Config
    attr_accessor :users
    attr_accessor :groups

    def initialize(users: [], groups: [])
      @users = users
      @groups = groups
    end

    def clone
      config = self.class.new
      config.users = users.map { |u| u.clone_to(config) }
      config.groups = groups.map { |g| g.clone_to(config) }

      config
    end
  end
end
