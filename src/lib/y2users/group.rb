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

require "y2users/config_element"

module Y2Users
  # Class to represent user groups
  #
  # @example
  #   group = Group.new("admins")
  #   group.gid = 110
  #   group.attached? #=> false
  #   group.id #=> 1
  #
  #   config = Config.new("my_config")
  #   config.attach(group)
  #
  #   group.config #=> config
  #   group.attached? #=> true
  class Group < ConfigElement
    # Group name
    #
    # @return [String]
    attr_accessor :name

    # Group id
    #
    # @return [String, nil] nil if it is not assigned yet
    attr_accessor :gid

    # Names of users that become to this group
    #
    # To get the list of users (and not only their names), see {#users}.
    #
    # @return [Array<String>]
    attr_accessor :users_name

    # Where the group is defined
    #
    # @return[:local, :ldap, :unknown]
    attr_accessor :source

    # Constructor
    #
    # @param name [String]
    def initialize(name)
      super()

      @name = name
      @users_name = []
      @source = :unknown
    end

    # Users that become to this group, including users which have this group as primary group
    #
    # The group must be attached to a config in order to find its users.
    #
    # @return [Array<User>]
    def users
      return [] unless attached?

      config.users.select { |u| u.gid == gid || users_name.include?(u.name) }
    end

    # Whether two groups are equal
    #
    # Only relevant attributes are compared. For example, the config in which the group is attached
    # and the internal group id are not considered.
    #
    # @return [Boolean]
    def ==(other)
      return false unless other.is_a?(self.class)

      [:name, :gid, :users_name, :source].all? do |a|
        public_send(a) == other.public_send(a)
      end
    end

    alias_method :eql?, :==
  end
end
