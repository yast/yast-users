#!/usr/bin/env rspec
#
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
require "y2users/config"
require "y2users/user"
require "y2users/group"
require "y2users/collision_checker"

describe Y2Users::CollisionChecker do
  subject(:validator) { described_class.new(config) }

  let(:config) { Y2Users::Config.new }

  describe "#issues" do
    context "when there is no collision" do
      before do
        user1 = Y2Users::User.new("test")
        config.attach(user1)

        user2 = Y2Users::User.new("test2")
        config.attach(user2)

        user3 = Y2Users::User.new("test3")
        user3.uid = "1000"
        config.attach(user3)

        user4 = Y2Users::User.new("test4")
        user4.uid = "1001"
        config.attach(user4)
      end

      it "returns empty issues list" do
        expect(validator.issues).to be_empty
      end
    end

    context "when there is a user uids collision" do
      before do
        user1 = Y2Users::User.new("test")
        config.attach(user1)

        user2 = Y2Users::User.new("test2")
        user2.uid = "1001"
        config.attach(user2)

        user3 = Y2Users::User.new("test3")
        user3.uid = "1000"
        config.attach(user3)

        user4 = Y2Users::User.new("test4")
        user4.uid = "1000"
        config.attach(user4)
      end

      it "returns issue for conflict" do
        expect(validator.issues).to_not be_empty
        expect(validator.issues.size).to eq 1
        expect(validator.issues.to_a.first.message).to eq "Users test3, test4 have same UID 1000."
      end
    end

    context "when there is a user names collision" do
      before do
        user1 = Y2Users::User.new("test")
        config.attach(user1)

        user2 = Y2Users::User.new("test2")
        user2.uid = "1001"
        config.attach(user2)


        user4 = Y2Users::User.new("test")
        user4.uid = "1000"
        config.attach(user4)
      end

      it "returns issue for conflict" do
        expect(validator.issues).to_not be_empty
        expect(validator.issues.size).to eq 1
        expect(validator.issues.to_a.first.message).to eq "User test is specified multiple times."
      end
    end

    context "when there is a group gids collision" do
      before do
        group1 = Y2Users::Group.new("test")
        config.attach(group1)

        group2 = Y2Users::Group.new("test2")
        group2.gid = "1001"
        config.attach(group2)

        group3 = Y2Users::Group.new("test3")
        group3.gid = "1000"
        config.attach(group3)

        group4 = Y2Users::Group.new("test4")
        group4.gid = "1000"
        config.attach(group4)
      end

      it "returns issue for conflict" do
        expect(validator.issues).to_not be_empty
        expect(validator.issues.size).to eq 1
        expect(validator.issues.to_a.first.message).to eq "Groups test3, test4 have same GID 1000."
      end
    end

    context "when there is a group names collision" do
      before do
        group1 = Y2Users::Group.new("test")
        config.attach(group1)

        group2 = Y2Users::Group.new("test2")
        group2.gid = "1001"
        config.attach(group2)

        group3 = Y2Users::Group.new("test")
        group3.gid = "1000"
        config.attach(group3)
      end

      it "returns issue for conflict" do
        expect(validator.issues).to_not be_empty
        expect(validator.issues.size).to eq 1
        expect(validator.issues.to_a.first.message).to eq "Group test is specified multiple times."
      end
    end

  end
end
