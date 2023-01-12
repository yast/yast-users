#!/usr/bin/env rspec

# Copyright (c) [2021-2023] SUSE LLC
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

require "y2users/linux/writer"
require "y2users/config"
require "y2users/login_config"
require "y2users/user_commit_config_collection"
require "y2issues/list"
require "y2issues/issue"

describe Y2Users::Linux::Writer do
  subject { described_class.new(target_config, initial_config, commit_configs) }

  let(:initial_config) { Y2Users::Config.new }

  let(:target_config) { initial_config.copy }

  let(:commit_configs) { Y2Users::UserCommitConfigCollection.new }

  describe "#write" do
    before do
      allow(Y2Users::Linux::GroupsWriter).to receive(:new)
        .with(target_config, initial_config).and_return(groups_writer)

      allow(Y2Users::Linux::UseraddConfigWriter).to receive(:new)
        .with(target_config, initial_config).and_return(useradd_writer)

      allow(Y2Users::Linux::UsersWriter).to receive(:new)
        .with(target_config, initial_config, commit_configs).and_return(users_writer)

      allow(Y2Users::Linux::LoginConfigWriter).to receive(:new)
        .with(login_config).and_return(login_writer)

      target_config.login = login_config
    end

    let(:groups_writer) do
      instance_double(Y2Users::Linux::GroupsWriter, write: groups_issues)
    end

    let(:useradd_writer) do
      instance_double(Y2Users::Linux::UseraddConfigWriter, write: useradd_issues)
    end

    let(:users_writer) do
      instance_double(Y2Users::Linux::UsersWriter, write: users_issues)
    end

    let(:login_writer) do
      instance_double(Y2Users::Linux::LoginConfigWriter, write: login_issues)
    end

    let(:groups_issues) { nil }

    let(:useradd_issues) { nil }

    let(:users_issues) { nil }

    let(:login_issues) { nil }

    let(:login_config) { Y2Users::LoginConfig.new }

    def issues(*messages)
      issues = messages.map { |m| Y2Issues::Issue.new(m) }

      Y2Issues::List.new(issues)
    end

    it "writes groups, useradd config, users and login config" do
      expect(groups_writer).to receive(:write).ordered
      expect(useradd_writer).to receive(:write).ordered
      expect(users_writer).to receive(:write).ordered
      expect(login_writer).to receive(:write).ordered

      subject.write
    end

    context "when the target config has not login config" do
      let(:login_config) { nil }

      it "does not write the login config" do
        expect(login_writer).to_not receive(:write)

        subject.write
      end
    end

    context "when the groups writer generates issues" do
      let(:groups_issues) { issues("group1 issue", "group2 issue") }

      it "returns the generated issues" do
        issues = subject.write

        expect(issues.map(&:message)).to include("group1 issue", "group2 issue")
      end
    end

    context "when the useradd config writer generates issues" do
      let(:useradd_issues) { issues("useradd issue1", "useradd issue2") }

      it "returns the generated issues" do
        issues = subject.write

        expect(issues.map(&:message)).to include("useradd issue1", "useradd issue2")
      end
    end

    context "when the users writer generates issues" do
      let(:useradd_issues) { issues("user1 issue", "user2 issue") }

      it "returns the generated issues" do
        issues = subject.write

        expect(issues.map(&:message)).to include("user1 issue", "user2 issue")
      end
    end

    context "when the login config writer generates issues" do
      let(:useradd_issues) { issues("login issue1", "login issue2") }

      it "returns the generated issues" do
        issues = subject.write

        expect(issues.map(&:message)).to include("login issue1", "login issue2")
      end
    end

    context "when the writers do not generate issues" do
      it "returns an empty list of issues" do
        issues = subject.write

        expect(issues).to be_empty
      end
    end
  end
end
