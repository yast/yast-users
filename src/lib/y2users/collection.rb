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

require "forwardable"

module Y2Users
  # Base class for collections
  #
  # A collection is similar to a ruby Array class, but the collection is intended to provide query
  # methods to make easier to work with the collected elements.
  #
  # @example
  #   # Collection of named elements (respond to #name method)
  #   class ExampleCollection < Collection
  #     def by_name(value)
  #       selection = elements.select { |e| e.name == value }
  #
  #       self.class.new(selection)
  #     end
  #   end
  #
  #   obj1 = NamedObject.new("foo")
  #   obj2 = NamedObject.new("bar")
  #   obj3 = NamedObject.new("foo")
  #
  #   collection = ExampleCollection.new([obj1, obj2, obj3])
  #   collection.by_name("foo")   #=> ExampleCollection<obj1, obj3>
  #   collection.empty?           #=> false
  class Collection
    extend Forwardable

    def_delegators :@elements, :each, :select, :find, :reject, :map, :any?, :size, :empty?, :first

    # Constructor
    #
    # @param elements [Array<Object>]
    def initialize(elements = [])
      @elements = elements
    end

    # Adds an element to the collection
    #
    # @raise [FrozenError] see {#check_editable}
    #
    # @param element [Object]
    # @return [self]
    def add(element)
      check_editable

      @elements << element

      self
    end

    # List with all the elements
    #
    # @return [Array<Object>]
    def all
      @elements.dup
    end

    alias_method :to_a, :all

    # Generates a new collection with the sum of elements
    #
    # @param other [Collection]
    # @return [Collection]
    def +(other)
      self.class.new(all + other.all)
    end

  private

    # Checks whether the collection can be modified
    #
    # Modifications in the list of elements should be prevented when the collection is frozen.
    #
    # @raise [FrozenError] if the collection is frozen
    # @return [Boolean]
    def check_editable
      return true unless frozen?

      raise FrozenError, "can't modify frozen #{self.class}: #{inspect}"
    end
  end
end
