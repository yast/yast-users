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
  # Methods for an element that can be attached to a {Config} (e.g., {User}, {Group}).
  module ConfigElement
    # {Config} in which the element is attached to
    #
    # @return [Config, nil] nil if the element is not attached yet
    attr_reader :config

    # Internal identifier to distinguish elements
    #
    # Two elements are considered to be the same if they have the same id, even when they live in
    # different configs.
    #
    # @return [Integer, nil] the id is assigned by the config when attaching the element
    attr_reader :id

    # Assigns the internal id for this element
    #
    # @note The id of an element should not be modified. This method is exposed in the public API
    #   only to make possible to set the id when attaching/detaching an element to/from a config,
    #   see {Config#attach} and {Config#detach}.
    #
    # @param id [Integer]
    def assign_internal_id(id)
      @id = id
    end

    # Assigns the config which the element belongs to
    #
    # @note The config of an element should not be modified. This method is exposed in the public
    #   API only to make possible to set the config reference when attaching/detaching an element
    #   to/from a config, see {Config#attach} and {Config#detach}.
    #
    # @param config [Config]
    def assign_config(config)
      @config = config
    end

    # Whether the element is currently attached to a {Config}
    #
    # @return [Boolean]
    def attached?
      !config.nil?
    end

    # Whether this element is considered the same as other
    #
    # Two elements are considered the same when they have the same id, independently on the rest of
    # attributes.
    #
    # @param other [User, Group]
    # @return [Boolean]
    def is?(other)
      return false unless self.class == other.class
      return false if id.nil? || other.id.nil?

      id == other.id
    end

    # Generates a new cloned element without an specific config or id.
    #
    # Note that the new cloned element is not attached to any config.
    #
    # @return [User, Group]
    def clone
      cloned = super
      cloned.assign_config(nil)
      cloned.assign_internal_id(nil)

      cloned
    end
  end
end
