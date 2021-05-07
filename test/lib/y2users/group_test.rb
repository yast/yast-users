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

    let(:user3) { Y2Users::User.new("test2") }

    let(:config) { Y2Users::Config.new }

    before do
      subject.gid = 100

      config.attach(users)
    end

    context "if the group is not attached to any config" do
      let(:users) { [user1, user2, user3] }

      it "returns an empty list" do
        expect(subject.users).to be_empty
      end
    end

    context "if the group is attached to a config" do
      before do
        config.attach(subject)
      end

      context "and the group does not specify any user name" do
        before do
          subject.users_name = []
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
        before do
          subject.users_name = ["test2", "test3", "test4"]
        end

        context "and the config contains users with that names" do
          let(:users) { [user2, user3] }

          it "includes users from config with that names" do
            expect(subject.users).to include(user2, user3)
          end

          it "does not include users that are not found in the config" do
            expect(subject.users.map(&:name)).to_not include("test4")
          end

          context "and the config has users with this group as primary group" do
            let(:users) { [user1, user2, user3] }

            it "includes users from config which have this group as primary group" do
              expect(subject.users.size).to eq(3)
              expect(subject.users).to include(user1)
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
end
