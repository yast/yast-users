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

describe Y2Users::Group do
  subject { described_class.new("test") }

  include_examples "config element"

  describe "#users" do
    let(:user1) do
      user = Y2Users::User.new("test1")
      user.gid = 100
      user
    end

    let(:user2) { Y2Users::User.new("test2") }

    let(:user3) { Y2Users::User.new("test3") }

    let(:config) { Y2Users::Config.new }

    let(:user_names) { [] }

    before do
      subject.gid = 100
      subject.users_name = user_names

      config.attach(users)
    end

    context "if the group is not attached to any config" do
      let(:users) { [user1, user2, user3] }
      let(:user_names) { ["test1"] }

      it "returns an empty list" do
        expect(subject.users).to be_empty
      end
    end

    context "if the group is attached to a config" do
      before do
        config.attach(subject)
      end

      context "and the group does not specify any user name" do
        let(:user_names) { [] }
        let(:users) { [user1, user2, user3] }

        context "and the gid of the group is nil" do
          before { subject.gid = nil }

          # Regression test: it used to include all users with a nil gid
          it "returns an empty list" do
            expect(subject.users).to be_empty
          end
        end

        context "and the config has no user with this group as primary group" do
          let(:users) { [user2, user3] }

          it "returns an empty list" do
            expect(subject.users).to be_empty
          end
        end

        context "and the config has users with this group as primary group" do
          let(:users) { [user1] }

          it "includes users from config which have this group as primary group" do
            expect(subject.users).to include(user1)
          end
        end
      end

      context "and the group specifies some user names" do
        let(:user_names) { ["test2", "test4"] }

        context "and the config contains users with those names" do
          let(:users) { [user2, user3] }

          it "includes users from config with that names" do
            expect(subject.users).to contain_exactly(*user2)
          end

          it "does not include users that are not found in the config" do
            expect(subject.users.map(&:name)).to_not include("test4")
          end

          context "and the config has users with this group as primary group" do
            let(:users) { [user1, user2, user3] }

            it "includes users from config which have this group as primary group" do
              expect(subject.users.size).to eq(2)
              expect(subject.users).to include(user1)
            end
          end

          context "and the gid of the group is nil" do
            before { subject.gid = nil }

            # Regression test
            it "does not include users with gid nil" do
              expect(subject.users).to_not include(user3)
            end
          end
        end
      end
    end
  end

  describe "#==" do
    subject { described_class.new("test1") }

    before do
      subject.gid = 100
      subject.users_name = ["test1", "test2"]
      subject.source = [:ldap]
    end

    let(:other) { subject.copy }

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

    context "when the #users_name does not match" do
      before do
        other.users_name = ["test1"]
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

    context "when the given object is not a group" do
      let(:other) { "This is not a group" }

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end
  end

  describe "#system?" do
    before do
      allow(Yast::ShadowConfig).to receive(:fetch).with(:sys_gid_max).and_return("499")
    end

    context "when the group has gid" do
      before do
        subject.gid = gid
      end

      context "and the gid is smaller than the max system gid" do
        let(:gid) { 300 }

        it "returns true" do
          expect(subject.system?).to eq(true)
        end
      end

      context "and the gid is bigger than the max system gid" do
        let(:gid) { 500 }

        it "returns false" do
          expect(subject.system?).to eq(false)
        end
      end
    end

    context "when the group has no gid" do
      before do
        subject.system = is_system
      end

      context "and the group was configured as a system group" do
        let(:is_system) { true }

        it "returns true" do
          expect(subject.system?).to eq(true)
        end
      end

      context "and the user was not configured as a system user" do
        let(:is_system) { false }

        it "returns false" do
          expect(subject.system?).to eq(false)
        end
      end
    end
  end

  describe "#system=" do
    before do
      subject.gid = gid
    end

    context "if the group has already a gid" do
      let(:gid) { 1000 }

      it "raises an error" do
        expect { subject.system = true }.to raise_error(RuntimeError)
      end
    end

    context "if the group has no gid yet" do
      let(:gid) { nil }

      context "and true is given" do
        it "marks the group as a system group" do
          subject.system = true

          expect(subject.system?).to eq(true)
        end
      end

      context "and false is given" do
        it "marks the group as a local group" do
          subject.system = false

          expect(subject.system?).to eq(false)
        end
      end
    end
  end
end
