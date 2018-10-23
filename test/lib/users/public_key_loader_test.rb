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
require "users/public_key_loader"

describe Y2Users::PublicKeyLoader do
  subject(:loader) { described_class.new }

  describe "#from_usb_stick" do
    PUBKEY_CONTENT = File.read(FIXTURES_PATH.join("home", "user1", ".ssh", "id_rsa.pub")).strip
    let(:tmpdir) { Dir.mktmpdir }

    before do
      allow(Dir).to receive(:mktmpdir).and_return(tmpdir)
      allow(loader).to receive(:get_file_from_url) do |args|
        source = FIXTURES_PATH.join("home", "user1", ".ssh", args[:urlpath][1..-1])
        target = File.join(args[:destdir], args[:localfile])
        FileUtils.cp(source, target) if File.exist?(source)
      end
    end

    let(:rsa_content) do
      File.readlines(FIXTURES_PATH)
    end

    it "retrieves existing keys" do
      expect(loader.from_usb_stick).to eq([PUBKEY_CONTENT])
    end
  end
end
