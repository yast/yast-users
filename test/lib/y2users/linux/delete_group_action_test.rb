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

require "y2users/linux/delete_group_action"
require "y2users/group"

describe Y2Users::Linux::DeleteGroupAction do
  subject { described_class.new(group) }

  let(:group) { Y2Users::Group.new("test") }

  describe "#perform" do
    before do
      allow(Yast::Execute).to receive(:on_target!)
    end

    it "calls groupdel to delete the group" do
      expect(Yast::Execute).to receive(:on_target!).with("/usr/sbin/groupdel", "test")

      subject.perform
    end

    context "when the command for deleting the group successes" do
      it "returns a successful result" do
        result = subject.perform

        expect(result.success?).to eq(true)
      end
    end

    context "when the command for deleting the group fails" do
      before do
        allow(Yast::Execute).to receive(:on_target!)
          .and_raise(Cheetah::ExecutionFailed.new(nil, nil, nil, nil))
      end

      it "returns a failed result with an issue" do
        allow(Yast::Execute).to receive(:on_target!)
          .and_raise(Cheetah::ExecutionFailed.new(nil, nil, nil, nil))

        result = subject.perform

        expect(result.success?).to eq(false)
        expect(result.issues.first.message).to match(/could not be deleted/)
      end
    end
  end
end
