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

require "date"
require "y2users/user"
require "y2users/linux/remove_home_content_action"

describe Y2Users::Linux::RemoveHomeContentAction do
  subject(:action) { described_class.new(user) }
  let(:user) { Y2Users::User.new("test") }

  before do
    allow(Yast::Execute).to receive(:on_target!)
  end

  describe "#perform" do

    it "removes content with find -mindepth 1 -delete" do
      expect(Yast::Execute).to receive(:on_target!) do |cmd, *args|
        expect(cmd).to eq "/usr/bin/find"
        expect(args).to include "-mindepth"
        expect(args).to include "1"
        expect(args).to include "-delete"
      end

      action.perform
    end

    it "passes user home as parameter" do
      user.home.path = "/tmp/home"

      expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
        expect(args).to include "/tmp/home"
      end

      action.perform
    end

    it "returns result without success and with issues if cmd failed" do
      allow(Yast::Execute).to receive(:on_target!)
        .and_raise(Cheetah::ExecutionFailed.new(nil, double(exitstatus: 1), nil, nil))

      result = action.perform
      expect(result.success?).to eq false
      expect(result.issues).to_not be_empty
    end
  end
end
