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
require "yast"

Yast.import "UsersSimple"

describe Y2Users::UsersSimple::Reader do
  describe "#read" do
    before { Yast::UsersSimple.SetUsers(users_simple_users) }

    context "for a set of users directly imported from a previous system by UsersSimple" do
      let(:import_dir) { File.join(FIXTURES_PATH, "root3", "etc") }

      let(:users_simple_users) do
        # This imports regular users ignoring root, the old pre-Y2Users way
        Yast::UsersSimple.ReadUserData(import_dir)
        users = Yast::UsersSimple.GetImportedUsers("local").values
        users.each { |u| u["encrypted"] = true }
        users
      end

      it "generates a config with the proper data" do
        config = subject.read

        expect(config).to be_a(Y2Users::Config)

        expect(config.users.size).to eq 3
        expect(config.users.map(&:name)).to contain_exactly("root", "b_user", "c_user")

        b_user = config.users.by_name("b_user")
        expect(b_user.shell).to eq "/bin/bash"
        expect(b_user.uid).to eq "1000"
        expect(b_user.home).to eq "/home/b_user"
        expect(b_user.full_name).to eq "A test local user"
        expect(b_user.password.value.encrypted?).to eq true
        expect(b_user.password.value.content).to match(/^\$1\$.QKD/)
        expect(b_user.password.aging.last_change).to be_a(Date)
        expect(b_user.password.aging.last_change.to_s).to eq "2015-12-16"
        expect(b_user.password.minimum_age).to eq ""
        expect(b_user.password.maximum_age).to eq ""
        expect(b_user.password.warning_period).to eq ""
        expect(b_user.password.inactivity_period).to eq ""
        expect(b_user.password.account_expiration.content).to eq ""

        c_user = config.users.by_name("c_user")
        expect(c_user.uid).to eq "1001"
        expect(c_user.gecos).to eq []
        expect(c_user.password.value.encrypted?).to eq true
        expect(c_user.password.aging.last_change).to be_a(Date)
        expect(c_user.password.aging.last_change.to_s).to eq "2021-05-07"
        expect(c_user.password.minimum_age).to eq "0"
        expect(c_user.password.maximum_age).to eq "90"
        expect(c_user.password.warning_period).to eq "14"
        expect(c_user.password.inactivity_period).to eq ""
        expect(c_user.password.account_expiration.content).to eq ""
      end
    end

    context "for a set of users created with minimal information" do
      before do
        Yast::UsersSimple.SetRootPassword(root_pwd)
        Yast::UsersSimple.SetRootPublicKey(root_authorized_key)
      end

      let(:root_pwd) { "secretRoot" }
      let(:root_authorized_key) { "ssh-rsa root-authorized-key" }

      let(:users_simple_users) do
        [{ "uid" => "test", "cn" => "Test User", "userPassword" => "secret" }]
      end

      it "generates a config with the proper data" do
        config = subject.read

        expect(config).to be_a(Y2Users::Config)

        expect(config.users.size).to eq 2
        expect(config.users.map(&:name)).to contain_exactly("root", "test")

        root = config.users.root
        expect(root.uid).to eq "0"
        expect(root.name).to eq "root"
        expect(root.shell).to be_nil
        expect(root.home).to eq "/root"
        expect(root.authorized_keys).to eq [root_authorized_key]
        expect(root.password.value.encrypted?).to eq false
        expect(root.password.value.content).to eq root_pwd

        user = config.users.by_name("test")
        expect(user.shell).to be_nil
        expect(user.uid).to be_nil
        expect(user.home).to be_nil
        expect(user.full_name).to eq "Test User"
        expect(user.password.value.encrypted?).to eq false
        expect(user.password.value.content).to eq "secret"
        expect(user.password.aging).to be_nil
        expect(user.password.minimum_age).to be_nil
        expect(user.password.maximum_age).to be_nil
        expect(user.password.warning_period).to be_nil
        expect(user.password.account_expiration).to be_nil
      end
    end

    context "for a specific user" do
      let(:users_simple_users) { [user] }

      context "which has no info about the last password change" do
        let(:user) { { "uid" => "test", "shadowLastChange" => nil } }

        it "sets a password to the user without aging info" do
          user = subject.read.users.by_name("test")

          expect(user.password.aging).to be_nil
        end
      end

      context "which has an empty value for the last password change" do
        let(:user) { { "uid" => "test", "shadowLastChange" => "" } }

        it "sets a password to the user with an empty aging value" do
          user = subject.read.users.by_name("test")

          expect(user.password.aging).to be_a(Y2Users::PasswordAging)
          expect(user.password.aging.content).to eq("")
        end
      end

      context "which has a value for the last password change" do
        let(:user) { { "uid" => "test", "shadowLastChange" => "12345" } }

        it "sets a password to the user with the given aging value" do
          user = subject.read.users.by_name("test")

          expect(user.password.aging).to be_a(Y2Users::PasswordAging)
          expect(user.password.aging.content).to eq("12345")
        end
      end

      context "which has no info about the minimum password age" do
        let(:user) { { "uid" => "test", "shadowMin" => nil } }

        it "sets a password to the user without minimum age info" do
          user = subject.read.users.by_name("test")

          expect(user.password.minimum_age).to be_nil
        end
      end

      context "which has an empty value for the minimum password age" do
        let(:user) { { "uid" => "test", "shadowMin" => "" } }

        it "sets a password to the user with an empty minimun age" do
          user = subject.read.users.by_name("test")

          expect(user.password.minimum_age).to eq("")
        end
      end

      context "which has a value for the minimum password age" do
        let(:user) { { "uid" => "test", "shadowMin" => "9999" } }

        it "sets a password to the user with the given minimum age" do
          user = subject.read.users.by_name("test")

          expect(user.password.minimum_age).to eq("9999")
        end
      end

      context "which has no info about the maximum password age" do
        let(:user) { { "uid" => "test", "shadowMax" => nil } }

        it "sets a password to the user without maximum age info" do
          user = subject.read.users.by_name("test")

          expect(user.password.maximum_age).to be_nil
        end
      end

      context "which has an empty value for the maximum password age" do
        let(:user) { { "uid" => "test", "shadowMax" => "" } }

        it "sets a password to the user with an empty maximum age" do
          user = subject.read.users.by_name("test")

          expect(user.password.maximum_age).to eq("")
        end
      end

      context "which has a value for the maximum password age" do
        let(:user) { { "uid" => "test", "shadowMax" => "9999" } }

        it "sets a password to the user with the given maximum age" do
          user = subject.read.users.by_name("test")

          expect(user.password.maximum_age).to eq("9999")
        end
      end

      context "which has no info about the password warning period" do
        let(:user) { { "uid" => "test", "shadowWarning" => nil } }

        it "sets a password to the user without warning period info" do
          user = subject.read.users.by_name("test")

          expect(user.password.warning_period).to be_nil
        end
      end

      context "which has an empty value for the password warning period" do
        let(:user) { { "uid" => "test", "shadowWarning" => "" } }

        it "sets a password to the user with an empty warning period" do
          user = subject.read.users.by_name("test")

          expect(user.password.warning_period).to eq("")
        end
      end

      context "which has a value for the password warning period" do
        let(:user) { { "uid" => "test", "shadowWarning" => "9999" } }

        it "sets a password to the user with the given warning period" do
          user = subject.read.users.by_name("test")

          expect(user.password.warning_period).to eq("9999")
        end
      end

      context "which has no info about the password inactivity period" do
        let(:user) { { "uid" => "test", "shadowInactive" => nil } }

        it "sets a password to the user without inactivity period info" do
          user = subject.read.users.by_name("test")

          expect(user.password.inactivity_period).to be_nil
        end
      end

      context "which has an empty value for the password inactivity period" do
        let(:user) { { "uid" => "test", "shadowInactive" => "" } }

        it "sets a password to the user with an empty inactivity period" do
          user = subject.read.users.by_name("test")

          expect(user.password.inactivity_period).to eq("")
        end
      end

      context "which has a value for the password inactivity period" do
        let(:user) { { "uid" => "test", "shadowInactive" => "9999" } }

        it "sets a password to the user with the given inactivity period" do
          user = subject.read.users.by_name("test")

          expect(user.password.inactivity_period).to eq("9999")
        end
      end

      context "which has no info about the account expiration" do
        let(:user) { { "uid" => "test", "shadowExpire" => nil } }

        it "sets a password to the user without account expiration info" do
          user = subject.read.users.by_name("test")

          expect(user.password.account_expiration).to be_nil
        end
      end

      context "which has an empty value for the last password change" do
        let(:user) { { "uid" => "test", "shadowExpire" => "" } }

        it "sets a password to the user with an empty account expiration value" do
          user = subject.read.users.by_name("test")

          expect(user.password.account_expiration).to be_a(Y2Users::AccountExpiration)
          expect(user.password.account_expiration.content).to eq("")
        end
      end

      context "which has a value for the last password change" do
        let(:user) { { "uid" => "test", "shadowExpire" => "12345" } }

        it "sets a password to the user with the given account expiration value" do
          user = subject.read.users.by_name("test")

          expect(user.password.account_expiration).to be_a(Y2Users::AccountExpiration)
          expect(user.password.account_expiration.content).to eq("12345")
        end
      end

      context "without the root password" do
        let(:root_pwd) { "" }

        it "leaves it unset" do
          config = subject.read
          root = config.users.root

          expect(root.password).to be_nil
        end
      end

      context "without the root authorized key" do
        let(:root_authorized_key) { "" }

        it "leaves it unset" do
          config = subject.read
          root = config.users.root

          expect(root.authorized_keys).to eq([])
        end
      end
    end
  end
end
