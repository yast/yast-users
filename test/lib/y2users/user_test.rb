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
require_relative "config_element_examples"
require "y2users"
require "date"

describe Y2Users::User do
  subject { described_class.new("test") }

  include_examples "config element"

  describe "#primary_group" do
    before do
      group = Y2Users::Group.new("test")
      group.gid = gid
      config.attach(group)
    end

    let(:config) { Y2Users::Config.new }

    let(:gid) { 100 }

    context "if the user is not attached to any config" do
      it "returns nil" do
        expect(subject.primary_group).to be_nil
      end
    end

    context "if the user is attached to a config" do
      before do
        config.attach(subject)
      end

      context "and the user has no gid" do
        before do
          subject.gid = nil
        end

        it "returns nil" do
          expect(subject.primary_group).to be_nil
        end
      end

      context "and the user has a gid" do
        before do
          subject.gid = 100
        end

        context "and there is no group in the config with such a gid" do
          let(:gid) { 101 }

          it "returns nil" do
            expect(subject.primary_group).to be_nil
          end
        end

        context "and there is a group in the config with such a gid" do
          let(:gid) { 100 }

          it "returns the group with such a gid" do
            group = subject.primary_group

            expect(group).to be_a(Y2Users::Group)
            expect(group.gid).to eq(100)
          end
        end
      end
    end
  end

  describe "#groups" do
    let(:group1) do
      group = Y2Users::Group.new("test1")
      group.gid = 100
      group.users_name = []
      group
    end

    let(:group2) do
      group = Y2Users::Group.new("test2")
      group.gid = 101
      group.users_name = ["test", "other"]
      group
    end

    let(:group3) do
      group = Y2Users::Group.new("test3")
      group.gid = 102
      group.users_name = ["test"]
      group
    end

    let(:group4) do
      group = Y2Users::Group.new("test4")
      group.gid = 103
      group.users_name = ["other"]
      group
    end

    let(:config) { Y2Users::Config.new }

    let(:groups) { [group1, group2, group3, group4] }

    before do
      config.attach(groups)
    end

    context "if the user is not attached to any config" do
      it "returns an empty list" do
        expect(subject.groups).to be_empty
      end
    end

    context "if the user is attached to a config" do
      before do
        config.attach(subject)
      end

      it "includes all groups from config that contain such a user name" do
        expect(subject.groups).to contain_exactly(group2, group3)
      end

      context "and the config has no groups with such a user name" do
        let(:groups) { [group1, group4] }

        it "returns an empty list" do
          expect(subject.groups).to be_empty
        end
      end

      context "and the user indicates the gid of its primary group" do
        before do
          subject.gid = 100
        end

        context "and the config has a group with such a gid" do
          it "includes the primary group" do
            expect(subject.groups).to include(group1)
          end
        end

        context "and the config has not a group with such a gid" do
          let(:groups) { [group2, group3, group4] }

          it "does not include the primary group" do
            expect(subject.groups).to_not include(group1)
          end
        end
      end
    end
  end

  describe "#expire_date" do
    before do
      subject.password = password
    end

    context "when the user has no password" do
      let(:password) { nil }

      it "returns nil" do
        expect(subject.expire_date).to be_nil
      end
    end

    context "when the user has a password" do
      let(:password) { Y2Users::Password.create_plain("S3cr3T") }

      before do
        password.account_expiration = expiration
      end

      context "and the password has no expiration" do
        let(:expiration) { nil }

        it "returns nil" do
          expect(subject.expire_date).to be_nil
        end
      end

      context "and the password has expiration" do
        let(:expiration) { today }

        let(:today) { Date.today }

        it "returns the password expiration" do
          expect(subject.expire_date).to eq(today)
        end
      end
    end
  end

  describe "#full_name" do
    before do
      subject.gecos = gecos
    end

    context "when the user has GECOS" do
      let(:gecos) { ["Test User", "other"] }

      it "returns the first GECOS value" do
        expect(subject.full_name).to eq("Test User")
      end
    end

    context "when the user has no GECOS" do
      let(:gecos) { [] }

      it "returns the user name" do
        expect(subject.full_name).to eq("test")
      end
    end
  end

  describe "#==" do
    subject { described_class.new("test1") }

    before do
      subject.uid = 1000
      subject.gid = 100
      subject.shell = "/dev/bash"
      subject.home = "/home/test1"
      subject.gecos = ["User Test1", "Other"]
      subject.source = [:ldap]
      subject.password = Y2Users::Password.create_plain("S3cr3T")
    end

    let(:other) { subject.clone }

    context "when all the attributes are equal" do
      it "returns true" do
        expect(subject == other).to eq(true)
      end
    end

    context "when the #name does not match" do
      before do
        other.name = "test2"
      end

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end

    context "when the #uid does not match" do
      before do
        other.uid = 1001
      end

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end

    context "when the #gid does not match" do
      before do
        other.gid = 101
      end

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end

    context "when the #shell does not match" do
      before do
        other.shell = "/bin/zsh"
      end

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end

    context "when the #home does not match" do
      before do
        other.home = "/home/test2"
      end

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end

    context "when the #gecos does not match" do
      before do
        other.gecos = []
      end

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end

    context "when the #source does not match" do
      before do
        other.source = :local
      end

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end

    context "when the #password does not match" do
      before do
        other.password.value.content = "M0r3-S3cr3T"
      end

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end

    context "when the given object is not an user" do
      let(:other) { "This is not an user" }

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end
  end

  describe "#root?" do
    before do
      subject.name = name
    end

    context "when the user name is 'root'" do
      let(:name) { "root" }

      it "returns true" do
        expect(subject.root?).to eq(true)
      end
    end

    context "when the user name is not 'root'" do
      let(:name) { "root1" }

      it "returns false" do
        expect(subject.root?).to eq(false)
      end
    end
  end

  describe "#system?" do
    before do
      allow(Yast::ShadowConfig).to receive(:fetch).with(:sys_uid_max).and_return("499")
      subject.name = name
    end

    RSpec.shared_examples "system user if nobody" do
      context "and the user name is 'nobody'" do
        let(:name) { "nobody" }

        it "returns true" do
          expect(subject.system?).to eq(true)
        end
      end

      context "and the user name is different from 'nobody'" do
        let(:name) { "somebody" }

        it "returns false" do
          expect(subject.system?).to eq(false)
        end
      end
    end

    RSpec.shared_examples "system user anyways" do
      context "and the user name is 'nobody'" do
        let(:name) { "nobody" }

        it "returns true" do
          expect(subject.system?).to eq(true)
        end
      end

      context "and the user name is different from 'nobody'" do
        let(:name) { "somebody" }

        it "returns true" do
          expect(subject.system?).to eq(true)
        end
      end
    end

    context "when the user has uid" do
      before do
        subject.uid = uid
      end

      context "and the uid is bigger than the max system uid" do
        let(:uid) { 500 }

        include_examples "system user if nobody"
      end

      context "and the uid is smaller than the max system uid" do
        let(:uid) { 300 }

        include_examples "system user anyways"
      end
    end

    context "when the user has no uid" do
      before do
        subject.system = is_system
      end

      context "and the user was configured as a system user" do
        let(:is_system) { true }

        include_examples "system user anyways"
      end

      context "and the user was not configured as a system user" do
        let(:is_system) { false }

        include_examples "system user if nobody"
      end
    end
  end

  describe "#system=" do
    before do
      subject.uid = uid
    end

    context "if the user has already an uid" do
      let(:uid) { 1000 }

      it "raises an error" do
        expect { subject.system = true }.to raise_error(RuntimeError)
      end
    end

    context "if the user has no uid yet" do
      let(:uid) { nil }

      context "and true is given" do
        it "marks the user as a system user" do
          subject.system = true

          expect(subject.system?).to eq(true)
        end
      end

      context "and false is given" do
        it "marks the user as a local user" do
          subject.system = false

          expect(subject.system?).to eq(false)
        end
      end
    end
  end
end
