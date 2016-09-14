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
require "tmpdir"

Yast.import "SSHAuthorizedKeys"

describe Yast::SSHAuthorizedKeys do
  subject(:ssh_authorized_keys) { Yast::SSHAuthorizedKeys }

  let(:valid_key_spec) { double("valid_key") }
  let(:invalid_key_spec) { double("invalid_key") }
  let(:home) { "/home/user" }
  let(:key) { double("key") }

  before do
    allow(Yast::Users::SSHAuthorizedKey).to receive(:build_from)
      .with(valid_key_spec)
      .and_return(key)
    allow(Yast::Users::SSHAuthorizedKey).to receive(:build_from)
      .with(invalid_key_spec)
      .and_return(nil)
    ssh_authorized_keys.main
  end

  describe "#import_keys" do
    context "given an array which contains some valid keys specifications" do
      let(:keys) { [valid_key_spec, invalid_key_spec] }

      it "returns true" do
        expect(subject.import_keys(home, keys)).to eq(true)
      end

      it "registers given keys" do
        subject.import_keys(home, keys)
        expect(subject.keyring[home]).to eq([key])
      end
    end

    context "given an array which does not contain valid keys specifications" do
      let(:keys) { [invalid_key_spec] }

      it "returns false" do
        expect(subject.import_keys(home, keys)).to eq(false)
      end

      it "does not register any key" do
        subject.import_keys(home, keys)
        expect(subject.keyring[home]).to be_empty
      end
    end
  end

  describe "#export_keys" do
    let(:home) { "/home/user" }

    context "when some key was registered for the given home" do
      let(:key) do
        double("key", options: "tunnel=0", keytype: "ssh-rsa", content: "123ABC",
          comment: "user@example.net")
      end

      before { subject.import_keys(home, [valid_key_spec]) }

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
      it "returns an empty array" do
        expect(subject.export_keys(home)).to eq([])
      end
    end
  end
end
