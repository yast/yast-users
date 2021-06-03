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

require "y2users/config_merger"
require "y2users/users_collection"
require "y2users/groups_collection"

module Y2Users
  # Class to represent a configuration of users and groups
  #
  # @example
  #   user1 = User.new("john")
  #   user2 = User.new("peter")
  #   group = Group.new("users")
  #
  #   config1 = Config.new
  #   config1.users #=> UsersCollection<[]>
  #   config1.attach(user1, user2, group)
  #   config1.users #=> UsersCollection<[user1, user2]>
  #   config1.groups #=> GroupCollection<[group]>
  #
  #   config2 = config1.copy
  #   user = config2.users.first
  #   config2.detach(user)
  #   config2.users #=> UsersCollection<[user2]>
  class Config
    # Login configuration, see {LoginConfig}
    #
    # @see login?
    #
    # @return [LoginConfig, nil] nil if not defined (unknown)
    attr_accessor :login

    # Constructor
    #
    # @see UsersCollection
    # @see GroupsCollection
    def initialize
      @users_collection = UsersCollection.new
      @groups_collection = GroupsCollection.new
      @login = nil
    end

    # Collection of users that belong to this config
    #
    # The collection cannot be modified directly. Use {#attach} and {#detach} instead.
    #
    # @return [UsersCollection]
    def users
      users_collection.dup.freeze
    end

    # Collection of groups that belong to this config
    #
    # The colletion cannot be modified directly. Use {#attach} and {#detach} instead.
    #
    # @return [GroupsCollection]
    def groups
      groups_collection.dup.freeze
    end

    # Whether the login config is defined
    #
    # @return [Boolean]
    def login?
      !login.nil?
    end

    # Attaches users and groups to this config
    #
    # The given users and groups cannot be attached to a config and their ids should not be included
    # in the config, see {#attach_element}.
    #
    # @param elements [Array<ConfigElement>]
    # @return [self]
    def attach(*elements)
      elements.flatten.each { |e| attach_element(e) }

      self
    end

    # Detaches users and groups from this config
    #
    # The given users and groups must be attached to this config, see {#detach_element}. Also note
    # that the autologin user is removed from the login config if the autologin user is detached.
    #
    # @param elements [Array<ConfigElement>]
    # @return [self]
    def detach(*elements)
      elements.flatten.each { |e| detach_element(e) }

      self
    end

    # Generates a deep copy of the config
    #
    # The copied users and groups keep the same id as the original users and groups.
    #
    # @return [Config]
    def copy
      elements = (users + groups).map(&:copy)

      self.class.new.tap do |config|
        config.attach(elements)
        login&.copy_to(config)
        config.useradd = useradd.dup
      end
    end

    # Generates a new config as result of merging the users and groups of the given config into the
    # users and groups of the current config.
    #
    # @param other [Config]
    # @return [Config]
    def merge(other)
      copy.merge!(other)
    end

    # Modifies the current config by merging the users and groups of the given config into the users
    # and groups of the current config
    #
    # @return [Config]
    def merge!(other)
      merger = ConfigMerger.new(self, other)
      merger.merge

      self
    end

    # Useradd configuration to be applied to the system before creating the users
    #
    # @return [UseraddConfig, nil] nil if the configuration is unknown
    attr_accessor :useradd

  private

    # Collection of users
    #
    # @return [UsersCollection]
    attr_reader :users_collection

    # Collection of groups
    #
    # @return [GroupsCollection]
    attr_reader :groups_collection

    # Attaches a user or group
    #
    # @raise [RuntimeError] if the element is already attached to a config
    # @raise [RuntimeError] if an element with the same id already exists
    #
    # @param element [ConfigElement]
    def attach_element(element)
      raise "Element #{element} is already attached to a config" if element.attached?
      raise "Element #{element} already exists in this config" if exist_element?(element)

      element.assign_config(self)

      collection_for(element).add(element)
    end

    # Detaches a user or group
    #
    # @raise [RuntimeError] if the given element is not attached to the config
    #
    # @param element [ConfigElement]
    def detach_element(element)
      raise "Element #{element} is not attached to this config" if element.config != self

      exist = exist_element?(element)

      if !exist
        log.warn("Detach element: element #{element} is attached to the config #{self}, but " \
          "it cannot be found.")
      end

      collection_for(element).delete(element.id) if exist

      element.assign_config(nil)

      # Clean up the autologin user if the detached user was set for autologin
      login.autologin_user = nil if login? && login.autologin_user&.is?(element)
    end

    # Collection for the given element
    #
    # @param element [ConfigElement]
    # @return [ConfigElementCollection]
    def collection_for(element)
      element.is_a?(User) ? @users_collection : @groups_collection
    end

    # Whether the given element exists in its collection
    #
    # @param element [ConfigElement]
    # @return [Boolean]
    def exist_element?(element)
      collection_for(element).include?(element.id)
    end
  end
end
