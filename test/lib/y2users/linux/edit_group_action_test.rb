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

require "y2users/linux/edit_group_action"
require "y2users/group"

describe Y2Users::Linux::EditGroupAction do
  subject { described_class.new(initial_group, target_group) }

  let(:initial_group) { Y2Users::Group.new("test") }

  let(:target_group) { initial_group.copy }

  describe "#perform" do
    before do
      allow(Yast::Execute).to receive(:on_target!)
    end

    context "when the group name has changed" do
      before do
        target_group.name = "other"
      end

      it "calls groupmod with --new-name option" do
        expect(Yast::Execute).to receive(:on_target!).with(/groupmod/, any_args, "test") do |*args|
          expect(args.join(" ")).to match(/--new-name other/)
        end

        subject.perform
      end
    end

    context "when the gid has changed" do
      before do
        target_group.gid = "1000"
      end

      it "calls groupmod with --gid option" do
        expect(Yast::Execute).to receive(:on_target!).with(/groupmod/, any_args, "test") do |*args|
          expect(args.join(" ")).to match(/--gid 1000/)
        end

        subject.perform
      end
    end

    context "when the group has not been modified" do
      it "does not call groupmod" do
        expect(Yast::Execute).to_not receive(:on_target!).with(/groupmod/)

        subject.perform
      end
    end

    context "when the command for editing the group successes" do
      before do
        # Some change to ensure the command is called
        target_group.name = "other"
      end

      it "returns a successful result" do
        result = subject.perform

        expect(result.success?).to eq(true)
      end
    end

    context "when the command for creating the group fails" do
      before do
        # Some change to ensure the command is called
        target_group.name = "other"

        allow(Yast::Execute).to receive(:on_target!)
          .and_raise(Cheetah::ExecutionFailed.new(nil, nil, nil, nil))
      end

      it "returns a failed result with an issue" do
        result = subject.perform

        expect(result.success?).to eq(false)
        expect(result.issues.first.message).to match(/could not be modified/)
      end
    end
  end
end
