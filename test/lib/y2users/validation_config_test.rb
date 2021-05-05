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

describe Y2Users::ValidationConfig do
  describe "#check_ca?" do
    before do
      allow(Yast::ProductFeatures).to receive(:GetBooleanFeature)
        .with("globals", "root_password_ca_check")
        .and_return(ca_check)
    end

    context "if CA password check is enabled" do
      let(:ca_check) { true }

      it "returns true" do
        expect(subject.check_ca?).to eq true
      end
    end

    context "if ca password check is disabled" do
      let(:ca_check) { false }

      it "returns false" do
        expect(subject.check_ca?).to eq false
      end
    end

    context "if ca password check is not set" do
      let(:ca_check) { nil }

      it "returns false" do
        expect(subject.check_ca?).to eq false
      end
    end
  end
end
