#!/usr/bin/env rspec
# Copyright (c) 2016 SUSE LLC.
#  All Rights Reserved.
#
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of version 2 or 3 of the GNU General
#  Public License as published by the Free Software Foundation.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, contact SUSE LLC.
#
#  To contact SUSE about this file by physical or electronic mail,
#  you may find current contact information at www.suse.com
require_relative "../../test_helper"
require "users/ssh_authorized_keys_file"

describe Yast::Users::SSHAuthorizedKeysFile do
  subject(:file) { Yast::Users::SSHAuthorizedKeysFile.new(path) }
  let(:path) { FIXTURES_PATH.join("home", "user1", ".ssh", "authorized_keys") }

  describe "#keys" do
    context "when file is empty" do
      let(:path) { FIXTURES_PATH.join("home", "user2", ".ssh", "authorized_keys") }

      it "returns an empty array" do
        expect(subject.keys).to eq([])
      end
    end

    context "when file contains some keys" do
      let(:path) { FIXTURES_PATH.join("home", "user1", ".ssh", "authorized_keys") }

      it "returns the keys that are present in the file" do
        first, second = subject.keys
        expect(first).to match(/environment=.+/)
        expect(second).to match(/ssh-rsa/)
      end
    end

    context "when file does not exist" do
      let(:path) { FIXTURES_PATH.join("non-existent-file") }

      it "returns an empty array" do
        expect(subject.keys).to eq([])
      end
    end
  end

  describe "#keys=" do
    let(:key) { "ssh-dsa 123ABC" }

    it "sets file keys" do
      file.keys = [key]
      expect(file.keys).to eq([key])
    end
  end

  describe "#save" do
    let(:key0) { "ssh-dsa 123ABC" }
    let(:key1) { "ssh-rsa 456DEF" }
    let(:expected_content) { "ssh-dsa 123ABC\nssh-rsa 456DEF\n" }

    let(:path) { "/tmp/home/user" }
    let(:dir)  { File.dirname(path) }

    before do
      allow(Yast::FileUtils).to receive(:Exists).with(dir)
        .and_return(dir_exists)
    end

    context "if the directory exists" do
      let(:dir_exists) { true }

      it "creates the file with the registered keys and returns true" do
        expect(Yast::SCR).to receive(:Write)
          .with(Yast::Path.new(".target.string"), path, expected_content)
        file.keys = [key0, key1]
        file.save
      end
    end

    context "if the directory does not exist" do
      let(:dir_exists) { false }

      it "returns false" do
        file.keys = [key0, key1]
        expect(file.save).to eq(false)
      end
    end
  end

  describe "#add_key" do
    let(:key) { "ssh-dsa 123ABC" }

    context "when the contains keys" do
      let(:path) { FIXTURES_PATH.join("home", "user1", ".ssh", "authorized_keys") }

      it "adds the new key" do
        file.add_key(key)
        expect(file.keys).to include(key)
      end
    end

    context "when the file does not contain keys" do
      let(:path) { FIXTURES_PATH.join("home", "user2", ".ssh", "authorized_keys") }

      it "adds the new key" do
        file.add_key(key)
        expect(file.keys).to eq([key])
      end
    end
  end
end
