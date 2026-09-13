#!/usr/bin/env rspec

# Copyright (c) [2026] SUSE LLC
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
require "y2users/collection"

describe Y2Users::Collection do
  subject(:collection) { described_class.new(["a", "b"]) }

  describe "#add" do
    it "adds the given element to the collection" do
      collection.add("c")

      expect(collection.all).to eq(["a", "b", "c"])
    end

    it "returns self" do
      expect(collection.add("c")).to eq(collection)
    end

    context "when the collection is frozen" do
      subject(:collection) { described_class.new(["a"]).freeze }

      it "raises a FrozenError" do
        expect { collection.add("b") }.to raise_error(FrozenError)
      end
    end
  end

  describe "#all" do
    it "returns a new array with the collected elements" do
      all = collection.all

      expect(all).to eq(["a", "b"])
      expect(all).to_not equal(collection.instance_variable_get(:@elements))
    end
  end

  describe "#+" do
    it "returns a new collection with the elements of both collections" do
      other = described_class.new(["c"])

      result = collection + other

      expect(result).to be_a(described_class)
      expect(result.all).to eq(["a", "b", "c"])
    end

    it "does not modify the original collection" do
      collection + described_class.new(["c"])

      expect(collection.all).to eq(["a", "b"])
    end
  end
end
