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

require "y2users/collection"

module Y2Users
  # Base class for collection of config elements (e.g., {User}, {Group}).
  class ConfigElementCollection < Collection
    # Constructor
    #
    # @param elements [Array<ConfigElement>]
    def initialize(elements = [])
      super
    end

    # Deletes the element with the given id from the collection
    #
    # @raise [FrozenError] see {#check_editable}
    #
    # @param id [Integer]
    # @return [self]
    def delete(id)
      check_editable

      @elements.reject! { |e| e.id == id }

      self
    end

    # Generates a new collection without the elements whose id is included in the list of ids
    #
    # @param ids [Array<Integer>]
    # @return [Collection]
    def without(*ids)
      elements = (self.ids - ids.flatten).map { |i| by_id(i) }

      self.class.new(elements)
    end

    # Generates a new collection only with the elements that have changed from another collection
    #
    # Note that the new collection only includes elements that exist in the other collection, that
    # is, the new elements are not considered.
    #
    # @param other [Collection]
    # @return [Collection]
    def changed_from(other)
      ids = self.ids & other.ids

      elements = ids.map { |i| by_id(i) }.reject { |e| e == other.by_id(e.id) }

      self.class.new(elements)
    end

    # Whether the collection already contains an element with the given id
    #
    # @param id [Integer]
    # @return [Boolean]
    def include?(id)
      ids.include?(id)
    end

    # Element with the given id
    #
    # @return [ConfigElement, nil] nil if the collection does not include an element with
    #   such an id.
    def by_id(value)
      @elements.find { |e| e.id == value }
    end

    # All element ids
    #
    # @return [Array<Integer>]
    def ids
      map(&:id)
    end
  end
end
