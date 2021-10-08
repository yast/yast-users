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

    let(:users) { [] }

    it "returns an immutable collection of users" do
      users = subject.users

      expect(users).to be_a(Y2Users::UsersCollection)
      expect { users.add(Y2Users::User.new("test")) }.to raise_error(RuntimeError)
    end

    context "when there are no attached users" do
      let(:users) { [] }

      it "returns an empty collection" do
        users = subject.users

        expect(users).to be_empty
      end
    end

    context "when there are attached users" do
      let(:user1) { Y2Users::User.new("test1") }

      let(:user2) { Y2Users::User.new("test2") }

      let(:user3) { Y2Users::User.new("test3") }

      let(:users) { [user1, user2, user3] }

      it "returns a collection with all the attached users" do
        expect(subject.users.all).to contain_exactly(user1, user2, user3)
      end
    end
  end

  describe "#groups" do
    before do
      subject.attach(groups)
    end

    let(:groups) { [] }

    it "returns an immutable collection of groups" do
      groups = subject.groups

      expect(groups).to be_a(Y2Users::GroupsCollection)
      expect { groups.add(Y2Users::Group.new("test")) }.to raise_error(RuntimeError)
    end

    context "when there are no attached groups" do
      let(:groups) { [] }

      it "returns an empty collection" do
        expect(subject.groups).to be_empty
      end
    end

    context "when there are attached groups" do
      let(:group1) { Y2Users::Group.new("test1") }

      let(:group2) { Y2Users::Group.new("test2") }

      let(:group3) { Y2Users::Group.new("test3") }

      let(:groups) { [group1, group2, group3] }

      it "returns a collection with all the attached groups" do
        expect(subject.groups.all).to contain_exactly(group1, group2, group3)
      end
    end
  end

  describe "#login?" do
    context "when there is no login config" do
      it "returns false" do
        expect(subject.login?).to eq(false)
      end
    end

    context "when there is login config" do
      before do
        subject.login = Y2Users::LoginConfig.new
      end

      it "returns true" do
        expect(subject.login?).to eq(true)
      end
    end
  end

  describe "#attach" do
    let(:user1) { Y2Users::User.new("test1") }

    let(:user2) { Y2Users::User.new("test2") }

    let(:group1) { Y2Users::Group.new("test1") }

    it "adds the given elements to the collections of users and groups" do
      subject.attach(user1, user2, group1)

      expect(subject.users.all).to contain_exactly(user1, user2)

      expect(subject.groups.all).to contain_exactly(group1)
    end

    it "assigns the config to the given elements" do
      subject.attach(user1, group1)

      expect(user1.config).to eq(subject)
      expect(group1.config).to eq(subject)
    end

    it "returns the config" do
      result = subject.attach(user1, group1)

      expect(result).to eq(subject)
    end

    context "if a given element is already attached to the config" do
      before do
        subject.attach(user2)
      end

      it "raises an error" do
        expect { subject.attach(user2) }.to raise_error(RuntimeError, /already attached/)
      end
    end

    context "if a given element is already attached to another config" do
      before do
        described_class.new.attach(user2)
      end

      it "raises an error" do
        expect { subject.attach(user2) }.to raise_error(RuntimeError, /already attached/)
      end
    end

    context "if the given element has an id that already exists in the config" do
      before do
        subject.attach(user1)
      end

      it "raises an error" do
        expect { subject.attach(user1.copy) }.to raise_error(RuntimeError, /already exists/)
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

    it "removes the given elements from the colletions of users and groups" do
      subject.detach(user2, group1)

      expect(subject.users.all).to contain_exactly(user1)

      expect(subject.groups).to be_empty
    end

    it "removes the config from the given elements" do
      subject.detach(user2, group1)

      expect(user2.config).to be_nil

      expect(group1.config).to be_nil
    end

    it "does not modify the rest of elements" do
      subject.detach(user2, group1)

      expect(user1.config).to eq(subject)
    end

    it "returns the config" do
      result = subject.detach(user2, group1)

      expect(result).to eq(subject)
    end

    context "if the given element is used for autologin" do
      before do
        subject.login = Y2Users::LoginConfig.new
        subject.login.autologin_user = user1
      end

      it "removes the autologin user from the login config" do
        subject.detach(user1)

        expect(subject.login.autologin?).to eq(false)
      end
    end

    context "if the given element is not used for autologin" do
      before do
        subject.login = Y2Users::LoginConfig.new
        subject.login.autologin_user = user1
      end

      it "does not remove the autologin user from the login config" do
        subject.detach(user2)

        expect(subject.login.autologin_user).to eq(user1)
      end
    end

    context "if a given element is not attached yet" do
      let(:user3) { Y2Users::User.new("test3")  }

      it "raises an error" do
        expect { subject.detach(user3) }.to raise_error(RuntimeError, /not attached/)
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

  describe "#copy" do
    before do
      subject.attach([user1, user2, group1, group2])

      subject.login = Y2Users::LoginConfig.new
      subject.login.passwordless = true
      subject.login.autologin_user = user1
    end

    let(:user1) { Y2Users::User.new("test1") }

    let(:user2) { Y2Users::User.new("test2") }

    let(:group1) { Y2Users::Group.new("test1") }

    let(:group2) { Y2Users::Group.new("test2") }

    def find(config, element)
      elements = config.users.all + config.groups.all

      elements.find { |e| e == element }
    end

    it "generates a new config object" do
      config = subject.copy

      expect(config).to_not eq(subject)
    end

    it "copies all users from the current config" do
      config = subject.copy

      expect(config.users.all).to eq(subject.users.all)
    end

    it "copies all groups from the current config" do
      config = subject.copy

      expect(config.groups.all).to eq(subject.groups.all)
    end

    it "keeps the same users id" do
      config = subject.copy

      config.users.each do |user|
        original_user = find(subject, user)

        expect(user.id).to eq(original_user.id)
      end
    end

    it "keeps the same groups id" do
      config = subject.copy

      config.groups.each do |group|
        original_group = find(subject, group)

        expect(group.id).to eq(original_group.id)
      end
    end

    it "copies the login config" do
      config = subject.copy

      expect(config.login).to be_a(Y2Users::LoginConfig)
      expect(config.login.passwordless?).to eq(true)
      expect(config.login.autologin_user.name).to eq("test1")
    end
  end

  describe "#merge" do
    before do
      subject.attach([user1, group1])

      other.attach([user1.copy, user2, group2])
      other.login = Y2Users::LoginConfig.new
      other.login.passwordless = true
    end

    let(:other) { Y2Users::Config.new }

    let(:user1) { Y2Users::User.new("test1") }

    let(:user2) { Y2Users::User.new("test2") }

    let(:group1) { Y2Users::Group.new("test1") }

    let(:group2) { Y2Users::Group.new("test2") }

    it "generates a new config object" do
      config = subject.merge(other)

      expect(config).to_not eq(subject)
    end

    it "does not mofidify the current config" do
      users = subject.users.all
      groups = subject.groups.all

      subject.merge(other)

      expect(subject.users.all).to eq(users)
      expect(subject.groups.all).to eq(groups)
    end

    it "merges users from the given config into the users of the current config" do
      config = subject.merge(other)

      names = config.users.map(&:name)

      expect(names).to contain_exactly("test1", "test2")
    end

    it "merges groups from the given config into the groups of the current config" do
      config = subject.merge(other)

      names = config.groups.map(&:name)

      expect(names).to contain_exactly("test1", "test2")
    end

    it "copies the login config from the given config into the new config" do
      config = subject.merge(other)

      expect(config.login).to be_a(Y2Users::LoginConfig)
      expect(config.login.passwordless?).to eq(true)
    end
  end

  describe "#merge!" do
    before do
      subject.attach([user1, group1])

      other.attach([user1.copy, user2, group2])
      other.login = Y2Users::LoginConfig.new
      other.login.passwordless = true
    end

    let(:other) { Y2Users::Config.new }

    let(:user1) { Y2Users::User.new("test1") }

    let(:user2) { Y2Users::User.new("test2") }

    let(:group1) { Y2Users::Group.new("test1") }

    let(:group2) { Y2Users::Group.new("test2") }

    it "does not generate a new config object" do
      config = subject.merge!(other)

      expect(config).to eq(subject)
    end

    it "modifies the current config object" do
      users = subject.users.all
      groups = subject.groups.all

      subject.merge!(other)

      expect(subject.users.all).to_not eq(users)
      expect(subject.groups.all).to_not eq(groups)
    end

    it "merges users from the given config into the users of the current config" do
      subject.merge!(other)

      names = subject.users.map(&:name)

      expect(names).to contain_exactly("test1", "test2")
    end

    it "merges groups from the given config into the groups of the current config" do
      subject.merge!(other)

      names = subject.groups.map(&:name)

      expect(names).to contain_exactly("test1", "test2")
    end

    it "copies the login config from the given config into the current config" do
      subject.merge!(other)

      expect(subject.login).to be_a(Y2Users::LoginConfig)
      expect(subject.login.passwordless?).to eq(true)
    end
  end
end
