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

require_relative "test_helper"
require "y2users"

shared_examples "config element collection" do
  let(:elements) { [element1, element2, element3] }

  let(:element1) { element_class.new("test1") }

  let(:element2) { element_class.new("test2") }

  let(:element3) { element_class.new("test3") }

  let(:element_class) do
    (described_class == Y2Users::UsersCollection) ? Y2Users::User : Y2Users::Group
  end

  describe "#add" do
    let(:element) { element_class.new("test") }

    it "adds the given element to the collection" do
      expect(subject.any? { |e| e.id == element.id }).to eq(false)

      size = subject.size
      subject.add(element)

      expect(subject.size).to eq(size + 1)
      expect(subject.any? { |e| e.id == element.id }).to eq(true)
    end

    it "returns the collection" do
      expect(subject.add(element)).to eq(subject)
    end

    context "if the collection is frozen" do
      before do
        subject.freeze
      end

      it "raises an error" do
        expect { subject.add(element) }.to raise_error(FrozenError)
      end
    end
  end

  describe "#delete" do
    context "if the collection includes an element with the given id" do
      let(:id) { elements.first.id }

      it "deletes the element from the collection" do
        expect(subject.any? { |e| e.id == id }).to eq(true)

        size = subject.size
        subject.delete(id)

        expect(subject.size).to eq(size - 1)
        expect(subject.any? { |e| e.id == id }).to eq(false)
      end

      it "returns the collection" do
        expect(subject.delete(id)).to eq(subject)
      end
    end

    context "if the collection does not include an element with the given id" do
      let(:id) { element_class.new("test").id }

      it "does not modify the collection" do
        size = subject.size
        subject.delete(id)

        expect(subject.size).to eq(size)
      end

      it "returns the collection" do
        expect(subject.delete(id)).to eq(subject)
      end
    end

    context "if the collection is frozen" do
      before do
        subject.freeze
      end

      it "raises an error" do
        expect { subject.delete(elements.first.id) }.to raise_error(FrozenError)
      end
    end
  end

  describe "#all" do
    it "return the list of elements" do
      all = subject.all

      expect(all).to eq(elements)
    end
  end

  describe "#+" do
    let(:other) { described_class.new(other_elements) }

    let(:other_elements) { [other_element1, other_element2] }

    let(:other_element1) { elements.first.copy }

    let(:other_element2) { element_class.new("test") }

    it "returns a new collection with all elements from both collections" do
      all_ids = (subject.all + other.all).map(&:id)

      collection = subject + other

      expect(collection).to be_a(described_class)
      expect(collection).to_not eq(subject)
      expect(collection.map(&:id)).to contain_exactly(*all_ids)
    end

    it "does not modify the left operand collection" do
      elements = subject.all

      (subject + other)

      expect(subject.all).to eq(elements)
    end

    it "does not modify the right operand collection" do
      elements = other.all

      (subject + other)

      expect(other.all).to eq(elements)
    end
  end

  describe "#without" do
    it "returns a new collection excluding the elements with the given ids" do
      ids = subject.map(&:id)

      element = element_class.new("test")
      subject.add(element)

      collection = subject.without(ids)

      expect(collection).to be_a(described_class)
      expect(collection).to_not eq(subject)
      expect(collection.map(&:id)).to contain_exactly(element.id)
    end

    context "when the collection does not contain an element with the given ids" do
      let(:ids) { [element_class.new("test").id] }

      it "returns a new collection with the same elements" do
        collection = subject.without(ids)

        expect(collection).to be_a(described_class)
        expect(collection).to_not eq(subject)
        expect(collection.all).to eq(subject.all)
      end
    end
  end

  describe "#changed_from" do
    let(:other) { described_class.new(other_elements) }

    let(:other_elements) { [other_element1, other_element2, other_element3] }

    let(:other_element1) do
      element = element1.copy
      element.name = "other"
      element
    end

    let(:other_element2) do
      element = element2.copy
      element.name = "other"
      element
    end

    let(:other_element3) { element_class.new("test") }

    it "returns a new collection with the modified elements from the other config" do
      collection = subject.changed_from(other)

      expect(collection).to be_a(described_class)
      expect(collection).to_not eq(subject)
      expect(collection.map(&:id)).to contain_exactly(element1.id, element2.id)
    end

    it "does not include elements that do not exist in the other config" do
      collection = subject.changed_from(other)

      expect(collection.map(&:id)).to_not include(element3.id)
    end

    it "does not include elements that only exist in the other config" do
      collection = subject.changed_from(other)

      expect(collection.map(&:id)).to_not include(other_element3.id)
    end
  end

  describe "#include?" do
    context "if the collection contains an element with the given id" do
      let(:id) { element2.id }

      it "returns true" do
        expect(subject.include?(id)).to eq(true)
      end
    end

    context "if the collection does not contain an element with the given id" do
      let(:id) { element_class.new("test").id }

      it "returns false" do
        expect(subject.include?(id)).to eq(false)
      end
    end
  end

  describe "#by_id" do
    context "if the collection contains an element with the given id" do
      let(:id) { element2.id }

      it "returns the element" do
        result = subject.by_id(id)

        expect(result).to be_a(element_class)
        expect(result.id).to eq(element2.id)
      end
    end

    context "if the collection does not contain an element with the given id" do
      let(:id) { element_class.new("test").id }

      it "returns nil" do
        expect(subject.by_id(id)).to be_nil
      end
    end
  end

  describe "#ids" do
    it "returns the ids of all the elements" do
      ids = elements.map(&:id)

      expect(subject.ids).to contain_exactly(*ids)
    end
  end
end
