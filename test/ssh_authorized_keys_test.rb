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
  let(:authorized_keys_path) { File.join("ssh_dir", ".authorized_keys") }
  let(:key) { double("key") }
  let(:keys) { [key] }
  let(:keyring) { instance_double(Yast::Users::SSHAuthorizedKeyring, add_keys: []) }

  before do
    allow(Yast::Users::SSHAuthorizedKeyring).to receive(:new).and_return(keyring)
  end

  describe "#write_keys" do
    context "when home directory does not exists" do
      let(:exception) do
        Yast::Users::SSHAuthorizedKeyring::HomeDoesNotExist.new(home)
      end

      it "shows an error message" do
        allow(keyring).to receive(:write_keys).and_raise(exception)
        expect(Yast::Report).to receive(:Warning)
          .with(/'#{home}' does not exist/)
        subject.write_keys(home, ["ssh-rsa ..."])
      end
    end

    context "SSH directory is not a directory" do
      let(:exception) do
        Yast::Users::SSHAuthorizedKeyring::NotRegularSSHDirectory.new(ssh_dir)
      end

      it "shows an error message" do
        allow(keyring).to receive(:write_keys).and_raise(exception)
        expect(Yast::Report).to receive(:Warning)
          .with(/'#{ssh_dir}' exists but it is not a directory/)
        subject.write_keys(home, ["ssh-rsa ..."])
      end
    end

    context "SSH directory could not be created" do
      let(:exception) do
        Yast::Users::SSHAuthorizedKeyring::CouldNotCreateSSHDirectory.new(ssh_dir)
      end

      it "shows an error message" do
        allow(keyring).to receive(:write_keys).and_raise(exception)
        expect(Yast::Report).to receive(:Warning)
          .with(/not create directory '#{ssh_dir}'/)
        subject.write_keys(home, ["ssh-rsa ..."])
      end
    end

    context "authorized_keys exists but it's not a regular file" do
      let(:exception) do
        Yast::Users::SSHAuthorizedKeyring::NotRegularAuthorizedKeysFile.new(authorized_keys_path)
      end

      it "shows an error message" do
        allow(keyring).to receive(:write_keys).and_raise(exception)
        expect(Yast::Report).to receive(:Warning)
          .with(/'#{authorized_keys_path}' exists but it is not a file/)
        subject.write_keys(home, ["ssh-rsa ..."])
      end
    end
  end
end
