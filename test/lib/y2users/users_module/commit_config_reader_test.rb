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
require "y2users/users_module/commit_config_reader"

describe Y2Users::UsersModule::CommitConfigReader do
  subject { described_class.new }

  describe "#read" do
    let(:users) do
      [
        {
          "uid"           => "test1",
          "chown_home"    => true,
          "create_home"   => true,
          "homeDirectory" => "/home/test",
          "org_user"      => {
            "homeDirectory" => "/home/test1"
          },
          "home_mode"     => "755",
          "modified"      => "edited",
          "no_skeleton"   => true
        },
        {
          "uid"               => "test2",
          "chown_home"        => false,
          "create_home"       => false,
          "homeDirectory"     => "/home/test2",
          "org_homeDirectory" => "/home/test2",
          "home_mode"         => "755",
          "modified"          => "edited",
          "no_skeleton"       => false
        }
      ]
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
            "userPassword"     => "$6$jap/4cvK4.veohli$0JPqLC3sheKRTv79PoiW1fBtbudBad04hWKrUdfOM" \
              "yzVoGCUZ1KZivJqq1bIFUlJUJPXIbwFOqxNU1wrpZ8/",
            "what"             => "delete_user"
          },
          "test2" => {
            "addit_data"       => "",
            "authorized_keys"  => [],
            "cn"               => "test2",
            "delete_home"      => true,
            "gidNumber"        => "100",
            "grouplist"        => {},
            "groupname"        => "users",
            "homeDirectory"    => "/home/test2",
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
            "uid"              => "test2",
            "uidNumber"        => 1002,
            "userPassword"     => "!$6$yRZunFQ0DSZghYQ4$7K2cLQ/XrhucUZr4btKmUbfMuUmbDmRX7msfs6VQ" \
              "GKb2nkrbNn0c2d3mNmG.MGfFgmYyv.540Yaq2GtpVaK1",
            "what"             => "delete_user"
          }
        }
      }
    end

    before do
      mapped_users = Hash[users.map { |u| [u["uid"], u] }]
      allow(Yast::Users).to receive(:GetUsers).and_return(mapped_users, {})
      allow(Yast::Users).to receive(:RemovedUsers).and_return(removed_users)
    end

    it "generates a commit config with the read data" do
      commit_config = subject.read

      expect(commit_config).to be_a(Y2Users::CommitConfig)

      expect(commit_config.target_dir).to be_nil

      user_configs = commit_config.user_configs
      expect(user_configs.size).to eq(3)

      commit_config1 = user_configs.by_username("test1")
      expect(commit_config1.username).to eq("test1")
      expect(commit_config1.home_without_skel?).to eq(true)
      expect(commit_config1.move_home?).to eq(true)
      expect(commit_config1.adapt_home_ownership?).to eq(true)

      commit_config2 = user_configs.by_username("test2")
      expect(commit_config2.username).to eq("test2")
      expect(commit_config2.home_without_skel?).to eq(false)
      expect(commit_config2.move_home?).to eq(false)
      expect(commit_config2.adapt_home_ownership?).to eq(false)
      expect(commit_config2.remove_home?).to eq(true)

      commit_config3 = user_configs.by_username("test6")
      expect(commit_config3.username).to eq("test6")
      expect(commit_config3.remove_home?).to eq(false)
    end

    context "if base_dir is set to a non-default value" do
      before do
        allow(Yast::Users).to receive(:GetBaseDirectory).and_return "/var/yp/yp_etc"
      end

      it "generates a commit config with the corresponding #target_dir" do
        commit_config = subject.read
        expect(commit_config).to be_a(Y2Users::CommitConfig)
        expect(commit_config.target_dir).to eq "/var/yp/yp_etc"
      end

    end
  end
end
