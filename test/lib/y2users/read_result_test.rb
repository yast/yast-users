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
require "y2issues"

describe Y2Users::ReadResult do
  subject(:result) { Y2Users::ReadResult.new(config, issues) }

  let(:config) { Y2Users::Config.new }
  let(:issues) { Y2Issues::List.new }

  describe "#issues?" do
    context "when some issue is registered" do
      before do
        issues << Y2Issues::InvalidValue.new("dummy", location: nil)
      end

      it "returns true" do
        expect(result.issues?).to eq(true)
      end
    end

    context "when no issues are registered" do
      it "returns false" do
        expect(result.issues?).to eq(false)
      end
    end
  end
end
