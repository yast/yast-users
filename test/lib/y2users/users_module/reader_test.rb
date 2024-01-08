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
        "btrfs_subvolume"   => true,
        "chown_home"        => true,
        "cn"                => "test1",
        "create_home"       => true,
        "encrypted"         => true,
        "gidNumber"         => 100,
        "givenName"         => "",
        "grouplist"         => {
          "test2" => 1
        },
        "groupname"         => "users",
        "homeDirectory"     => "/home/test1",
        "home_mode"         => "755",
        "loginShell"        => "/bin/bash",
        "modified"          => "added",
        "no_skeleton"       => true,
        "org_homeDirectory" => "/home/test1",
        "org_uid"           => "test1",
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
        "uid"               => "test1",
        "uidNumber"         => 1002,
        "userPassword"      => "$6$CIrJOmyF8WBnHsAn$Sh.pjryO9CD.Dfm9KzDdVYYXblxiTw05b9b0GVpMbckbU" \
                               "gK/fFvn7nM.ipqooa3Ks5fGgzV.6gPBGG1l8hs7L.",
        "what"              => "group_change"
      },
      {
        "addit_data"        => "",
        "authorized_keys"   => [],
        "btrfs_subvolume"   => 0,
        "chown_home"        => true,
        "cn"                => "testing guy",
        "create_home"       => true,
        "enabled"           => false,
        "encrypted"         => true,
        "gidNumber"         => 100,
        "givenName"         => "",
        "grouplist"         => {
          "video" => 1
        },
        "groupname"         => "users",
        "homeDirectory"     => "/home/test2",
        "home_mode"         => "755",
        "loginShell"        => "/bin/bash",
        "modified"          => "edited",
        "no_skeleton"       => false,
        "org_homeDirectory" => "/home/test2",
        "org_uid"           => "test2",
        "org_uidNumber"     => 1001,
        "org_user"          => {
          "addit_data"       => "",
          "authorized_keys"  => [],
          "chown_home"       => true,
          "cn"               => "test2",
          "create_home"      => true,
          "enabled"          => false,
          "encrypted"        => true,
          "gidNumber"        => "100",
          "grouplist"        => {
            "video" => 1,
            "test2" => 1
          },
          "groupname"        => "users",
          "homeDirectory"    => "/home/test2",
          "loginShell"       => "/bin/bash",
          "shadowExpire"     => "",
          "shadowFlag"       => "",
          "shadowInactive"   => "",
          "shadowLastChange" => "18894",
          "shadowMax"        => "99999",
          "shadowMin"        => "0",
          "shadowWarning"    => "7",
          "type"             => "local",
          "uid"              => "test2",
          "uidNumber"        => 1001,
          "userPassword"     => "!$6$7CgeIaVsqcVd2OXq$T9ObPbjPCOm7E3U730S8ZLJ82GBBi9XXYJM4iUNadk" \
                                "gfpZ3CU/cXe.hdaGhdutqhixtFuZ2hrhEIZvlTcKgSc."
        },
        "plugins"           => [],
        "removed_grouplist" => {
          "test2" => 1
        },
        "shadowExpire"      => "",
        "shadowFlag"        => "",
        "shadowInactive"    => "",
        "shadowLastChange"  => "18894",
        "shadowMax"         => "99999",
        "shadowMin"         => "0",
        "shadowWarning"     => "7",
        "sn"                => "",
        "type"              => "local",
        "uid"               => "test2",
        "uidNumber"         => 1001,
        "userPassword"      => "!$6$7CgeIaVsqcVd2OXq$T9ObPbjPCOm7E3U730S8ZLJ82GBBi9XXYJM4iUNadkg" \
                               "fpZ3CU/cXe.hdaGhdutqhixtFuZ2hrhEIZvlTcKgSc.",
        "what"              => "edit_user"
      }
    ]
  end

  let(:removed_users) do
    {
      "local" => {
        "test3" => {
          "addit_data"       => "",
          "authorized_keys"  => [],
          "cn"               => "test3",
          "delete_home"      => false,
          "gidNumber"        => "100",
          "grouplist"        => {},
          "groupname"        => "users",
          "homeDirectory"    => "/home/test3",
          "loginShell"       => "/bin/bash",
          "modified"         => "deleted",
          "plugins"          => [],
          "shadowExpire"     => "",
          "shadowFlag"       => "",
          "shadowInactive"   => "",
          "shadowLastChange" => "18899",
          "shadowMax"        => "99999",
          "shadowMin"        => "0",
          "shadowWarning"    => "7",
          "type"             => "local",
          "uid"              => "test3",
          "uidNumber"        => 1001,
          "userPassword"     => "$6$jap/4cvK4.veohli$0JPqLC3sheKRTv79PoiW1fBtbudBad04hWKrUdfOMyzA" \
                                "tVoGCUZ1KZivJqq1bIFUlJUJPXIbwFOqxNU1wrpZ8/",
          "what"             => "delete_user"
        },
        "test4" => {
          "addit_data"       => "",
          "authorized_keys"  => [],
          "cn"               => "test4",
          "delete_home"      => true,
          "gidNumber"        => "100",
          "grouplist"        => {},
          "groupname"        => "users",
          "homeDirectory"    => "/home/test4",
          "loginShell"       => "/bin/bash",
          "modified"         => "deleted",
          "org_user"         => {},
          "plugins"          => [],
          "shadowExpire"     => "",
          "shadowFlag"       => "",
          "shadowInactive"   => "",
          "shadowLastChange" => "18899",
          "shadowMax"        => "99999",
          "shadowMin"        => "0",
          "shadowWarning"    => "7",
          "type"             => "local",
          "uid"              => "test4",
          "uidNumber"        => 1002,
          "userPassword"     => "!$6$yRZunFQ0DSZghYQ4$7K2cLQ/XrhucUZr4btKmUbfMuUmbDmRX7msfs6VQGKE" \
                                "fb2nkrbNn0c2d3mNmG.MGfFgmYyv.540Yaq2GtpVaK1",
          "what"             => "delete_user"
        }
      }
    }
  end

  let(:sys_groups) do
    [
      # real data with data dumper from perl after modifications in UI
      {
        "cn"            => "test1",
        "gidNumber"     => "100",
        "more_users"    => {},
        "org_cn"        => "test1",
        "org_gidNumber" => 100,
        "type"          => "local",
        "userlist"      => {}
      },
      # test2 is a new group (only in target)
      {
        "cn"            => "test2",
        "gidNumber"     => 497,
        "modified"      => "added",
        "more_users"    => {},
        "org_cn"        => "test2",
        "org_gidNumber" => 497,
        "type"          => "system",
        "userlist"      => {
          "test1" => 1
        },
        "what"          => "user_change"
      },
      {
        "cn"         => "test3",
        "gidNumber"  => "",
        "more_users" => {},
        "type"       => "system",
        "userlist"   => {}
      }
    ]
  end

  let(:local_groups) do
    [
      {
        "cn"            => "test4",
        "gidNumber"     => 1000,
        "more_users"    => {},
        "org_cn"        => "test4",
        "org_gidNumber" => 1000,
        "plugins"       => [],
        "type"          => "local",
        "userlist"      => {
          "test2" => 1
        }
      }
    ]
  end

  let(:removed_groups) do
    {
      "local" => {
        "test5" => {
          "cn"           => "test5",
          "gidNumber"    => 1000,
          "modified"     => "deleted",
          "more_users"   => {},
          "type"         => "local",
          "userPassword" => "x",
          "userlist"     => {},
          "what"         => "delete_group"
        }
      }
    }
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
    mapped_users = users.map { |u| [u["uid"], u] }.to_h
    allow(Yast::Users).to receive(:GetUsers).and_return({}, mapped_users)
    mapped_sys_groups = sys_groups.map { |g| [g["cn"], g] }.to_h
    mapped_local_groups = local_groups.map { |g| [g["cn"], g] }.to_h
    allow(Yast::Users).to receive(:GetGroups).and_return(mapped_sys_groups, mapped_local_groups)
    allow(Yast::Users).to receive(:RemovedUsers).and_return(removed_users)
    allow(Yast::Users).to receive(:RemovedGroups).and_return(removed_groups)
    allow(Yast::Users).to receive(:GetRootAliases).and_return("test1" => 1)
  end

  # Scenario:
  #
  # New users: test1
  # Existing users: test2
  # Removed users. test3, test4
  #
  # New Groups: test2
  # Existing groups: test1, test3, test4
  # Removed groups: test5
  describe "#read" do
    it "generates the system and target config" do
      system_config, target_config = subject.read

      # System config check

      expect(system_config).to be_a(Y2Users::Config)
      expect(system_config.users.map(&:name)).to contain_exactly("test2", "test3", "test4")
      expect(system_config.groups.map(&:name))
        .to contain_exactly("test1", "test3", "test4", "test5")

      # Target config check

      expect(target_config).to be_a(Y2Users::Config)
      expect(target_config.users.map(&:name)).to contain_exactly("test1", "test2")

      test_user = target_config.users.by_name("test1")
      expect(test_user.uid).to eq "1002"
      expect(test_user.home).to be_a(Y2Users::Home)
      expect(test_user.home.path).to eq "/home/test1"
      expect(test_user.home.btrfs_subvol?).to eq true
      expect(test_user.home.permissions).to eq "0755"
      expect(test_user.shell).to eq "/bin/bash"
      expect(test_user.primary_group.name).to eq "test1"
      expect(test_user.receive_system_mail?).to eq true
      expect(test_user.password.value.encrypted?).to eq true
      expect(test_user.password.value.content).to match(/^\$6\$CI/)
      expect(test_user.password.aging.content).to eq("18887")
      expect(test_user.password.account_expiration.content).to eq("")

      expect(target_config.groups.map(&:name))
        .to contain_exactly("test1", "test2", "test3", "test4")

      test_group = target_config.groups.by_name("test2")
      expect(test_group.gid).to eq "497"
      expect(test_group.users.map(&:name)).to eq(["test1"])
      expect(test_group.system?).to eq(true)

      test_group = target_config.groups.by_name("test4")
      expect(test_group.system?).to eq(false)

      # useradd config check

      useradd = target_config.useradd
      expect(useradd.group).to eq "100"
      expect(useradd.expiration).to eq ""
      expect(useradd.inactivity_period).to eq(-1)
      expect(useradd.umask).to eq "022"
    end
  end
end
