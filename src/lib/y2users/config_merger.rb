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
require "y2users/useradd_config"

module Y2Users
  # Helper class to merge users and groups from one config into another config
  class ConfigMerger
    include Yast::Logger

    # Constructor
    #
    # @param lhs [Config] Left Hand Side config. This config is modified.
    # @param rhs [Config] Right Hand Side config
    def initialize(lhs, rhs)
      @lhs = lhs
      @rhs = rhs
    end

    # Merges information from {rhs} config into {lhs} config
    #
    # @see merge_elements
    # @see merge_login
    def merge
      log.debug "Starting Y2Users configuration merge"
      log.debug "lhs: #{lhs.inspect}"
      log.debug "rhs: #{rhs.inspect}"

      merge_elements
      merge_login
      merge_useradd

      log.debug "Result of Y2Users merge: #{lhs.inspect}"
    end

  private

    # Left Hand Side config
    #
    # @return [Config]
    attr_reader :lhs

    # Right Hand Side config
    #
    # @return [Config]
    attr_reader :rhs

    # Merges users and groups
    #
    # Users and groups that already exist on lhs are replaced with their rhs counterparts.
    def merge_elements
      collection = rhs.users + rhs.groups

      collection.each { |e| merge_element(lhs, e) }
    end

    # Copies rhs login config to lhs
    #
    # If rhs login config is unknown, then lhs one is kept.
    def merge_login
      return unless rhs.login?

      rhs.login.copy_to(lhs)
    end

    # Merges the useradd configuration
    #
    # Basically overwrites all lhs values with the non-null ones coming from rhs
    def merge_useradd
      return unless rhs.useradd

      lhs.useradd ||= UseraddConfig.new
      lhs.useradd.class.writable_attributes.each do |attr|
        value = rhs.useradd.public_send(attr)
        next if value.nil?

        lhs.useradd.public_send(:"#{attr}=", value)
      end
    end

    # Merges an element into a config
    #
    # @param config [Config] This config is modified
    # @param element [ConfigElement]
    def merge_element(config, element)
      current_element = find_element(config, element)

      new_element = element.copy

      if current_element
        new_element.assign_internal_id(current_element.id)
        config.detach(current_element)
      end

      config.attach(new_element)
    end

    # Finds an element into a config by its name
    #
    # @param config [Config]
    # @param element [ConfigElement]
    #
    # @raise [RuntimeError] if the the given element is not an {User} or {Group}.
    #
    # @return [ConfigElement, nil] nil if the config does not contain an element with the same
    #   name as the given element.
    def find_element(config, element)
      collection = case element
      when User
        config.users
      when Group
        config.groups
      else
        raise "Element #{element} not valid. It must be an User or Group"
      end

      collection.find { |e| e.name == element.name }
    end
  end
end
