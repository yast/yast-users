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
require "y2users"

describe Y2Users::UseraddConfig do
  describe ".writable_attributes" do
    it "returns an array of symbols" do
      expect(described_class.writable_attributes).to all be_a(Symbol)
    end

    it "does not include :skel or :usrskel" do
      expect(described_class.writable_attributes).to_not include(:skel, :usrskel)
    end
  end
end
