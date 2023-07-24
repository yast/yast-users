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

require_relative "test_helper"
require "y2users/user_commit_config"

describe Y2Users::UserCommitConfig do
  subject { described_class.new }

  describe "#home_without_skel?" do
    before do
      subject.home_without_skel = value
    end

    context "when the value is set to nil" do
      let(:value) { nil }

      it "returns false" do
        expect(subject.home_without_skel?).to eq(false)
      end
    end

    context "when the value is set to false" do
      let(:value) { false }

      it "returns false" do
        expect(subject.home_without_skel?).to eq(false)
      end
    end

    context "when the value is set to true" do
      let(:value) { true }

      it "returns true" do
        expect(subject.home_without_skel?).to eq(true)
      end
    end
  end

  describe "#move_home?" do
    before do
      subject.move_home = value
    end

    context "when the value is set to nil" do
      let(:value) { nil }

      it "returns false" do
        expect(subject.move_home?).to eq(false)
      end
    end

    context "when the value is set to false" do
      let(:value) { false }

      it "returns false" do
        expect(subject.move_home?).to eq(false)
      end
    end

    context "when the value is set to true" do
      let(:value) { true }

      it "returns true" do
        expect(subject.move_home?).to eq(true)
      end
    end
  end

  describe "#adapt_home_ownership?" do
    before do
      subject.adapt_home_ownership = value
    end

    context "when the value is set to nil" do
      let(:value) { nil }

      it "returns false" do
        expect(subject.adapt_home_ownership?).to eq(false)
      end
    end

    context "when the value is set to false" do
      let(:value) { false }

      it "returns false" do
        expect(subject.adapt_home_ownership?).to eq(false)
      end
    end

    context "when the value is set to true" do
      let(:value) { true }

      it "returns true" do
        expect(subject.adapt_home_ownership?).to eq(true)
      end
    end
  end
end
