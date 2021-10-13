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
        "homeDirectory"     => "/home/test",
        "home_mode"         => "755",
        "loginShell"        => "/bin/bash",
        "modified"          => "edited",
        "no_skeleton"       => false,
        "org_homeDirectory" => "/home/test",
        "org_uid"           => "test",
        "org_uidNumber"     => 1001,
        "org_user"          => {
          "addit_data"       => "",
          "authorized_keys"  => [],
          "chown_home"       => true,
          "cn"               => "test",
          "create_home"      => true,
          "enabled"          => false,
          "encrypted"        => true,
          "gidNumber"        => "100",
          "grouplist"        => {
            "video" => 1,
            "wheel" => 1
          },
          "groupname"        => "users",
          "homeDirectory"    => "/home/test",
          "loginShell"       => "/bin/bash",
          "shadowExpire"     => "",
          "shadowFlag"       => "",
          "shadowInactive"   => "",
          "shadowLastChange" => "18894",
          "shadowMax"        => "99999",
          "shadowMin"        => "0",
          "shadowWarning"    => "7",
          "type"             => "local",
          "uid"              => "test",
          "uidNumber"        => 1001,
          "userPassword"     => "!$6$7CgeIaVsqcVd2OXq$T9ObPbjPCOm7E3U730S8ZLJ82GBBi9XXYJM4iUNadk" \
            "gfpZ3CU/cXe.hdaGhdutqhixtFuZ2hrhEIZvlTcKgSc."
        },
        "plugins"           => [],
        "removed_grouplist" => {
          "wheel" => 1
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
        "uid"               => "test",
        "uidNumber"         => 1001,
        "userPassword"      => "!$6$7CgeIaVsqcVd2OXq$T9ObPbjPCOm7E3U730S8ZLJ82GBBi9XXYJM4iUNadkg" \
          "fpZ3CU/cXe.hdaGhdutqhixtFuZ2hrhEIZvlTcKgSc.",
        "what"              => "edit_user"
      }
    ]
  end

  let(:sys_groups) do
    [
      # real data with data dumper from perl after modifications in UI
      {
        "cn"            => "users",
        "gidNumber"     => 100,
        "more_users"    => {},
        "org_cn"        => "users",
        "org_gidNumber" => 100,
        "type"          => "local",
        "userPassword"  => "x",
        "userlist"      => {}
      },
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
        "cn"            => "testing",
        "gidNumber"     => 1000,
        "modified"      => "added",
        "more_users"    => {},
        "org_cn"        => "testing",
        "org_gidNumber" => 1000,
        "plugins"       => [],
        "type"          => "local",
        "userPassword"  => nil,
        "userlist"      => {
          "test2" => 1
        },
        "what"          => "add_group"
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

  let(:removed_users) do
    {
      "local" => {
        "test6" => {
          "addit_data"       => "",
          "authorized_keys"  => [],
          "cn"               => "test6",
          "delete_home"      => false,
          "gidNumber"        => "100",
          "grouplist"        => {},
          "groupname"        => "users",
          "homeDirectory"    => "/home/test6",
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
          "uid"              => "test6",
          "uidNumber"        => 1001,
          "userPassword"     => "$6$jap/4cvK4.veohli$0JPqLC3sheKRTv79PoiW1fBtbudBad04hWKrUdfOMyzA" \
            "tVoGCUZ1KZivJqq1bIFUlJUJPXIbwFOqxNU1wrpZ8/",
          "what"             => "delete_user"
        },
        "test7" => {
          "addit_data"       => "",
          "authorized_keys"  => [],
          "cn"               => "test7",
          "delete_home"      => true,
          "gidNumber"        => "100",
          "grouplist"        => {},
          "groupname"        => "users",
          "homeDirectory"    => "/home/test7",
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
          "uid"              => "test7",
          "uidNumber"        => 1002,
          "userPassword"     => "!$6$yRZunFQ0DSZghYQ4$7K2cLQ/XrhucUZr4btKmUbfMuUmbDmRX7msfs6VQGKE" \
            "fb2nkrbNn0c2d3mNmG.MGfFgmYyv.540Yaq2GtpVaK1",
          "what"             => "delete_user"
        }
      }
    }
  end

  let(:removed_groups) do
    {
      "local" => {
        "testing" => {
          "cn"           => "testing",
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

  before do
    allow(Yast::Users).to receive(:GetLoginDefaults).and_return(login_config)
    mapped_users = Hash[users.map { |u| [u["uid"], u] }]
    allow(Yast::Users).to receive(:GetUsers).and_return({}, mapped_users)
    mapped_sys_groups = Hash[sys_groups.map { |g| [g["cn"], g] }]
    mapped_local_groups = Hash[local_groups.map { |g| [g["cn"], g] }]
    allow(Yast::Users).to receive(:GetGroups).and_return(mapped_sys_groups, mapped_local_groups)
    allow(Yast::Users).to receive(:RemovedUsers).and_return(removed_users)
    allow(Yast::Users).to receive(:RemovedGroups).and_return(removed_groups)
    allow(Yast::Users).to receive(:GetRootAliases).and_return("test5" => 1)
  end

  describe "#read" do
    it "generates the system and target config" do
      system_config, target_config = subject.read

      expect(target_config).to be_a(Y2Users::Config)

      expect(target_config.users.size).to eq 2
      expect(target_config.groups.size).to eq 3

      test_user = target_config.users.by_name("test5")
      expect(test_user.uid).to eq "1002"
      expect(test_user.home).to be_a(Y2Users::Home)
      expect(test_user.home.path).to eq "/home/test5"
      expect(test_user.home.btrfs_subvol?).to eq true
      expect(test_user.home.permissions).to eq "0755"
      expect(test_user.shell).to eq "/bin/bash"
      expect(test_user.primary_group.name).to eq "users"
      expect(test_user.receive_system_mail?).to eq true
      expect(test_user.password.value.encrypted?).to eq true
      expect(test_user.password.value.content).to match(/^\$6\$CI/)
      expect(test_user.password.aging.content).to eq("18887")
      expect(test_user.password.account_expiration.content).to eq("")

      test_group = target_config.groups.by_name("wheel")
      expect(test_group.gid).to eq "497"
      expect(test_group.users.map(&:name)).to eq(["test5"])

      useradd = target_config.useradd
      expect(useradd.group).to eq "100"
      expect(useradd.expiration).to eq ""
      expect(useradd.inactivity_period).to eq(-1)
      expect(useradd.umask).to eq "022"

      expect(system_config).to be_a(Y2Users::Config)

      expect(system_config.users.size).to eq 3
      expect(system_config.groups.size).to eq 3

      added_user = system_config.users.by_name("test5")
      expect(added_user).to eq nil

      removed_user = system_config.users.by_name("test6")
      expect(removed_user).to be_a(Y2Users::User)

      removed_user = system_config.groups.by_name("testing")
      expect(removed_user).to be_a(Y2Users::Group)
    end
  end
end
