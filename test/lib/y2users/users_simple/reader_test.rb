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
require "y2users/users_simple/reader"

describe Y2Users::UsersSimple::Reader do
  describe "#read_to" do
    before { Yast::UsersSimple.SetUsers(users_simple_users) }

    let(:config) { Y2Users::Config.new }

    context "for a set of users directly imported from a previous system by UsersSimple" do
      let(:import_dir) { File.join(FIXTURES_PATH, "root3", "etc") }

      let(:users_simple_users) do
        # This imports regular users ignoring root, the old pre-Y2Users way
        Yast::UsersSimple.ReadUserData(import_dir)
        users = Yast::UsersSimple.GetImportedUsers("local").values
        users.each { |u| u["encrypted"] = true }
        users
      end

      it "fills the given config with the proper data" do
        subject.read_to(config)

        expect(config.users.size).to eq 3
        expect(config.users.map(&:name)).to contain_exactly("root", "b_user", "c_user")

        b_user = config.users.find { |u| u.name == "b_user" }
        expect(b_user.shell).to eq "/bin/bash"
        expect(b_user.uid).to eq "1000"
        expect(b_user.home).to eq "/home/b_user"
        expect(b_user.full_name).to eq "A test local user"
        expect(b_user.password.value.encrypted?).to eq true
        expect(b_user.password.value.content).to match(/^\$1\$.QKD/)
        expect(b_user.password.last_change).to be_a(Date)
        expect(b_user.password.last_change.to_s).to eq "2015-12-16"
        expect(b_user.password.minimum_age).to eq 0
        expect(b_user.password.maximum_age).to be_nil
        expect(b_user.password.warning_period).to eq 0

        c_user = config.users.find { |u| u.name == "c_user" }
        expect(c_user.uid).to eq "1001"
        expect(c_user.gecos).to eq []
        expect(c_user.password.value.encrypted?).to eq true
        expect(c_user.password.last_change).to be_a(Date)
        expect(c_user.password.last_change.to_s).to eq "2021-05-07"
        expect(c_user.password.minimum_age).to eq 0
        expect(c_user.password.maximum_age).to eq 90
        expect(c_user.password.warning_period).to eq 14
        expect(c_user.password.inactivity_period).to be_nil
      end
    end

    context "for a set of users created with minimal information" do
      before do
        Yast::UsersSimple.SetRootPassword(root_pwd)
      end

      let(:root_pwd) { "secretRoot" }

      let(:users_simple_users) do
        [
          { "uid" => "test", "cn" => "Test User", "userPassword" => "secret" }
        ]
      end

      it "fills the given config with the proper data" do
        subject.read_to(config)

        expect(config.users.size).to eq 2
        expect(config.users.map(&:name)).to contain_exactly("root", "test")

        root = config.users.find { |u| u.uid == "0" }
        expect(root.name).to eq "root"
        expect(root.shell).to be_nil
        expect(root.password.value.encrypted?).to eq false
        expect(root.password.value.content).to eq root_pwd

        user = config.users.find { |u| u.name == "test" }
        expect(user.shell).to be_nil
        expect(user.uid).to be_nil
        expect(user.home).to be_nil
        expect(user.full_name).to eq "Test User"
        expect(user.password.value.encrypted?).to eq false
        expect(user.password.value.content).to eq "secret"
        expect(user.password.last_change).to be_nil
        expect(user.password.minimum_age).to eq 0
        expect(user.password.maximum_age).to be_nil
        expect(user.password.warning_period).to eq 0
      end
    end
  end
end
