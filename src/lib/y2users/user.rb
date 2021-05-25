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
require "y2users/user_validator"
require "y2users/password_validator"
require "yast2/equatable"

module Y2Users
  # Class to represent a user
  #
  # @example
  #   user = User.new("john")
  #   user.uid = 1001
  #   user.system? #=> false
  #   user.attached? #=> false
  #   user.id #=> 1
  #
  #   config = Config.new("my_config")
  #   config.attach(user)
  #
  #   user.config #=> config
  #   user.attached? #=> true
  class User < ConfigElement
    include Yast2::Equatable

    # User names that are considered system users
    # @see #system?
    SYSTEM_NAMES = ["nobody"].freeze
    private_constant :SYSTEM_NAMES

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

    # Only relevant attributes are compared. For example, the config in which the user is attached
    # and the internal user id are not considered.
    eql_attr :name, :uid, :gid, :shell, :home, :gecos, :source, :password

    # Constructor
    #
    # @param name [String]
    def initialize(name)
      super()

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

    # Whether the user has an uid
    #
    # @return [Boolean]
    def uid?
      !(uid.nil? || uid == "")
    end

    # Whether the user is root
    #
    # @return [Boolean]
    def root?
      name == "root"
    end

    # Whether this is a system user
    #
    # The traditional YaST criteria is used here. Thus, this is a system user if:
    #   * the name is "nobody"
    #   * the uid is smaller than SYS_UID_MAX (defined in /etc/login.defs)
    #
    # Note the value of SYS_UID_MIN (also defined in /etc/login.defs) is irrelevant for this check.
    #
    # For users that still don't have an uid, it is possible to enforce whether they should be
    # considered as a system user (and created as such in the system) via {#system=}.
    #
    # This is important when creating an user for several reasons:
    #   * The uid is chosen in the SYS_UID_MIN-SYS_UID_MAX range.
    #   * No aging information is added to /etc/shadow.
    #   * By default, the home directory is not created.
    #
    # @return [Boolean]
    def system?
      return true if SYSTEM_NAMES.include?(name)

      uid? ? system_uid? : @system
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

    # Generates a deep copy of the user
    #
    # @see ConfigElement#copy
    #
    # @return [User]
    def copy
      user = super
      user.password = password.copy if password

      user
    end

    # Validation errors
    #
    # @return [Y2Issues::List]
    def issues
      UserValidator.new(self).issues
    end

    # Validation errors of the current password
    #
    # @return [Y2Issues::List]
    def password_issues
      PasswordValidator.new(self).issues
    end

  private

    # Whether the user uid corresponds to a system user uid
    #
    # @return [Boolean]
    def system_uid?
      return false unless uid? && sys_uid_max

      uid.to_i <= sys_uid_max
    end

    # @return [Integer, nil]
    def sys_uid_max
      Yast::ShadowConfig.fetch(:sys_uid_max)&.to_i
    end
  end
end
