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
require "y2users"

describe Y2Users::ConfigMerger do
  subject { described_class.new(lhs, rhs) }

  let(:lhs) { Y2Users::Config.new }

  let(:rhs) { Y2Users::Config.new }

  describe "#merge" do
    before do
      lhs.attach(lhs_users)
      lhs.attach(lhs_groups)
    end

    let(:lhs_users) { [] }

    let(:lhs_groups) { [] }

    def lhs_user(name)
      lhs.users.find { |u| u.name == name }
    end

    def lhs_group(name)
      lhs.groups.find { |g| g.name == name }
    end

    context "when the rhs config contains users" do
      before do
        rhs.attach(rhs_users)
      end

      let(:user1) do
        user = Y2Users::User.new("test1")
        user.uid = 1000
        user.gid = 100
        user.home = "/home/test1"
        user
      end

      let(:user2) do
        user = Y2Users::User.new("test2")
        user.uid = 1001
        user.gid = 101
        user.home = "/home/test1"
        user
      end

      let(:user3) do
        user = Y2Users::User.new("test3")
        user.uid = 1003
        user.gid = 103
        user.home = "/home/test3"
        user
      end

      let(:rhs_users) { [user1, user2] }

      context "and the lhs config does not contain users with the same name" do
        let(:lhs_users) { [user3] }

        it "adds the new users to the lhs config" do
          expect(lhs.users.size).to eq(1)

          subject.merge

          expect(lhs.users.map(&:name)).to contain_exactly("test1", "test2", "test3")
        end

        it "keeps attributes from rhs users" do
          subject.merge

          expect(lhs_user("test1")).to eq(user1)
          expect(lhs_user("test2")).to eq(user2)
        end
      end

      context "and the lhs config contains users with the same name" do
        let(:lhs_users) { [lhs_user1, user3] }

        let(:lhs_user1) do
          user = user1.clone
          user.uid = 1100
          user.gid = 110
          user.home = "/home/lhs_user1"
          user
        end

        it "does not add a new user with the same name to the lhs config" do
          subject.merge

          expect(lhs.users.map(&:name)).to contain_exactly("test1", "test2", "test3")
        end

        it "updates the lhs user with the data from the corresponding rhs user" do
          subject.merge

          expect(lhs_user("test1").home).to eq("/home/test1")
        end

        it "keeps the lhs user id" do
          id = lhs_user("test1").id
          subject.merge

          expect(lhs_user("test1").id).to eq(id)
        end

        it "keeps the lhs user uid" do
          subject.merge

          expect(lhs_user("test1").uid).to eq(1100)
        end

        it "keeps the lhs user gid" do
          subject.merge

          expect(lhs_user("test1").gid).to eq(110)
        end
      end
    end

    context "when the rhs config contains groups" do
      before do
        rhs.attach(rhs_groups)
      end

      let(:group1) do
        group = Y2Users::Group.new("test1")
        group.gid = 100
        group.users_name = ["test1", "test2"]
        group
      end

      let(:group2) do
        group = Y2Users::Group.new("test2")
        group.gid = 101
        group.users_name = ["test2", "test3"]
        group
      end

      let(:group3) do
        group = Y2Users::Group.new("test3")
        group.gid = 103
        group.users_name = ["test3"]
        group
      end

      let(:rhs_groups) { [group1, group2] }

      context "and the lhs config does not contain groups with the same name" do
        let(:lhs_groups) { [group3] }

        it "adds the new groups to the lhs config" do
          expect(lhs.groups.size).to eq(1)

          subject.merge

          expect(lhs.groups.map(&:name)).to contain_exactly("test1", "test2", "test3")
        end

        it "keeps attributes from rhs groups" do
          subject.merge

          expect(lhs_group("test1")).to eq(group1)
          expect(lhs_group("test2")).to eq(group2)
        end
      end

      context "and the lhs config contains groups with the same name" do
        let(:lhs_groups) { [lhs_group1, group3] }

        let(:lhs_group1) do
          group = group1.clone
          group.gid = 110
          group.users_name = ["test1"]
          group
        end

        it "does not add a new group with the same name to the lhs config" do
          subject.merge

          expect(lhs.groups.map(&:name)).to contain_exactly("test1", "test2", "test3")
        end

        it "updates the lhs group with the data from the corresponding rhs group" do
          subject.merge

          expect(lhs_group("test1")).to eq(group1)
        end

        it "keeps the lhs group id" do
          id = lhs_group("test1").id
          subject.merge

          expect(lhs_group("test1").id).to eq(id)
        end
      end
    end
  end
end
