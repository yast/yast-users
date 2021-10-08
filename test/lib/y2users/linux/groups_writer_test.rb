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
  subject { described_class.new(target_config, initial_config) }

  let(:initial_config) { Y2Users::Config.new.tap { |c| c.attach(groups) } }

  let(:target_config) { initial_config.copy }

  let(:test1) { Y2Users::Group.new("test1") }

  let(:groups) { [test1] }

  describe "#write" do
    before do
      allow(Yast::Execute).to receive(:on_target!)
    end

    context "when adding groups" do
      let(:test2) { Y2Users::Group.new("test2") }

      let(:test3) { Y2Users::Group.new("test3") }

      let(:test4) { Y2Users::Group.new("test4") }

      before do
        target_config.attach([test2, test3, test4])
      end

      it "creates the new groups" do
        expect(Yast::Execute).to receive(:on_target!).with(/groupadd/, "test2")
        expect(Yast::Execute).to receive(:on_target!).with(/groupadd/, "test3")
        expect(Yast::Execute).to receive(:on_target!).with(/groupadd/, "test4")

        expect(Yast::Execute).to_not receive(:on_target!).with(/groupadd/, "test1")

        subject.write
      end

      context "when there are groups without gid" do
        before do
          test2.gid = "1001"
          test3.gid = nil
          test4.gid = "1002"
        end

        it "creates groups with gid first" do
          expect(Yast::Execute).to receive(:on_target!).with(/groupadd/, any_args, "test4").ordered
          expect(Yast::Execute).to receive(:on_target!).with(/groupadd/, any_args, "test2").ordered
          expect(Yast::Execute).to receive(:on_target!).with(/groupadd/, "test3").ordered

          subject.write
        end
      end

      context "when the group creation fails" do
        before do
          allow(Yast::Execute).to receive(:on_target!).with(/groupadd/, "test2")
            .and_raise(Cheetah::ExecutionFailed.new(nil, double(exitstatus: 1), nil, nil))
        end

        it "generates an issue" do
          issues = subject.write

          expect(issues.first.message).to match(/'test2' could not be created/)
        end
      end
    end
  end
end
