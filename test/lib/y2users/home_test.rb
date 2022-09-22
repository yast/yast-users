#!/usr/bin/env rspec

# Copyright (c) [2021-2022] SUSE LLC
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
require "y2users/home"

describe Y2Users::Home do
  subject { described_class.new }

  describe "#btrfs_subvol?" do
    before do
      subject.btrfs_subvol = value
    end

    context "when the value is set to nil" do
      let(:value) { nil }

      it "returns false" do
        expect(subject.btrfs_subvol?).to eq(false)
      end
    end

    context "when the value is set to false" do
      let(:value) { false }

      it "returns false" do
        expect(subject.btrfs_subvol?).to eq(false)
      end
    end

    context "when the value is set to true" do
      let(:value) { true }

      it "returns true" do
        expect(subject.btrfs_subvol?).to eq(true)
      end
    end
  end

  describe "#==" do
    before do
      subject.path = "/home/test"
      subject.permissions = "0777"
      subject.btrfs_subvol = true
    end

    context "when all the attributes are equal" do
      let(:other) { subject.dup }

      it "returns true" do
        expect(subject == other).to eq(true)
      end
    end

    context "when the #path does not match" do
      let(:other) do
        subject.dup.tap { |h| h.path = "/home/other" }
      end

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end

    context "when the #permissions does not match" do
      let(:other) do
        subject.dup.tap { |h| h.permissions = "0744" }
      end

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end

    context "when the #btrfs_subvol does not match" do
      let(:other) do
        subject.dup.tap { |h| h.btrfs_subvol = false }
      end

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end
  end

  describe "path?" do
    before do
      subject.path = path
    end

    context "if the path is nil" do
      let(:path) { nil }

      it "returns false" do
        expect(subject.path?).to eq(false)
      end
    end

    context "if the path is empty" do
      let(:path) { "" }

      it "returns false" do
        expect(subject.path?).to eq(false)
      end
    end

    context "if the path is not empty" do
      let(:path) { "/home/test" }

      it "returns true" do
        expect(subject.path?).to eq(true)
      end
    end
  end
end
