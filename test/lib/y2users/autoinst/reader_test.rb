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

require_relative "../test_helper"

require "y2users/config"
require "y2users/autoinst/reader"

# defines exported users
require_relative "../../../fixtures/users_export"

describe Y2Users::Autoinst::Reader do
  subject { described_class.new(profile) }

  let(:profile) { USERS_EXPORT }

  describe "#read" do
    it "fills given config with data from hash" do
      result = subject.read

      config = result.config
      expect(config.users.size).to eq 29
      expect(config.groups.size).to eq 43

      root_user = config.users.root
      expect(root_user.shell).to eq "/bin/bash"
      expect(root_user.primary_group.name).to eq "root"
      expect(root_user.password.value.encrypted?).to eq true
      expect(root_user.password.value.content).to match(/^\$6\$AS/)
    end

    context "when the users list is missing" do
      let(:profile) do
        { "groups" => [{ "groupname" => "users" }] }
      end

      it "sets the user list as an empty array" do
        result = subject.read

        config = result.config
        users_group = config.groups.first
        expect(users_group.name).to eq("users")
        expect(users_group.users_name).to eq([])
      end
    end

    context "when a user has no username" do
      let(:profile) do
        {
          "users" => [
            { "username" => "root", "user_password" => "secret" },
            { "user_password" => "secret" }
          ]
        }
      end

      it "registers an issue" do
        result = subject.read
        issue = result.issues.first
        expect(issue).to be_a(Y2Issues::InvalidValue)
        expect(issue.location.to_s).to eq("autoyast:users,1:username")
      end
    end

    context "when a user has an empty username" do
      let(:profile) do
        {
          "users" => [
            { "username" => "", "user_password" => "secret" },
            { "username" => "root", "user_password" => "secret" }
          ]
        }
      end

      it "registers an issue" do
        result = subject.read
        issue = result.issues.first
        expect(issue).to be_a(Y2Issues::InvalidValue)
        expect(issue.location.to_s).to eq("autoyast:users,0:username")
      end
    end

    context "when the profile is empty" do
      let(:profile) { {} }

      it "sets the users and groups lists as empty" do
        result = subject.read
        config = result.config

        expect(config.users).to be_empty
        expect(config.groups).to be_empty
      end
    end

    context "when the password is not encrypted" do
      let(:user_profile) do
        { "username" => "root", "user_password" => "secret" }
      end

      let(:profile) do
        { "users" => [user_profile] }
      end

      it "sets the passsword as unencrypted" do
        result = subject.read
        config = result.config

        user = config.users.first
        password = user.password
        expect(password.value).to_not be_encrypted
      end
    end

    context "when the password is not given" do
      let(:user_profile) do
        { "username" => "root" }
      end

      let(:profile) do
        { "users" => [user_profile] }
      end

      it "sets a nil password" do
        result = subject.read
        config = result.config

        user = config.users.first
        expect(user.password).to be_nil
      end
    end

    context "when a group has no groupname" do
      let(:profile) do
        {
          "groups" => [
            { "groupname" => "root" },
            { "gid" => "100" }
          ]
        }
      end

      it "registers an issue" do
        result = subject.read
        issue = result.issues.first
        expect(issue).to be_a(Y2Issues::InvalidValue)
        expect(issue.location.to_s).to eq("autoyast:groups,1:groupname")
      end
    end

    context "when a group has an empty groupname" do
      let(:profile) do
        {
          "groups" => [
            { "groupname" => "" },
            { "groupname" => "root", "gid" => "100" }
          ]
        }
      end

      it "registers an issue" do
        result = subject.read
        issue = result.issues.first
        expect(issue).to be_a(Y2Issues::InvalidValue)
        expect(issue.location.to_s).to eq("autoyast:groups,0:groupname")
      end
    end
  end
end
