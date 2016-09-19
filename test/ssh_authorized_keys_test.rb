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

require_relative "test_helper"
require "users/ssh_authorized_keyring"
require "tmpdir"

Yast.import "SSHAuthorizedKeys"
Yast.import "Report"

describe Yast::SSHAuthorizedKeys do
  subject(:ssh_authorized_keys) { Yast::SSHAuthorizedKeys }

  let(:valid_key_spec) { double("valid_key") }
  let(:invalid_key_spec) { double("invalid_key") }
  let(:home) { "/home/user" }
  let(:key) { double("key") }
  let(:keys) { [key] }

  before { subject.main }

  describe "#import_keys" do
    it "imports keys into the keyring" do
      expect(subject.keyring).to receive(:add_keys).with(home, keys)
        .and_return(keys)
      subject.import_keys(home, keys)
    end

    it "returns true if some key was imported" do
      allow(subject.keyring).to receive(:add_keys).with(home, keys)
        .and_return(keys)
      expect(subject.import_keys(home, keys)).to eq(true)
    end

    it "returns false if no key was imported" do
      allow(subject.keyring).to receive(:add_keys).with(home, keys)
        .and_return(keys)
      expect(subject.import_keys(home, keys)).to eq(true)
    end
  end

  describe "#export_keys" do
    context "when some key was added" do
      before { subject.import_keys(home, keys) }

      it "returns an array with added keys" do
        expect(subject.export_keys(home)).to eq(keys)
      end
    end

    context "when no key was added" do
      it "returns an empty array" do
        expect(subject.export_keys(home)).to eq([])
      end
    end
  end

  describe "#write_keys" do
    context "when home directory does not exists" do
      it "shows an error message" do
        allow(subject.keyring).to receive(:write_keys)
          .and_raise(Yast::Users::SSHAuthorizedKeyring::HomeDoesNotExist)
        expect(Yast::Report).to receive(:Warning)
          .with("Home directory '#{home}' does not exist\n" \
                "so authorized keys won't be written.")
        subject.write_keys(home)
      end
    end

    context "SSH directory is a link" do
      it "shows an error message" do
        allow(subject.keyring).to receive(:write_keys)
          .and_raise(Yast::Users::SSHAuthorizedKeyring::SSHDirectoryIsLink)
        expect(Yast::Report).to receive(:Warning)
          .with("SSH directory under '#{home}' is a symbolic link.\n" \
                "It may cause a security issue so authorized\n" \
                "keys won't be written.")
        subject.write_keys(home)
      end
    end

    context "SSH directory could not be created" do
      it "shows an error message" do
        allow(subject.keyring).to receive(:write_keys)
          .and_raise(Yast::Users::SSHAuthorizedKeyring::CouldNotCreateSSHDirectory)
        expect(Yast::Report).to receive(:Warning)
          .with("Could not create SSH directory under '#{home}',\n"\
                "so authorized keys won't be written.")
        subject.write_keys(home)
      end
    end
  end
end
