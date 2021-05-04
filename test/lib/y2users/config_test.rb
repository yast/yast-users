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

describe Y2Users::Config do
  subject { described_class.new }

  describe "#users" do
    before do
      subject.attach(users)
    end

    context "when there are no attached users" do
      let(:users) { [] }

      it "returns an empty list" do
        expect(subject.users).to be_empty
      end
    end

    context "when there are attached users" do
      let(:user1) { Y2Users::User.new("test1") }

      let(:user2) { Y2Users::User.new("test2") }

      let(:user3) { Y2Users::User.new("test3") }

      let(:users) { [user1, user2, user3] }

      it "returns an immutable list with all the attached users" do
        expect(subject.users).to contain_exactly(user1, user2, user3)

        expect { subject.users << Y2Users::User.new("test") }.to raise_error(RuntimeError)
      end
    end
  end

  describe "#groups" do
    before do
      subject.attach(groups)
    end

    context "when there are no attached groups" do
      let(:groups) { [] }

      it "returns an empty list" do
        expect(subject.groups).to be_empty
      end
    end

    context "when there are attached groups" do
      let(:group1) { Y2Users::Group.new("test1") }

      let(:group2) { Y2Users::Group.new("test2") }

      let(:group3) { Y2Users::Group.new("test3") }

      let(:groups) { [group1, group2, group3] }

      it "returns an immutable list with all the attached groups" do
        expect(subject.groups).to contain_exactly(group1, group2, group3)

        expect { subject.groups << Y2Users::Group.new("test2") }.to raise_error(RuntimeError)
      end
    end
  end

  describe "#attach" do
    let(:user1) { Y2Users::User.new("test1") }

    let(:user2) { Y2Users::User.new("test2") }

    let(:group1) { Y2Users::Group.new("test1") }

    it "attaches the given users and groups" do
      subject.attach(user1, user2, group1)

      expect(subject.users).to contain_exactly(user1, user2)

      expect(subject.groups).to contain_exactly(group1)
    end

    it "assigns an unique id to the attached elements" do
      subject.attach(user1, user2, group1)

      expect(user1.id).to_not be_nil
      expect(user2.id).to_not be_nil
      expect(group1.id).to_not be_nil

      ids = [user1, user2, group1].map(&:id)

      expect(ids).to all(be_a(Integer))
      expect(ids.uniq.size).to eq(3)
    end

    context "if a given element is already attached" do
      before do
        subject.attach(user2)
      end

      it "raises an error" do
        expect { subject.attach(user2) }.to raise_error(RuntimeError)
      end
    end
  end

  describe "#detach" do
    let(:user1) { Y2Users::User.new("test1") }

    let(:user2) { Y2Users::User.new("test2") }

    let(:group1) { Y2Users::Group.new("test1") }

    before do
      subject.attach(user1, user2, group1)
    end

    it "detaches the given users and groups" do
      subject.detach(user2, group1)

      expect(subject.users).to contain_exactly(user1)

      expect(subject.groups).to be_empty
    end

    it "sets the given elements as detached" do
      subject.detach(user2, group1)

      expect(user2.attached?).to eq(false)

      expect(group1.attached?).to eq(false)
    end

    it "removes the id from the given elements" do
      subject.detach(user2, group1)

      expect(user2.id).to be_nil

      expect(group1.id).to be_nil
    end

    it "does not modify the rest of elements" do
      subject.detach(user2, group1)

      expect(user1.attached?).to eq(true)
      expect(user1.id).to_not be_nil
    end

    context "if a given element is not attached yet" do
      let(:user3) { Y2Users::User.new("test3")  }

      it "raises an error" do
        expect { subject.detach(user3) }.to raise_error(RuntimeError)
      end
    end

    context "if a given element is attached to another config" do
      let(:user3) { Y2Users::User.new("test3") }

      before do
        Y2Users::Config.new.attach(user3)
      end

      it "raises an error" do
        expect { subject.detach(user3) }.to raise_error(RuntimeError)
      end
    end
  end
end
