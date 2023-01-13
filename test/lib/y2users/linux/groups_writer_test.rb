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

require "y2users/linux/groups_writer"
require "y2users/config"
require "y2users/group"

describe Y2Users::Linux::GroupsWriter do
  subject { described_class.new(target_config, initial_config, commit_config) }

  let(:initial_config) { Y2Users::Config.new.tap { |c| c.attach(groups) } }

  let(:target_config) { initial_config.copy }

  let(:test1) { Y2Users::Group.new("test1") }

  let(:test2) { Y2Users::Group.new("test2") }

  let(:groups) { [test1, test2] }

  let(:commit_config) do
    config = Y2Users::CommitConfig.new
    config.target_dir = target_dir
    config
  end

  let(:target_dir) { nil }

  describe "#write" do
    let(:create_group_action) { Y2Users::Linux::CreateGroupAction }

    let(:edit_group_action) { Y2Users::Linux::EditGroupAction }

    let(:delete_group_action) { Y2Users::Linux::DeleteGroupAction }

    def mock_action(action, result, *groups)
      action_instance = instance_double(action, perform: result)

      allow(action).to receive(:new).with(*groups).and_return(action_instance)

      action_instance
    end

    def success(*messages)
      Y2Users::Linux::ActionResult.new(true, issues(messages))
    end

    def failure(*messages)
      Y2Users::Linux::ActionResult.new(false, issues(messages))
    end

    def issues(messages)
      issues = messages.map { |m| Y2Issues::Issue.new(m) }

      Y2Issues::List.new(issues)
    end

    before do
      # Prevent to perform real actions into the system
      allow_any_instance_of(Y2Users::Linux::Action).to receive(:perform).and_return(success)
    end

    it "deletes, edits and creates groups in that order" do
      deleted_group = target_config.groups.by_id(test2.id)
      target_config.detach(deleted_group)

      edited_group = target_config.groups.by_id(test1.id)
      edited_group.name = "new_name"

      new_group = Y2Users::Group.new("test3")
      target_config.attach(new_group)

      delete_action = mock_action(delete_group_action, success, test2)
      edit_action = mock_action(edit_group_action, success, test1, edited_group)
      create_action = mock_action(create_group_action, success, new_group)

      expect(delete_action).to receive(:perform).ordered
      expect(edit_action).to receive(:perform).ordered
      expect(create_action).to receive(:perform).ordered

      subject.write
    end

    context "when a group is deleted from the target config" do
      let(:deleted_group) { target_config.groups.by_id(test2.id) }

      before do
        target_config.detach(deleted_group)
      end

      it "performs the action for deleting the group" do
        action = mock_action(delete_group_action, success, test2)

        expect(action).to receive(:perform)

        subject.write
      end

      it "returns the generated issues" do
        mock_action(delete_group_action, success("deleting group issue"), test2)

        issues = subject.write

        expect(issues.map(&:message)).to include(/deleting group issue/)
      end
    end

    context "when a group is edited in the target config" do
      let(:initial_group) { test2 }

      let(:target_group) { target_config.groups.by_id(initial_group.id) }

      before do
        target_group.name = "new_name"
      end

      it "performs the action for editing the group" do
        action = mock_action(edit_group_action, success, initial_group, target_group)

        expect(action).to receive(:perform)

        subject.write
      end

      it "returns the generated issues" do
        mock_action(edit_group_action, success("issue editing group"), initial_group, target_group)

        issues = subject.write

        expect(issues.map(&:message)).to include(/issue editing group/)
      end
    end

    context "when a group is added to the target config" do
      let(:test3) { Y2Users::Group.new("test3") }

      before do
        target_config.attach(test3)
      end

      it "performs the action for creating the group" do
        action = mock_action(create_group_action, success, test3)

        expect(action).to receive(:perform)

        subject.write
      end

      it "returns the generated issues" do
        mock_action(create_group_action, success("creating group issue"), test3)

        issues = subject.write

        expect(issues.map(&:message)).to include(/creating group issue/)
      end
    end

    context "when there are new groups without gid" do
      let(:test3) { Y2Users::Group.new("test3").tap { |g| g.gid = "1000" } }

      let(:test4) { Y2Users::Group.new("test4") }

      let(:test5) { Y2Users::Group.new("test5").tap { |g| g.gid = "1001" } }

      before do
        target_config.attach(test3, test4, test5)
      end

      it "creates groups with gid first" do
        action_test3 = mock_action(create_group_action, success, test3)
        action_test4 = mock_action(create_group_action, success, test4)
        action_test5 = mock_action(create_group_action, success, test5)

        expect(action_test5).to receive(:perform).ordered
        expect(action_test3).to receive(:perform).ordered
        expect(action_test4).to receive(:perform).ordered

        subject.write
      end
    end
  end
end
