#!/usr/bin/env rspec

# Copyright (c) [2021] SUSE LLC
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

require "y2users/config"
require "y2users/linux/base_reader"

describe Y2Users::Linux::BaseReader do
  describe "#read" do
    let(:passwd_content) { File.read(File.join(FIXTURES_PATH, "/root/etc/passwd")) }
    let(:group_content)  { File.read(File.join(FIXTURES_PATH, "/root/etc/group")) }
    let(:shadow_content) { File.read(File.join(FIXTURES_PATH, "/root/etc/shadow")) }
    let(:root_home) { FIXTURES_PATH.join("home", "root").to_s }
    let(:expected_root_auth_keys) { authorized_keys_from(root_home) }

    before do
      allow(subject.log).to receive(:warn)

      # mock Yast::Execute calls and provide file content from fixture
      allow(subject).to receive(:load_users).and_return(passwd_content)
      allow(subject).to receive(:load_groups).and_return(group_content)
      allow(subject).to receive(:load_passwords).and_return(shadow_content)
    end

    it "generates a config with read data" do
      config = subject.read

      expect(config).to be_a(Y2Users::Config)

      expect(config.users.size).to eq 17
      expect(config.groups.size).to eq 36

      root_user = config.users.root
      expect(root_user.uid).to eq "0"
      expect(root_user.home.path).to eq "/root"
      expect(root_user.shell).to eq "/bin/bash"
      expect(root_user.primary_group.name).to eq "root"
      expect(root_user.password.value.encrypted?).to eq true
      expect(root_user.password.value.content).to match(/^\$6\$pL/)
    end

    it "logs warning if password found for not existing user" do
      shadow_content << "fakeuser:$6$fakepassword.:16899::::::\n"

      expect(subject.log).to receive(:warn).with(/Found password for.*fakeuser./)

      subject.read
    end
  end
end
