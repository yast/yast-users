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
  # Class to represent an user
  #
  # @example
  #   user = User.new("john")
  #   user.uid = 1001
  #   user.system? #=> false
  #   user.attached? #=> false
  #   user.id #=> nil
  #
  #   config = Config.new("my_config")
  #   config.attach(user)
  #
  #   user.config #=> config
  #   user.id #=> 23
  #   user.attached? #=> true
  class User
    include ConfigElement

    Yast.import "ShadowConfig"

    # User name
    #
    # @return [String]
    attr_accessor :name

    # User ID
    #
    # @return [String, nil] nil if it is not assigned yet
    attr_accessor :uid

    # Primary group ID
    #
    # @note To get the primary group (and not only its ID), see {#primary_group}
    #
    # @return [String, nil] nil if it is not assigned yet
    attr_accessor :gid

    # Default user shell
    #
    # @return [String, nil] nil if it is not assigned yet
    attr_accessor :shell

    # Path to the home directory
    #
    # @return [String, nil] nil if it is not assigned yet
    attr_accessor :home

    # Fields for the GECOS entry
    #
    # @return [Array<String>]
    attr_accessor :gecos

    # Where the user is defined
    #
    # @return [:local, :ldap, :unknown]
    attr_accessor :source

    # Password for the user
    #
    # @return [Password]
    attr_accessor :password

    # Constructor
    #
    # @param name [String]
    def initialize(name)
      @name = name
      # TODO: GECOS
      @gecos = []
      @source = :unknown

      # See #system?
      @system = false
    end

    # Primary group for the user
    #
    # The user must be attached to a config in order to find its primary group.
    #
    # @return [Group, nil] nil if the group is not set yet
    def primary_group
      return nil unless attached?

      config.groups.find { |g| g.gid == gid }
    end

    # Groups where the user is included. It also contains the primary group.
    #
    # The user must be attached to a config in order to find its groups.
    #
    # @return [Array<Group>]
    def groups
      return [] unless attached?

      config.groups.select { |g| g.users.include?(self) }
    end

    # @return [Date, nil] date when the account expires or nil if never
    def expire_date
      password&.account_expiration
    end

    # User full name
    #
    # It is extracted from GECOS if possible. Otherwise, the user name is considered as the full
    # name.
    #
    # @return [String]
    def full_name
      gecos.first || name
    end

    # Whether two users are equal
    #
    # Only relevant attributes are compared. For example, the config in which the user is attached
    # and the internal user id are not considered.
    #
    # @return [Boolean]
    def ==(other)
      [:name, :uid, :gid, :shell, :home, :gecos, :source, :password].all? do |a|
        public_send(a) == other.public_send(a)
      end
    end

    alias_method :eql?, :==

    # Whether the user is root
    #
    # @return [Boolean]
    def root?
      name == "root"
    end

    # Whether this is a system user
    #
    # This is important when creating an user because several reasons:
    #   * The uid is chosen in the SYS_UID_MIN-SYS_UID_MAX range (defined in /etc/login.defs).
    #   * No aging information is added to /etc/shadow.
    #   * By default, the home directory is not created.
    #
    # For users that still don't have an uid, it is possible to enforce whether they should be
    # considered as a system user (and created as such in the system) via {#system=}.
    #
    # @return [Boolean]
    def system?
      uid ? system_uid? : @system
    end

    # Sets whether the user should be considered as a system one
    #
    # @raise [RuntimeError] if the user already has an uid, because forcing the value only makes
    #   sense for a user which uid is still not known.
    #
    # @see #system?
    #
    # @param value [Boolean]
    def system=(value)
      raise "The uid (#{uid}) is already defined" if uid

      @system = value
    end

    # @see ConfigElement#clone
    def clone
      cloned = super
      cloned.password = password.clone

      cloned
    end

  private

    # Whether the user uid corresponds to a system user uid
    #
    # @return [Boolean]
    def system_uid?
      return false unless uid && sys_uid_max

      uid.between?(sys_uid_min || 1, sys_uid_max)
    end

    # @return [Integer, nil]
    def sys_uid_min
      Yast::ShadowConfig.fetch(:sys_uid_min)&.to_i
    end

    # @return [Integer, nil]
    def sys_uid_max
      Yast::ShadowConfig.fetch(:sys_uid_max)&.to_i
    end
  end
end
