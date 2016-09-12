#!/usr/bin/rspec
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
        expect(first.options).to eq(
          'environment="PATH=/usr/local/bin:$PATH",command="/srv/logon.sh $USER"')
        expect(first.keytype).to eq("ssh-rsa")
        expect(first.content).to match /DDY3Kcr/
        expect(first.comment).to eq("dummy1@example.net")
        expect(second.options).to be_nil
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
    let(:key) { Yast::Users::SSHAuthorizedKey.new(keytype: "ssh-dsa", content: "123ABC") }

    it "sets file keys" do
      file.keys = [key]
      expect(file.keys).to eq([key])
    end
  end

  describe "#save" do
    let(:key0) { Yast::Users::SSHAuthorizedKey.new(keytype: "ssh-dsa", content: "123ABC") }
    let(:key1) { Yast::Users::SSHAuthorizedKey.new(keytype: "ssh-rsa", content: "456DEF") }

    let(:path) { "/tmp/home/user" }
    let(:dir)  { File.dirname(path) }
    let(:dir_exists) { true }

    before do
      allow(Yast::FileUtils).to receive(:Exists).with(dir)
        .and_return(dir_exists)
    end

    it "creates the file with the registered keys" do
      content = "ssh-dsa 123ABC\nssh-rsa 456DEF\n"
      expect(Yast::SCR).to receive(:Write)
        .with(Yast::Path.new(".target.string"), path, content)
      file.keys = [key0, key1]
      file.save
    end

    context "if the directory does not exist" do
      let(:dir_exists) { false }

      it "creates the directory" do
        expect(Yast::SCR).to receive(:Execute)
          .with(Yast::Path.new(".target.mkdir"), dir.to_s)
        allow(Yast::SCR).to receive(:Write).and_return(true)
        file.keys = [key0, key1]
        file.save
      end
    end
  end
end
