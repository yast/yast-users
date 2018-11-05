#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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

require_relative "../../test_helper"
require "users/leaf_blk_device"

describe Y2Users::LeafBlkDevice do
  describe ".all" do
    let(:lsblk_output) { File.read(FIXTURES_PATH.join("lsblk.txt")) }

    before do
      allow(Yast::Execute).to receive(:locally).and_return(lsblk_output)
    end

    it "returns all leaf block devices" do
      expect(described_class.all).to contain_exactly(
        an_object_having_attributes(name: "/dev/sda1", fstype: :vfat),
        an_object_having_attributes(name: "/dev/sda2", fstype: :ext4),
        an_object_having_attributes(name: "/dev/sr0", fstype: nil),
        an_object_having_attributes(name: "/dev/sr1", fstype: :iso9660)
      )
    end

    context "when lsblk fails" do
      before do
        allow(Yast::Execute).to receive(:locally).and_return(nil)
      end

      it "returns an empty array" do
        expect(described_class.all).to eq([])
      end
    end
  end

  describe "#filesystem?" do
    let(:fstype) { "ext4" }

    subject do
      Y2Users::LeafBlkDevice.new(
        name: "/dev/sdb1", model: "MyBrand 8G", disk: "/dev/sdb", fstype: fstype
      )
    end

    context "when the device has a filesystem" do
      it "returns true" do
        expect(subject.filesystem?).to eq(true)
      end
    end

    context "when the device does not have a filesystem" do
      let(:fstype) { nil }

      it "returns false" do
        expect(subject.filesystem?).to eq(false)
      end
    end
  end

  describe "#transport?" do
    subject do
      Y2Users::LeafBlkDevice.new(
        name: "/dev/sdb1", model: "MyBrand 8G", disk: "/dev/sdb", fstype: "ext4",
        transport: transport
      )
    end

    context "when the device has a transport" do
      let(:transport) { "usb" }

      it "returns true" do
        expect(subject.transport?).to eq(true)
      end
    end

    context "when the device does not have a transport" do
      let(:transport) { nil }

      it "returns false" do
        expect(subject.transport?).to eq(false)
      end
    end
  end
end

