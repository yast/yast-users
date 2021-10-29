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
require "y2users/linux/reader"

describe Y2Users::Linux::Reader do
  describe "#read" do
    let(:passwd_content) { File.read(File.join(FIXTURES_PATH, "/root2/etc/passwd")) }
    let(:group_content)  { File.read(File.join(FIXTURES_PATH, "/root2/etc/group")) }
    let(:shadow_content) { File.read(File.join(FIXTURES_PATH, "/root2/etc/shadow")) }
    let(:root_home) { FIXTURES_PATH.join("home", "root").to_s }
    let(:expected_root_auth_keys) { authorized_keys_from(root_home) }

    around do |example|
      # Let's use test/fixtures/home as src root for reading authorized keys from there
      change_scr_root(FIXTURES_PATH.join("home")) { example.run }
    end

    before do
      # mock Yast::Execute calls and provide file content from fixture
      allow(Yast::Execute).to receive(:on_target!).with(/getent/, "passwd", anything)
        .and_return(passwd_content)
      allow(Yast::Execute).to receive(:on_target!).with(/getent/, "group", anything)
        .and_return(group_content)
      allow(Yast::Execute).to receive(:on_target!).with(/getent/, "shadow", anything)
        .and_return(shadow_content)
      allow(Yast::Execute).to receive(:on_target!).with(/useradd/, "-D", anything)
        .and_return(useradd_default_values)

      allow(Yast::ShadowConfig).to receive(:fetch)
      allow(Yast::ShadowConfig).to receive(:fetch).with(:umask).and_return("044")

      # mocks root aliases
      allow(Yast::MailAliases).to receive(:GetRootAlias).and_return("games, unknown, news")

      # mocks to check reading of home permissions
      allow(Dir).to receive(:exist?)
      allow(Dir).to receive(:exist?).with("/home/a_user").and_return(true)
      allow(Yast::Execute).to receive(:on_target!)
        .with("/usr/bin/stat", any_args, "/home/a_user", stdout: :capture)
        .and_return("700")
    end

    it "generates a config with read data" do
      config = subject.read

      expect(config).to be_a(Y2Users::Config)

      expect(config.users.size).to eq 19
      expect(config.groups.size).to eq 7

      root_user = config.users.root
      expect(root_user.uid).to eq "0"
      expect(root_user.home.path).to eq "/root"
      expect(root_user.shell).to eq "/bin/bash"
      expect(root_user.primary_group.name).to eq "root"
      expect(root_user.password.value.encrypted?).to eq true
      expect(root_user.password.value.content).to match(/^\$6\$pL/)
      expect(root_user.password.aging.content).to eq("16899")
      expect(root_user.password.account_expiration.content).to eq("")
      expect(root_user.authorized_keys).to eq(expected_root_auth_keys)

      useradd = config.useradd
      expect(useradd.group).to eq "100"
      expect(useradd.expiration).to eq ""
      expect(useradd.inactivity_period).to eq(-1)
      expect(useradd.create_mail_spool).to eq true
      expect(useradd.umask).to eq "044"

      expect(config.login?).to eq(false)
    end

    it "sets root aliases" do
      config = subject.read

      root_aliases = config.users.select(&:receive_system_mail?)

      expect(root_aliases.size).to eq 2
      expect(root_aliases.map(&:name)).to contain_exactly("games", "news")
    end

    it "sets home permissions (octal number starting by 0)" do
      config = subject.read

      user = config.users.by_name("a_user")
      expect(user.home.permissions).to eq("0700")
    end

    context "when there are login settings" do
      before do
        allow(Yast::Autologin).to receive(:Read)
        allow(Yast::Autologin).to receive(:used).and_return(true)
        allow(Yast::Autologin).to receive(:user).and_return("games")
        allow(Yast::Autologin).to receive(:pw_less).and_return(true)
      end

      it "generates the login config" do
        config = subject.read

        expect(config.login?).to eq(true)
        expect(config.login.autologin_user.name).to eq("games")
        expect(config.login.passwordless?).to eq(true)
      end
    end
  end
end
