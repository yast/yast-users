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
  # Helper class to merge users and groups from one config into another config
  class ConfigMerger
    # Constructor
    #
    # @param lhs [Config] Left Hand Side config. This config is modified.
    # @param rhs [Config] Right Hand Side config
    def initialize(lhs, rhs)
      @lhs = lhs
      @rhs = rhs
    end

    # Merges users and groups from {rhs} config into {lhs} config
    #
    # Users and groups that already exist on {lhs} are updated with their {rhs} counterparts.
    #
    # @see merge_element
    def merge
      collection = rhs.users + rhs.groups

      collection.each { |e| merge_element(lhs, e) }
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

    # Merges an element into a config
    #
    # @param config [Config] This config is modified
    # @param element [ConfigElement]
    def merge_element(config, element)
      current_element = find_element(config, element)

      new_element = element.copy

      if current_element
        new_element.assign_internal_id(current_element.id)
        copy_values(current_element, new_element)
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

    # Copies values from one element into another
    #
    # @param from [ConfigElement] Source element
    # @param to [ConfigElement] Target element. This element is modified.
    def copy_values(from, to)
      return unless from.is_a?(User)

      # For an user, its uid and gid should not be updated in order to keep the current AutoYaST
      # behavior. In general, this only affects to the AutoYaST case. In other scenarios like a
      # regular installation, all users from {rhs} (except root) are new users, so this code is
      # not executed for them. And, during installation, only the password can be modified for root,
      # so this actually changes nothing for the root user.
      to.uid = from.uid
      to.gid = from.gid
    end
  end
end
