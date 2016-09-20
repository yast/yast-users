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
  let(:ssh_dir) { File.join(home, ".ssh") }
  let(:key) { double("key") }
  let(:keys) { [key] }

  before { subject.reset }

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
        .and_return([])
      expect(subject.import_keys(home, keys)).to eq(false)
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
      let(:exception) { Yast::Users::SSHAuthorizedKeyring::HomeDoesNotExist.new(home) }

      it "shows an error message" do
        allow(subject.keyring).to receive(:write_keys).and_raise(exception)
        expect(Yast::Report).to receive(:Warning)
          .with(/'#{exception.directory}' does not exist/)
        subject.write_keys(home)
      end
    end

    context "SSH directory is not a directory" do
      let(:exception) { Yast::Users::SSHAuthorizedKeyring::NotRegularSSHDirectory.new(ssh_dir)}

      it "shows an error message" do
        allow(subject.keyring).to receive(:write_keys).and_raise(exception)
        expect(Yast::Report).to receive(:Warning)
          .with(/'#{ssh_dir}' exists but it is not a directory/)
        subject.write_keys(home)
      end
    end

    context "SSH directory could not be created" do
      let(:exception) { Yast::Users::SSHAuthorizedKeyring::CouldNotCreateSSHDirectory.new(ssh_dir) }
      it "shows an error message" do
        allow(subject.keyring).to receive(:write_keys).and_raise(exception)
        expect(Yast::Report).to receive(:Warning)
          .with(/not create.+'#{ssh_dir}'/)
        subject.write_keys(home)
      end
    end
  end
end
