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
    # @param lhs [Config] Left Hand Size config. This config is modified.
    # @param rhs [Config] Right Hand Size config
    def initialize(lhs, rhs)
      @lhs = lhs
      @rhs = rhs
    end

    # Merges users and groups from {lhs} config into {rhs} config
    #
    # Users and groups that already exist on {lhs} are updated with their {rhs} counterparts. Note
    # that for users, their uid and gid are not updated according to the {rhs} values.
    def merge
      elements = rhs.users + rhs.groups

      elements.each { |e| merge_element(lhs, e) }
    end

  private

    # Left Hand Size config
    #
    # @return [Config]
    attr_reader :lhs

    # Right Hand Size config
    #
    # @return [Config]
    attr_reader :rhs

    # Merges an element into a config
    #
    # @param config [Config] This config is modified
    # @param element [User, Group]
    def merge_element(config, element)
      current_element = find_element(config, element)

      new_element = element.clone

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
    # @param element [User, Group]
    #
    # @raise [RuntimeError] if the the given element is not an {User} or {Group}.
    #
    # @return [User, Group, nil] nil if the config does not contain an element with the same name as
    #   the given element.
    def find_element(config, element)
      elements = case element
      when User
        config.users
      when Group
        config.groups
      else
        raise "Element #{element} not valid. It must be an User or Group"
      end

      elements.find { |e| e.name == element.name }
    end

    # Copies values from one element into another
    #
    # @param from [Config] source element
    # @param to [Config] target element
    def copy_values(from, to)
      return unless from.is_a?(User)

      to.uid = from.uid
      to.gid = from.gid
    end
  end
end
