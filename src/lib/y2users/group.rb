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

require "yast"
require "y2users/config_element"
require "yast2/equatable"

module Y2Users
  # Class to represent user groups
  #
  # @example
  #   group = Group.new("admins")
  #   group.gid = "110"
  #   group.attached? #=> false
  #   group.id #=> 1
  #
  #   config = Config.new("my_config")
  #   config.attach(group)
  #
  #   group.config #=> config
  #   group.attached? #=> true
  class Group < ConfigElement
    Yast.import "ShadowConfig"

    include Yast2::Equatable

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

    # Only relevant attributes are compared. For example, the config in which the group is attached
    # and the internal group id are not considered.
    eql_attr :name, :gid, :users_name, :source

    # Constructor
    #
    # @param name [String]
    def initialize(name)
      super()

      @name = name
      @users_name = []
      @source = :unknown

      # See #system?
      @system = false
    end

    # Users that become to this group, including users which have this group as primary group
    #
    # The group must be attached to a config in order to find its users.
    #
    # @return [Array<User>]
    def users
      return [] unless attached?

      config.users.select { |u| same_gid?(u) || users_name.include?(u.name) }
    end

    # Whether the group has an gid
    #
    # @return [Boolean]
    def gid?
      !(gid.nil? || gid == "")
    end

    # Whether this is a system group
    #
    # A group is considered a system group if its gid is smaller than SYS_GID_MAX (defined in
    # /etc/login.defs).
    #
    # Note the value of SYS_GID_MIN (also defined in /etc/login.defs) is irrelevant for this check.
    #
    # For groups that still don't have an gid, it is possible to enforce whether they should be
    # considered as a system group (and created as such in the system) via {#system=}.
    #
    # This is important when creating an group because its gid is chosen in the
    # SYS_UID_MIN-SYS_UID_MAX range.
    #
    # @return [Boolean]
    def system?
      gid? ? system_gid? : @system
    end

    # Sets whether the group should be considered as a system one
    #
    # @raise [RuntimeError] if the group already has an gid, because forcing the value only makes
    #   sense for a group which gid is still not known.
    #
    # @see #system?
    #
    # @param value [Boolean]
    def system=(value)
      raise "The gid (#{gid}) is already defined" if gid

      @system = value
    end

  private

    # @see #users
    def same_gid?(user)
      return false unless gid

      user.gid == gid
    end

    # Whether the user gid corresponds to a system group gid
    #
    # @return [Boolean]
    def system_gid?
      return false unless gid? && sys_gid_max

      gid.to_i <= sys_gid_max
    end

    # @return [Integer, nil]
    def sys_gid_max
      Yast::ShadowConfig.fetch(:sys_gid_max)&.to_i
    end
  end
end
