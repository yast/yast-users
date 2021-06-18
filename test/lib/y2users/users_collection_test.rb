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
require "y2users/users_collection"

describe Y2Users::UsersCollection do
  subject { described_class.new(elements) }

  include_examples "config element collection"

  let(:user1) { Y2Users::User.new("test1") }
  let(:user2) { Y2Users::User.new("test2") }
  let(:user3) { Y2Users::User.new("test3") }

  describe "#root" do
    context "if the collection contains a root user" do
      let(:elements) { [user1, root, user3] }

      let(:root) { Y2Users::User.create_root }

      it "returns the root user" do
        expect(subject.root).to be_a(Y2Users::User)
        expect(subject.root.id).to eq(root.id)
      end
    end

    context "if the collection does not contain a root user" do
      let(:elements) { [user1, user2, user3] }

      it "returns nil" do
        expect(subject.root).to be_nil
      end
    end
  end

  describe "#system" do
    let(:elements) { [user1, user2, user3] }

    context "if the collection contains system users" do
      before do
        user1.system = true
        user2.system = false
        user3.system = true
      end

      it "returns a new collection with all the system users" do
        collection = subject.system

        expect(collection).to be_a(Y2Users::UsersCollection)
        expect(collection).to_not eq(subject)
        expect(collection.ids).to contain_exactly(user1.id, user3.id)
      end
    end

    context "if the collection does not contain system users" do
      before do
        user1.system = false
        user2.system = false
        user3.system = false
      end

      it "returns a new empty collection" do
        collection = subject.system

        expect(collection).to be_a(Y2Users::UsersCollection)
        expect(collection).to_not eq(subject)
        expect(collection).to be_empty
      end
    end
  end

  describe "#by_uid" do
    let(:elements) { [user1, user2, user3] }

    context "if the collection contains users with the given uid" do
      before do
        user2.uid = 1000
        user3.uid = 1000
      end

      it "returns a new collection with all the users with the given uid" do
        collection = subject.by_uid(1000)

        expect(collection).to be_a(Y2Users::UsersCollection)
        expect(collection).to_not eq(subject)
        expect(collection.ids).to contain_exactly(user2.id, user3.id)
      end
    end

    context "if the collection does not contain users with the given uid" do
      it "returns a new empty collection" do
        collection = subject.by_uid(1000)

        expect(collection).to be_a(Y2Users::UsersCollection)
        expect(collection).to_not eq(subject)
        expect(collection).to be_empty
      end
    end
  end

  describe "#by_name" do
    context "if the collection contains a user with the given name" do
      let(:elements) { [user1, user2, user3] }

      it "returns the user with the given name" do
        user = subject.by_name("test2")

        expect(user).to be_a(Y2Users::User)
        expect(user.id).to eq(user2.id)
      end
    end

    context "if the collection does not contain a user with the given name" do
      let(:elements) { [user1, user3] }

      it "returns nil" do
        user = subject.by_name("test2")

        expect(user).to be_nil
      end
    end
  end
end
