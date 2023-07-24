#!/usr/bin/env rspec

# Copyright (c) [2021-2023] SUSE LLC
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

require_relative "../test_helper"

require "y2users/linux/set_auth_keys_action"
require "y2users/user"

describe Y2Users::Linux::SetAuthKeysAction do
  subject(:action) { described_class.new(user) }
  let(:user) do
    Y2Users::User.new("test").tap do |user|
      user.home.path = "/home/test"
      user.authorized_keys = ["test"]
    end
  end

  describe "#perform" do
    it "calls SSHAuthorizedKeyring#write_keys" do
      obj = double(Yast::Users::SSHAuthorizedKeyring)
      expect(obj).to receive(:write_keys)
      expect(obj).to receive(:add_keys).with(["test"])
      expect(Yast::Users::SSHAuthorizedKeyring).to receive(:new).with("/home/test", [])
        .and_return(obj)

      subject.perform
    end

    it "returns result without success and with issues if cmd failed" do
      obj = double(Yast::Users::SSHAuthorizedKeyring)
      expect(obj).to receive(:add_keys).with(["test"])
      expect(obj).to receive(:write_keys)
        .and_raise(Yast::Users::SSHAuthorizedKeyring::PathError, "/home/test")
      expect(Yast::Users::SSHAuthorizedKeyring).to receive(:new).with("/home/test", [])
        .and_return(obj)

      result = action.perform
      expect(result.success?).to eq false
      expect(result.issues).to_not be_empty
    end
  end
end
