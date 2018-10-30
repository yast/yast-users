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
require "users/widgets/public_keys_list"
require "users/ssh_public_key"
require "cwm/rspec"

describe Y2Users::Widgets::PublicKeysList do
  subject(:widget) { described_class.new(keys) }

  include_examples "CWM::CustomWidget"

  let(:key1) { instance_double(Y2Users::SSHPublicKey, fingerprint: "SHA256:123", comment: "") }
  let(:key2) { instance_double(Y2Users::SSHPublicKey, fingerprint: "SHA256:456", comment: "") }
  let(:keys) { [key1, key2] }

  describe "#handle" do
    let(:event) { { "ID" => "remove_0" } }

    it "removes the selected key" do
      widget.handle(event)
      expect(widget.keys).to eq([key2])
    end
  end

  describe "#add" do
    let(:key3) { instance_double(Y2Users::SSHPublicKey, fingerprint: "SHA256:456", comment: "") }

    it "adds the key and updates the list" do
      expect(widget).to receive(:change_items).with([key1, key2, key3]).and_call_original
      widget.add(key3)
      expect(widget.keys).to eq([key1, key2, key3])
    end
  end

  describe "#change_items" do
    it "updates the keys list" do
      expect(Yast::UI).to receive(:ReplaceWidget).with(:public_keys_list_items, Yast::Term)
      widget.change_items([key1])
      expect(widget.keys).to eq([key1])
    end
  end

  describe "#empty?" do
    context "when the list does not contain any key" do
      let(:keys) { [] }

      it "returns true" do
        expect(widget).to be_empty
      end
    end

    context "when the list contains some key" do
      let(:keys) { [key1] }

      it "returns false" do
        expect(widget).to_not be_empty
      end
    end
  end
end
