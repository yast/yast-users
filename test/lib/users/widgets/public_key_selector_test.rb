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
require "users/widgets/public_key_selector"
require "cwm/rspec"

describe Y2Users::Widgets::PublicKeySelector do
  subject(:widget) { described_class.new }

  include_examples "CWM::CustomWidget"

  let(:blk_devices) { [] }
  let(:key) { Y2Users::SSHPublicKey.new(File.read(FIXTURES_PATH.join("id_rsa.pub"))) }

  before do
    allow(Y2Users::LeafBlkDevice).to receive(:all).and_return(blk_devices)
    described_class.selected_blk_device_name = nil
    described_class.value = nil
  end

  describe "#contents" do
    let(:blk_devices) { [usb_with_fs, usb_no_fs, squashfs, no_transport] }

    let(:usb_with_fs) do
      Y2Users::LeafBlkDevice.new(
        name: "/dev/sdb1", model: "MyBrand 8G", disk: "/dev/sdb", transport: :usb,
        fstype: :vfat
      )
    end

    let(:usb_no_fs) do
      Y2Users::LeafBlkDevice.new(
        name: "/dev/sdc1", model: "MyBrand 4G", disk: "/dev/sdc", transport: :usb,
        fstype: nil
      )
    end

    let(:squashfs) do
      Y2Users::LeafBlkDevice.new(
        name: "/dev/some", model: "MyBrand 4G", disk: "/dev/sdc", transport: :unknown,
        fstype: :squashfs
      )
    end

    let(:no_transport) do
      Y2Users::LeafBlkDevice.new(
        name: "/dev/loop1", model: "MyBrand 8G", disk: "/dev/sdb", transport: nil,
        fstype: :unknown
      )
    end

    before do
      allow(widget).to receive(:value).and_return(value)
    end

    context "block device selector" do
      let(:value) { nil }

      it "includes devices containing a filesystem" do
        expect(widget.contents.to_s).to include("/dev/sdb1")
      end

      it "does not include devices which does not have a filesystem" do
        expect(widget.contents.to_s).to_not include("/dev/sdc1")
      end

      it "does not include devices which has a squashfs filesystem" do
        expect(widget.contents.to_s).to_not include("/dev/loop1")
      end

      it "does not include devices which does not have a transport" do
        expect(widget.contents.to_s).to_not include("/dev/loop1")
      end

      context "when a key is selected" do
        let(:value) { key }

        it "is not displayed" do
          expect(widget.contents.to_s).to_not include("MyBrand")
        end
      end
    end

    context "public key summary" do
      let(:value) { key }

      it "includes the key fingerprint and the comment" do
        expect(widget.contents.to_s).to include(key.formatted_fingerprint)
        expect(widget.contents.to_s).to include(key.comment)
      end

      context "when no key is selected" do
        let(:value) { nil }

        it "is not displayed" do
          expect(widget.contents.to_s).to_not include(key.comment)
        end
      end
    end
  end

  describe "#handle" do
    context "searching for a key" do
      let(:tmpdir) { TESTS_PATH.join("tmp") }
      let(:event) { { "ID" => :browse } }
      let(:disk) { "/dev/sr0" }
      let(:mounted?) { true }

      before do
        allow(Dir).to receive(:mktmpdir).and_return(tmpdir.to_s)

        allow(subject).to receive(:selected_blk_device_name).and_return(disk)
        allow(Yast::UI).to receive(:QueryWidget).with(Id(:blk_device), :Value)
          .and_return(disk)
        allow(Yast::SCR).to receive(:Execute)
          .with(Yast::Path.new(".target.mount"), ["/dev/sr0", tmpdir.to_s], "-o ro")
          .and_return(mounted?)
        allow(Yast::SCR).to receive(:Execute)
          .with(Yast::Path.new(".target.umount"), tmpdir.to_s)
        FileUtils.mkdir(tmpdir)
      end

      context "when the user selects a key" do
        let(:key_path) { FIXTURES_PATH.join("id_rsa.pub") }
        let(:key_content) { File.read(key_path).strip }

        before do
          allow(Yast::UI).to receive(:AskForExistingFile).with(tmpdir.to_s, "*.pub", anything)
            .and_return(key_path)
        end

        it "reads the key" do
          widget.handle(event)
          expect(widget.value.to_s).to eq(key_content)
        end

        it "saves the key for later use" do
          widget.handle(event)
          expect(described_class.value.to_s).to eq(key_content)
        end
      end

      context "when the user cancels the dialog" do
        let(:key_path) { nil }

        it "does not import any value" do
          widget.handle(event)
          expect(widget.value).to be_nil
        end
      end

      context "when the selected device cannot be mounted" do
        let(:mounted?) { false }

        it "reports the problem" do
          expect(Yast2::Popup).to receive(:show)
          widget.handle(event)
        end
      end

      it "saves the selected device for later use" do
        expect { widget.handle(event) }.to change { described_class.selected_blk_device_name }
          .from(nil).to("/dev/sr0")
      end
    end

    context "removing the key" do
      let(:event) { { "ID" => :remove } }

      before do
        described_class.value = key
      end

      it "removes the current key" do
        expect { widget.handle(event) }.to change { widget.value }.from(key).to(nil)
      end
    end

    context "refreshing the devices list" do
      let(:event) { { "ID" => :refresh } }

      it "refreshes the devices list" do
        widget.contents
        widget.handle(event)
        widget.contents
      end
    end
  end

  describe "#store" do
    before do
      allow(widget).to receive(:value).and_return(key)
    end

    context "when a key was read" do
      it "imports the key" do
        expect(Yast::SSHAuthorizedKeys).to receive(:import_keys).with("/root", [key.to_s])
        widget.store
      end
    end

    context "when no key was read" do
      let(:key) { nil }

      it "does not try to import any key" do
        expect(Yast::SSHAuthorizedKeys).to_not receive(:import_keys)
        widget.store
      end
    end
  end

  describe "#empty?" do
    before do
      allow(subject).to receive(:value).and_return(key)
    end

    context "when no key is selected" do
      let(:key) { nil }

      it "returns true" do
        expect(widget).to be_empty
      end
    end

    context "when key is selected" do
      let(:key) { instance_double(Y2Users::SSHPublicKey) }

      it "returns false" do
        expect(widget).to_not be_empty
      end
    end
  end
end
