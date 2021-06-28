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
  # Collection of users
  class UsersCollection < ConfigElementCollection
    # Constructor
    #
    # @param users [Array<User>]
    def initialize(users = [])
      super
    end

    # Root user from the collection
    #
    # @return [User, nil] nil if the collection does not include a root user
    def root
      find(&:root?)
    end

    # Generates a new collection only with the system users
    #
    # @return [UsersCollection]
    def system
      users = select(&:system?)

      self.class.new(users)
    end

    # Generates a new collection with the users whose uid is the given uid
    #
    # @param value [Integer]
    # @return [UsersCollection]
    def by_uid(value)
      users = select { |u| u.uid == value }

      self.class.new(users)
    end

    # User with the given name
    #
    # @param value [String]
    # @return [User, nil] nil if the collection does not include a user with the given name
    def by_name(value)
      find { |u| u.name == value }
    end
  end
end
