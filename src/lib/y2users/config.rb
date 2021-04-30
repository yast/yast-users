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
  # Class to represent a configuration of users and groups
  #
  # @example
  #   user = User.new("john")
  #   group = Group.new("users")
  #
  #   config1 = Config.new("config1")
  #   config1.users #=> []
  #   config1.attach(user, group)
  #   config1.users #=> [user]
  #   config1.groups #=> [group]
  #
  #   config2 = config1.clone_as("config2")
  #   user2 = config2.users.first
  #   config2.detach(user2)
  #   config2.users #=> []
  class Config
    class << self
      def get(name)
        @register ||= {}
        @register[name]
      end

      def register(config)
        @register ||= {}
        @register[config.name] = config
      end

      def remove(config)
        name = config.is_a?(self) ? config.name : config

        @register.delete(name)
      end

      def system(reader: nil, force_read: false)
        res = get(:system)
        return res if res && !force_read

        if !reader
          require "y2users/linux/reader"
          reader = Linux::Reader.new
        end

        res = new(:system)
        reader.read_to(res)

        res
      end
    end

    # Config name
    #
    # @return [String]
    attr_reader :name

    # Constructor
    #
    # param name [String]
    def initialize(name)
      @name = name

      @users_manager = ElementManager.new(config)
      @groups_manager = ElementManager.new(config)

      self.class.register(self)
    end

    # Users that belong to this config
    #
    # @note The list of users cannot be modified directly. Use {#attach} and {#detach} instead.
    #
    # @return [Array<User>]
    def users
      users_manager.elements.dup.freeze
    end

    # Groups that belong to this config
    #
    # @note The list of groups cannot be modified directly. Use {#attach} and {#detach} instead.
    #
    # @return [Array<Group>]
    def groups
      groups_manager.elements.dup.freeze
    end

    # Attaches users and groups to this config
    #
    # The given users and groups cannot be already attached to a config.
    #
    # @param elements [Array<User, Group>]
    def attach(*elements)
      elements.each { |e| attach_element(e) }
    end

    # Detaches users and groups from this config
    #
    # @param elements [Array<User, Group>]
    def detach(*elements)
      elements.each { |e| detach_element(e) }
    end

    # Generates a new config with the very same list of users and groups
    #
    # Note that the cloned users and groups keep the same id as the original users and groups.
    #
    # @param name [String] name for the new cloned config
    # @return [Config]
    def clone_as(name)
      config = self.class.new(name)

      elements = users + groups
      elements.each { |e| config.clone_element(e) }

      config
    end

  protected

    # Clones a given user or group and attaches it into this config
    #
    # Note that the cloned element keep the same id as the source element.
    #
    # @param element [User, Group]
    def clone_element(element)
      cloned = element.clone
      cloned.assign_internal_id(element.id)

      attach(cloned)
    end

  private

    # Manager for users
    #
    # @return [ElementManager]
    attr_reader :users_manager

    # Manager for groups
    #
    # @return [ElementManager]
    attr_reader :groups_manager

    # Generates the id for the next attached user or group
    #
    # @return [Integer]
    def self.next_element_id
      @last_element_id ||= 0
      @last_element_id += 1
    end

    private_class_method(:next_element_id)

    # Attaches an user or group
    #
    # An id is assigned to the given user/group, if needed.
    #
    # @param element [User, Group]
    def attach_element(element)
      element.assign_internal_id(self.class.next_element_id) if element.id.nil?

      element.is_a?(User) ? users_manager.attach(element) : groups_manager.attach(element)
    end

    # Detaches an user or group
    #
    # @param element [User, Group]
    def detach_element(element)
      element.is_a?(User) ? users_manager.detach(element) : groups_manager.detach(element)
    end

    # Helper class to manage a list of users or groups
    class ElementManager
      # @return [Array<User, Group>]
      attr_reader :elements

      # Constructor
      #
      # @param config [Config]
      def initialize(config)
        @config = config
        @elements = []
      end

      # Attaches the element to the config
      #
      # @raise [RuntimeError] if the element is already attached
      #
      # @param element [User, Group]
      def attach(element)
        raise "Element already attached: #{element}" if element.attached?

        @elements << element

        element.assign_config(config)
      end

      # Detaches the element from the config
      #
      # @param element [User, Group]
      def detach(element)
        return if element.config != config

        index = @elements.find_index { |e| e.is?(element) }
        @elements.delete_at(index) if index

        element.assing_config(nil)
        element.assign_internal_id(nil)
      end
    end
  end
end
