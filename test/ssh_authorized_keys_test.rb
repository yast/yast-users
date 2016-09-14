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

require_relative "test_helper"

Yast.import "SSHAuthorizedKeys"

describe Yast::SSHAuthorizedKeys do
  subject(:ssh_authorized_keys) { Yast::SSHAuthorizedKeys }

  before { ssh_authorized_keys.main }

  describe "#read_keys" do
    context "if some keys are present in the given home directory" do
      let(:home) { FIXTURES_PATH.join("home", "user1").to_s }

      it "returns true" do
        expect(subject.read_keys(home)).to eq(true)
      end

      it "registers defined keys" do
        subject.read_keys(home)
        expect(subject.keys).to_not be_empty
      end
    end

    context "if no keys are present in the home directory" do
      let(:home) { FIXTURES_PATH.join("home", "user2").to_s }

      it "returns false" do
        expect(subject.read_keys(home)).to eq(false)
      end

      it "does not register any key" do
        subject.read_keys(home)
        expect(subject.keys).to eq({})
      end
    end

    context "if authorized keys file does not exist" do
      let(:home) { FIXTURES_PATH.join("home", "other").to_s }

      it "returns false" do
        expect(subject.read_keys(home)).to eq(false)
      end

      it "does not register any key" do
        subject.read_keys(home)
        expect(subject.keys).to eq({})
      end
    end
  end

  describe "#import_keys" do
    let(:home) { "/home/user" }
    let(:valid_key_spec) { double("valid_key") }
    let(:invalid_key_spec) { double("invalid_key") }
    let(:key) { double("key") }

    before do
      allow(Yast::Users::SSHAuthorizedKey).to receive(:build_from).with(valid_key_spec)
        .and_return(key)
      allow(Yast::Users::SSHAuthorizedKey).to receive(:build_from).with(invalid_key_spec)
        .and_return(nil)
    end

    context "given an array which contains some valid keys specifications" do
      let(:keys) { [valid_key_spec, invalid_key_spec] }

      it "returns true" do
        expect(subject.import_keys(home, keys)).to eq(true)
      end

      it "registers given keys" do
        subject.import_keys(home, keys)
        expect(subject.keys).to eq({home => [key]})
      end
    end

    context "given an array which does not contain valid keys specifications" do
      let(:keys) { [invalid_key_spec] }

      it "returns false" do
        expect(subject.import_keys(home, keys)).to eq(false)
      end

      it "does not register any key" do
        subject.import_keys(home, keys)
        expect(subject.keys).to be_empty
      end
    end
  end

  describe "#write_keys" do
    let(:home) { "/home/user" }
    let(:file) { double("file", save: true) }

    before do
      allow(Yast::Users::SSHAuthorizedKeysFile)
        .to receive(:new).and_return(file)
    end

    context "if no keys are registered for the given home" do
      it "returns false" do
        expect(subject.write_keys(home)).to eq(false)
      end

      it "does not try to write the keys" do
        expect(file).to_not receive(:save)
        subject.write_keys(home)
      end
    end

    context "if some keys are registerd for the given home" do
      before do
        subject.import_keys(home, ["ssh-rsa 123ABC"])
        allow(file).to receive(:keys=)
      end

      it "returns true" do
        expect(subject.write_keys(home)).to eq(true)
      end

      it "writes the keys" do
        expect(Yast::Users::SSHAuthorizedKeysFile).to receive(:new)
          .with(File.join(home, ".ssh", "authorized_keys"))
          .and_return(file)
        expect(file).to receive(:keys=)
          .with(subject.keys[home])
        expect(file).to receive(:save)
        subject.write_keys(home)
      end
    end
  end

  describe "#export_keys" do
    let(:home) { "/home/user" }

    before do
      allow(subject).to receive(:keys).and_return({home => keys})
    end

    context "when some key was registered for the given home" do
      let(:key) do
        double("key", options: "tunnel=0", keytype: "ssh-rsa", content: "123ABC",
          comment: "user@example.net")
      end
      let(:keys) { [key] }

      it "returns a hash describing the keys" do
        expect(subject.export_keys(home)).to eq([{
          "options" => key.options,
          "comment" => key.comment,
          "content" => key.content,
          "keytype" => key.keytype
        }])
      end
    end

    context "when no key was registered for the given home" do
      let(:keys) { [] }

      it "returns an empty array" do
        expect(subject.export_keys(home)).to eq([])
      end
    end
  end
end
