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

require "y2users/linux/create_group_action"
require "y2users/group"

describe Y2Users::Linux::CreateGroupAction do
  subject { described_class.new(group) }

  let(:group) { Y2Users::Group.new("test") }

  describe "#write" do
    before do
      allow(Yast::Execute).to receive(:on_target!)
    end

    it "calls groupadd to create the group" do
      expect(Yast::Execute).to receive(:on_target!).with("/usr/sbin/groupadd", "test")

      subject.perform
    end

    context "when the group has gid" do
      before do
        group.gid = "1000"
      end

      it "calls groupadd with --non-unique option" do
        expect(Yast::Execute).to receive(:on_target!).with(/groupadd/, any_args) do |*args|
          expect(args).to include("--non-unique")
        end

        subject.perform
      end

      it "calls groupadd with --gid option" do
        expect(Yast::Execute).to receive(:on_target!).with(/groupadd/, any_args) do |*args|
          expect(args.join(" ")).to match(/--gid 1000/)
        end

        subject.perform
      end
    end

    context "when the group has no gid" do
      it "calls groupadd without --non-unique option" do
        expect(Yast::Execute).to receive(:on_target!).with(/groupadd/, any_args) do |*args|
          expect(args).to_not include("--non-unique")
        end

        subject.perform
      end

      it "calls groupadd without --gid option" do
        expect(Yast::Execute).to receive(:on_target!).with(/groupadd/, any_args) do |*args|
          expect(args).to_not include("--gid")
        end

        subject.perform
      end
    end

    context "when the command for creating the group successes" do
      it "returns a successful result" do
        result = subject.perform

        expect(result.success?).to eq(true)
      end
    end

    context "when the command for creating the group fails" do
      before do
        allow(Yast::Execute).to receive(:on_target!)
          .and_raise(Cheetah::ExecutionFailed.new(nil, nil, nil, nil))
      end

      it "returns a failed result with an issue" do
        result = subject.perform

        expect(result.success?).to eq(false)
        expect(result.issues.first.message).to match(/could not be created/)
      end
    end
  end
end
