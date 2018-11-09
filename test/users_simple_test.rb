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

require_relative "test_helper"

Yast.import "UsersSimple"
Yast.import "SSHAuthorizedKeys"

describe Yast::UsersSimple do
  subject(:users) { Yast::UsersSimple }

  describe "#SetRootPublicKey" do
    it "sets the root public key" do
      expect { users.SetRootPublicKey("ssh-rsa ...") }
        .to change { users.GetRootPublicKey }.to("ssh-rsa ...")
    end
  end

  describe "#Write" do
    context "when a public key for the root was given" do
      before do
        users.SetRootPublicKey("ssh-rsa ...")
      end

      it "writes the public key" do
        expect(Yast::SSHAuthorizedKeys).to receive(:write_keys)
          .with("/root", ["ssh-rsa ..."])
        users.Write()
      end
    end

    context "when no public key for the root was given" do
      before do
        users.SetRootPublicKey("")
      end

      it "does not try to write any public key" do
        expect(Yast::SSHAuthorizedKeys).to_not receive(:write_keys)
        users.Write()
      end
    end
  end
end
