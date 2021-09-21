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
require "y2users/users_module/reader"

describe Y2Users::UsersModule::Reader do
  let(:users) do
    [
      # real data with data dumper from perl after modifications in UI
      {
        "addit_data"        => "",
        "btrfs_subvolume"   => false,
        "chown_home"        => true,
        "cn"                => "test5",
        "create_home"       => true,
        "encrypted"         => true,
        "gidNumber"         => 100,
        "givenName"         => "",
        "grouplist"         => {
          "wheel" => 1
        },
        "groupname"         => "users",
        "homeDirectory"     => "/home/test5",
        "home_mode"         => "755",
        "loginShell"        => "/bin/bash",
        "modified"          => "added",
        "no_skeleton"       => true,
        "org_homeDirectory" => "/home/test5",
        "org_uid"           => "test5",
        "org_uidNumber"     => 1002,
        "plugins"           => [],
        "shadowExpire"      => "",
        "shadowFlag"        => "",
        "shadowInactive"    => "-1",
        "shadowLastChange"  => "18887",
        "shadowMax"         => "99999",
        "shadowMin"         => "0",
        "shadowWarning"     => "7",
        "sn"                => "",
        "text_userpassword" => "test",
        "type"              => "local",
        "uid"               => "test5",
        "uidNumber"         => 1002,
        "userPassword"      => "$6$CIrJOmyF8WBnHsAn$Sh.pjryO9CD.Dfm9KzDdVYYXblxiTw05b9b0GVpMbckbU" \
          "gK/fFvn7nM.ipqooa3Ks5fGgzV.6gPBGG1l8hs7L.",
        "what"              => "add_user"
      }
    ]
  end

  let(:sys_groups) do
    [
      # real data with data dumper from perl after modifications in UI
      {
        "cn"            => "wheel",
        "gidNumber"     => 497,
        "modified"      => "edited",
        "more_users"    => {},
        "org_cn"        => "wheel",
        "org_gidNumber" => 497,
        "type"          => "system",
        "userPassword"  => "x",
        "userlist"      => {
          "test5" => 1
        },
        "what"          => "user_change"
      }
    ]
  end

  let(:local_groups) do
    [
      {
        "cn"            => "users",
        "gidNumber"     => 100,
        "more_users"    => {},
        "org_cn"        => "users",
        "org_gidNumber" => 100,
        "type"          => "local",
        "userPassword"  => "x",
        "userlist"      => {}
      }
    ]
  end

  let(:login_config) do
    {
      "expire"   => "",
      "group"    => "100",
      "groups"   => "",
      "home"     => "/home",
      "inactive" => "-1",
      "shell"    => "/bin/bash",
      "skel"     => "/etc/skel",
      "umask"    => "022"
    }
  end

  before do
    allow(Yast::Users).to receive(:GetLoginDefaults).and_return(login_config)
    mapped_users = Hash[users.map { |u| [u["uid"], u] }]
    allow(Yast::Users).to receive(:GetUsers).and_return({}, mapped_users)
    mapped_sys_groups = Hash[sys_groups.map { |g| [g["cn"], g] }]
    mapped_local_groups = Hash[local_groups.map { |g| [g["cn"], g] }]
    allow(Yast::Users).to receive(:GetGroups).and_return(mapped_sys_groups, mapped_local_groups)
  end

  describe "#read" do
    it "generates a config with read data" do
      config = subject.read

      expect(config).to be_a(Y2Users::Config)

      expect(config.users.size).to eq 1
      expect(config.groups.size).to eq 2

      test_user = config.users.by_name("test5")
      expect(test_user.uid).to eq "1002"
      expect(test_user.home).to eq "/home/test5"
      expect(test_user.shell).to eq "/bin/bash"
      expect(test_user.primary_group.name).to eq "users"
      expect(test_user.password.value.encrypted?).to eq true
      expect(test_user.password.value.content).to match(/^\$6\$CI/)
      expect(test_user.password.aging.content).to eq("18887")
      expect(test_user.password.account_expiration.content).to eq("")

      test_group = config.groups.by_name("wheel")
      expect(test_group.gid).to eq "497"
      expect(test_group.users.map(&:name)).to eq(["test5"])

      useradd = config.useradd
      expect(useradd.group).to eq "100"
      expect(useradd.expiration).to eq ""
      expect(useradd.inactivity_period).to eq(-1)
      expect(useradd.umask).to eq "022"
    end
  end
end
