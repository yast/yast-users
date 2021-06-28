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
require "y2users/shadow_date"
require "date"

describe Y2Users::ShadowDate do
  subject { described_class.new(value) }

  describe "#to_s" do
    context "when created from a numeric string" do
      let(:value) { "1111" }

      it "returns the same numeric string" do
        expect(subject.to_s).to eq(value)
      end
    end

    context "when created from a date" do
      let(:value) { Date.new(1973, 1, 16) }

      it "returns a string representing the date as the number of days since 1970-01-01" do
        expect(subject.to_s).to eq("1111")
      end
    end
  end

  describe "#to_date" do
    context "when created from a numeric string" do
      let(:value) { "1111" }

      it "returns a date object correspoding to the given number" do
        date = Date.new(1973, 1, 16)

        expect(subject.to_date).to eq(date)
      end
    end

    context "when created from a date" do
      let(:value) { Date.new(1973, 1, 16) }

      it "returns the same date" do
        expect(subject.to_date).to eq(value)
      end
    end
  end
end
