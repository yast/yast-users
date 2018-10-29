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

require_relative "../../../test_helper"
require "users/widgets/disk_selector"
require "cwm/rspec"

describe Y2Users::Widgets::DiskSelector do
  include_examples "CWM::ComboBox"

  let(:devices) { [] }

  before do
    allow(Y2Users::LeafBlkDevice).to receive(:all).and_return(devices)
  end

  describe "#items" do
    let(:usb_with_fs) do
      Y2Users::LeafBlkDevice.new(
        name: "/dev/sdb1", model: "MyBrand 8G", disk: "/dev/sdb", fstype: :vfat, removable: true
      )
    end

    let(:usb_no_fs) do
      Y2Users::LeafBlkDevice.new(
        name: "/dev/sdc1", model: "MyBrand 4G", disk: "/dev/sdc", fstype: nil, removable: true
      )
    end

    let(:devices) { [usb_with_fs, usb_no_fs] }

    it "returns the list of devices containing a filesystem" do
      expect(subject.items).to eq([
        ["/dev/sdb1", "MyBrand 8G (/dev/sdb1)"]
      ])
    end
  end
end

