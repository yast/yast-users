#!/usr/bin/env rspec

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
require_relative "config_element_collection_examples"
require "y2users"
require "y2users/groups_collection"

describe Y2Users::GroupsCollection do
  subject { described_class.new(elements) }

  include_examples "config element collection"

  let(:group1) { Y2Users::Group.new("test1") }
  let(:group2) { Y2Users::Group.new("test2") }
  let(:group3) { Y2Users::Group.new("test3") }

  describe "#by_gid" do
    let(:elements) { [group1, group2, group3] }

    context "if the collection contains groups with the given gid" do
      before do
        group2.gid = 100
        group3.gid = 100
      end

      it "returns a new collection with all the groups with the given gid" do
        collection = subject.by_gid(100)

        expect(collection).to be_a(Y2Users::GroupsCollection)
        expect(collection).to_not eq(subject)
        expect(collection.ids).to contain_exactly(group2.id, group3.id)
      end
    end

    context "if the collection does not contain groups with the given gid" do
      it "returns a new empty collection" do
        collection = subject.by_gid(100)

        expect(collection).to be_a(Y2Users::GroupsCollection)
        expect(collection).to_not eq(subject)
        expect(collection).to be_empty
      end
    end
  end

  describe "#by_name" do
    context "if the collection contains a group with the given name" do
      let(:elements) { [group1, group2, group3] }

      it "returns the group with the given name" do
        group = subject.by_name("test2")

        expect(group).to be_a(Y2Users::Group)
        expect(group.id).to eq(group2.id)
      end
    end

    context "if the collection does not contain a user with the given name" do
      let(:elements) { [group1, group3] }

      it "returns nil" do
        group = subject.by_name("test2")

        expect(group).to be_nil
      end
    end
  end
end
