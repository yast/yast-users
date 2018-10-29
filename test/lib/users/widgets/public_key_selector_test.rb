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

  describe "#handle" do
    let(:tmpdir) { TESTS_PATH.join("tmp") }
    let(:event) { { "ID" => :browse } }
    let(:value) { "/dev/sr0" }
    let(:disk_selector) { instance_double(Y2Users::Widgets::DiskSelector, value: value) }
    let(:mounted?) { true }

    before do
      allow(Dir).to receive(:mktmpdir).and_return(tmpdir.to_s)

      allow(Y2Users::Widgets::DiskSelector).to receive(:new).and_return(disk_selector)
      allow(Yast::SCR).to receive(:Execute)
        .with(Yast::Path.new(".target.mount"), ["/dev/sr0", tmpdir.to_s], "-o ro")
        .and_return(mounted?)
      allow(Yast::SCR).to receive(:Execute)
        .with(Yast::Path.new(".target.umount"), tmpdir.to_s)
      FileUtils.mkdir(tmpdir)
    end

    # around do |example|
    #   example.run
    #   FileUtils.rm_r(tmpdir) if tmpdir.exist?
    # end
     
    context "when the user selects a key" do
      let(:key_path) { FIXTURES_PATH.join("id_rsa.pub") }
      let(:key_content) { File.read(key_path).strip }

      before do
        allow(Yast::UI).to receive(:AskForExistingFile).with(tmpdir.to_s, "*", anything)
          .and_return(key_path)
      end

      it "reads the key" do
        widget.handle(event)
        expect(widget.value.to_s).to eq(key_content)
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
  end

  describe "#store" do
    before do
      allow(widget).to receive(:value).and_return(value)
    end

    context "when a key was read" do
      let(:value) do
        Y2Users::SSHPublicKey.new(File.read(FIXTURES_PATH.join("id_rsa.pub")))
      end

      it "imports the key" do
        expect(Yast::SSHAuthorizedKeys).to receive(:import_keys).with("/root", [value.to_s])
        widget.store
      end
    end

    context "when no key was read" do
      let(:value) { nil }

      it "does not try to import the key" do
        expect(Yast::SSHAuthorizedKeys).to_not receive(:import_keys)
        widget.store
      end
    end
  end
end
