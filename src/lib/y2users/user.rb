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
    # @return [String, nil] nil if unknown
    attr_accessor :uid

    # Primary group ID
    #
    # @note To get the primary group (and not only its ID), see {#primary_group}
    #
    # @return [String, nil] nil if unknown
    attr_accessor :gid

    # Default user shell
    #
    # @return [String, nil] nil if unknown
    attr_accessor :shell

    # Path to the home directory
    #
    # @return [String, nil] nil if unknown
    attr_accessor :home

    # Whether a btrfs subvolume is used as home directory, especially relevant when creating the
    # user in the system
    #
    # @return [Boolean, nil] nil if irrelevant or unknown (some readers may not provide an accurate
    #   value for this attribute)
    attr_accessor :btrfs_subvolume_home

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
    # @return [Password, nil] nil if unknown
    attr_accessor :password

    # Authorized keys
    #
    # @return [Array<String>]
    attr_accessor :authorized_keys

    # Only relevant attributes are compared. For example, the config in which the user is attached
    # and the internal user id are not considered.
    eql_attr :name, :uid, :gid, :shell, :home, :gecos, :source, :password, :authorized_keys,
      :secondary_groups_name

    # Creates a prototype root user
    #
    # The generated root user is not attached to any config.
    #
    # @return [User]
    def self.create_root
      new("root").tap do |root|
        root.uid = "0"
        root.gecos = ["root"]
        root.home = "/root"
      end
    end

    # Constructor
    #
    # @param name [String]
    def initialize(name)
      super()

      @name = name
      # TODO: GECOS
      @gecos = []
      @authorized_keys = []
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
      return nil unless gid

      config.groups.find { |g| g.gid == gid }
    end

    # Groups where the user is included. It also contains the primary group unless set otherwise.
    #
    # The user must be attached to a config in order to find its groups.
    #
    # @param with_primary [Boolean] if primary group should be included
    # @return [Array<Group>]
    def groups(with_primary: true)
      return [] unless attached?

      groups = config.groups.select { |g| g.users.map(&:name).include?(name) }
      groups.reject! { |g| g.gid == gid } if gid && !with_primary

      groups
    end

    # Secondary group names where the user is included
    #
    # @return [Array<String>]
    def secondary_groups_name
      groups(with_primary: false).map(&:name).sort
    end

    # Content of the password
    #
    # @return [String, nil] nil if no password or the password has no value
    def password_content
      password&.value&.content
    end

    # @return [Date, nil] date when the account expires or nil if never
    def expire_date
      password&.account_expiration&.date
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
      user.authorized_keys = authorized_keys.map(&:dup)

      user
    end

    # Validation errors
    #
    # @see UserValidator#issues
    #
    # @param args [Array] additional arguments for {UserValidator#issues}
    # @return [Y2Issues::List]
    def issues(*args)
      UserValidator.new(self).issues(*args)
    end

    # Validation errors of the current password
    #
    # @see PasswordValidator#issues
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
