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
require "y2users/autoinst/reader"

# defines exported users
require_relative "../../../fixtures/users_export"

describe Y2Users::Autoinst::Reader do
  subject { described_class.new(profile) }

  let(:profile) { USERS_EXPORT }

  describe "#read" do
    it "fills given config with data from hash" do
      result = subject.read

      config = result.config
      expect(config.users.size).to eq 29
      expect(config.groups.size).to eq 43

      root_user = config.users.root
      expect(root_user.shell).to eq "/bin/bash"
      expect(root_user.primary_group.name).to eq "root"
      expect(root_user.password.value.encrypted?).to eq true
      expect(root_user.password.value.content).to match(/^\$6\$AS/)
      expect(root_user.password.aging).to be_nil
      expect(root_user.password.account_expiration.expire?).to eq(false)
      expect(root_user.authorized_keys).to contain_exactly("ssh-rsa AAAAB3Nza")

      expect(config.login?).to eq(false)

      expect(config.useradd.expiration).to eq nil
      expect(config.useradd.inactivity_period).to eq(-1)
      expect(config.useradd.group).to eq "100"
      expect(config.useradd.umask).to eq "022"
    end

    context "for a specific user" do
      let(:profile) do
        {
          "users" => [
            {
              "username"          => "test",
              "user_password"     => "S3cr3T",
              "password_settings" => password_settings
            }
          ]
        }
      end

      context "which has no info about the last password change" do
        let(:password_settings) { {} }

        it "sets a password to the user without aging info" do
          config = subject.read.config
          user = config.users.by_name("test")

          expect(user.password.aging).to be_nil
        end
      end

      context "which has an empty value for the last password change" do
        let(:password_settings) { { "last_change" => "" } }

        it "sets a password to the user with an empty aging value" do
          config = subject.read.config
          user = config.users.by_name("test")

          expect(user.password.aging).to be_a(Y2Users::PasswordAging)
          expect(user.password.aging.content).to eq("")
        end
      end

      context "which has a value for the last password change" do
        let(:password_settings) { { "last_change" => "2010-12-31" } }

        let(:shadow_date) { Y2Users::ShadowDate.new(Date.new(2010, 12, 31)) }

        it "sets a password to the user with the given aging value" do
          config = subject.read.config
          user = config.users.by_name("test")

          expect(user.password.aging).to be_a(Y2Users::PasswordAging)
          expect(user.password.aging.content).to eq(shadow_date.to_s)
        end
      end

      context "which has no info about the minimum password age" do
        let(:password_settings) { {} }

        it "sets a password to the user without minimum age info" do
          config = subject.read.config
          user = config.users.by_name("test")

          expect(user.password.minimum_age).to be_nil
        end
      end

      context "which has an empty value for the minimum password age" do
        let(:password_settings) { { "min" => "" } }

        it "sets a password to the user with an empty minimun age" do
          config = subject.read.config
          user = config.users.by_name("test")

          expect(user.password.minimum_age).to eq("")
        end
      end

      context "which has a value for the minimum password age" do
        let(:password_settings) { { "min" => "9999" } }

        it "sets a password to the user with the given minimum age" do
          config = subject.read.config
          user = config.users.by_name("test")

          expect(user.password.minimum_age).to eq("9999")
        end
      end

      context "which has no info about the maximum password age" do
        let(:password_settings) { {} }

        it "sets a password to the user without maximum age info" do
          config = subject.read.config
          user = config.users.by_name("test")

          expect(user.password.maximum_age).to be_nil
        end
      end

      context "which has an empty value for the maximum password age" do
        let(:password_settings) { { "max" => "" } }

        it "sets a password to the user with an empty maximum age" do
          config = subject.read.config
          user = config.users.by_name("test")

          expect(user.password.maximum_age).to eq("")
        end
      end

      context "which has a value for the maximum password age" do
        let(:password_settings) { { "max" => "9999" } }

        it "sets a password to the user with the given maximum age" do
          config = subject.read.config
          user = config.users.by_name("test")

          expect(user.password.maximum_age).to eq("9999")
        end
      end

      context "which has no info about the password warning period" do
        let(:password_settings) { {} }

        it "sets a password to the user without warning period info" do
          config = subject.read.config
          user = config.users.by_name("test")

          expect(user.password.warning_period).to be_nil
        end
      end

      context "which has an empty value for the password warning period" do
        let(:password_settings) { { "warn" => "" } }

        it "sets a password to the user with an empty warning period" do
          config = subject.read.config
          user = config.users.by_name("test")

          expect(user.password.warning_period).to eq("")
        end
      end

      context "which has a value for the password warning period" do
        let(:password_settings) { { "warn" => "9999" } }

        it "sets a password to the user with the given warning period" do
          config = subject.read.config
          user = config.users.by_name("test")

          expect(user.password.warning_period).to eq("9999")
        end
      end

      context "which has no info about the password inactivity period" do
        let(:password_settings) { {} }

        it "sets a password to the user without inactivity period info" do
          config = subject.read.config
          user = config.users.by_name("test")

          expect(user.password.inactivity_period).to be_nil
        end
      end

      context "which has an empty value for the password inactivity period" do
        let(:password_settings) { { "inact" => "" } }

        it "sets a password to the user with an empty inactivity period" do
          config = subject.read.config
          user = config.users.by_name("test")

          expect(user.password.inactivity_period).to eq("")
        end
      end

      context "which has a value for the password inactivity period" do
        let(:password_settings) { { "inact" => "9999" } }

        it "sets a password to the user with the given inactivity period" do
          config = subject.read.config
          user = config.users.by_name("test")

          expect(user.password.inactivity_period).to eq("9999")
        end
      end

      context "which has no info about the account expiration" do
        let(:password_settings) { {} }

        it "sets a password to the user without account expiration info" do
          config = subject.read.config
          user = config.users.by_name("test")

          expect(user.password.account_expiration).to be_nil
        end
      end

      context "which has an empty value for the account expiration" do
        let(:password_settings) { { "expire" => "" } }

        it "sets a password to the user with an empty account expiration value" do
          config = subject.read.config
          user = config.users.by_name("test")

          expect(user.password.account_expiration).to be_a(Y2Users::AccountExpiration)
          expect(user.password.account_expiration.content).to eq("")
        end
      end

      context "which has a value for the account expiration" do
        let(:password_settings) { { "expire" => "2010-12-31" } }

        let(:shadow_date) { Y2Users::ShadowDate.new(Date.new(2010, 12, 31)) }

        it "sets a password to the user with the given account expiration value" do
          config = subject.read.config
          user = config.users.by_name("test")

          expect(user.password.account_expiration).to be_a(Y2Users::AccountExpiration)
          expect(user.password.account_expiration.content).to eq(shadow_date.to_s)
        end
      end

      context "if home_btrfs_subvolume is not part of the user description" do
        let(:profile) do
          { "users" => [{ "username" => "test" }] }
        end

        it "sets User#btrfs_subvolume_home to nil" do
          user = subject.read.config.users.by_name("test")

          expect(user.btrfs_subvolume_home).to be_nil
        end
      end

      context "if home_btrfs_subvolume is part of the user description" do
        let(:profile) do
          { "users" => [{ "username" => "test", "home_btrfs_subvolume" => subvol }] }
        end

        context "and set to true" do
          let(:subvol) { true }

          it "sets User#btrfs_subvolume_home to true" do
            user = subject.read.config.users.by_name("test")

            expect(user.btrfs_subvolume_home).to eq true
          end
        end

        context "and set to false" do
          let(:subvol) { false }

          it "sets User#btrfs_subvolume_home to false" do
            user = subject.read.config.users.by_name("test")

            expect(user.btrfs_subvolume_home).to eq false
          end
        end
      end
    end

    context "when the users list is missing" do
      let(:profile) do
        { "groups" => [{ "groupname" => "users" }] }
      end

      it "sets the user list as an empty array" do
        config = subject.read.config

        users_group = config.groups.first
        expect(users_group.name).to eq("users")
        expect(users_group.users_name).to eq([])
      end
    end

    context "when a user has no username" do
      let(:profile) do
        {
          "users" => [
            { "username" => "root", "user_password" => "secret" },
            { "user_password" => "secret" }
          ]
        }
      end

      it "registers an issue" do
        result = subject.read
        issue = result.issues.first
        expect(issue).to be_a(Y2Issues::InvalidValue)
        expect(issue.location.to_s).to eq("autoyast:users,1:username")
      end
    end

    context "when a user has an empty username" do
      let(:profile) do
        {
          "users" => [
            { "username" => "", "user_password" => "secret" },
            { "username" => "root", "user_password" => "secret" }
          ]
        }
      end

      it "registers an issue" do
        result = subject.read
        issue = result.issues.first
        expect(issue).to be_a(Y2Issues::InvalidValue)
        expect(issue.location.to_s).to eq("autoyast:users,0:username")
      end
    end

    context "when there is a login_settings section" do
      let(:profile) do
        {
          "users"          => [users],
          "login_settings" => { "autologin_user" => "test", "password_less_login" => true }
        }
      end

      let(:users) { { "username" => "test" } }

      it "sets the login config according to the profile section" do
        config = subject.read.config

        expect(config.login?).to eq(true)
        expect(config.login.autologin_user.name).to eq("test")
        expect(config.login.passwordless?).to eq(true)
      end

      context "and the autologin user does not belong to the config" do
        let(:users) { { "username" => "other" } }

        it "does not set the autologin user" do
          config = subject.read.config

          expect(config.login?).to eq(true)
          expect(config.login.autologin?).to eq(false)
          expect(config.login.passwordless?).to eq(true)
        end
      end
    end

    context "when the login_settings section is missing" do
      let(:profile) do
        {
          "users" => [{ "username" => "test" }]
        }
      end

      it "does not set the login config" do
        config = subject.read.config

        expect(config.login?).to eq(false)
      end
    end

    context "when the profile is empty" do
      let(:profile) { {} }

      it "sets the users and groups lists as empty" do
        result = subject.read
        config = result.config

        expect(config.users).to be_empty
        expect(config.groups).to be_empty
      end

      it "does not set the login config" do
        result = subject.read
        config = result.config

        expect(config.login?).to eq(false)
      end

      it "creates an empty useradd configuration" do
        config = subject.read.config

        expect(config.useradd.group).to be_nil
        expect(config.useradd.home).to be_nil
        expect(config.useradd.umask).to be_nil
        expect(config.useradd.expiration).to be_nil
        expect(config.useradd.inactivity_period).to be_nil
        expect(config.useradd.umask).to be_nil
      end
    end

    context "when the password is not encrypted" do
      let(:user_profile) do
        { "username" => "root", "user_password" => "secret" }
      end

      let(:profile) do
        { "users" => [user_profile] }
      end

      it "sets the passsword as unencrypted" do
        result = subject.read
        config = result.config

        user = config.users.first
        password = user.password
        expect(password.value).to_not be_encrypted
      end
    end

    context "when the password is not given" do
      let(:user_profile) do
        { "username" => "root" }
      end

      let(:profile) do
        { "users" => [user_profile] }
      end

      it "sets a nil password" do
        result = subject.read
        config = result.config

        user = config.users.first
        expect(user.password).to be_nil
      end
    end

    context "when a group has no groupname" do
      let(:profile) do
        {
          "groups" => [
            { "groupname" => "root" },
            { "gid" => "100" }
          ]
        }
      end

      it "registers an issue" do
        result = subject.read
        issue = result.issues.first
        expect(issue).to be_a(Y2Issues::InvalidValue)
        expect(issue.location.to_s).to eq("autoyast:groups,1:groupname")
      end
    end

    context "when a group has an empty groupname" do
      let(:profile) do
        {
          "groups" => [
            { "groupname" => "" },
            { "groupname" => "root", "gid" => "100" }
          ]
        }
      end

      it "registers an issue" do
        result = subject.read
        issue = result.issues.first
        expect(issue).to be_a(Y2Issues::InvalidValue)
        expect(issue.location.to_s).to eq("autoyast:groups,0:groupname")
      end
    end
  end
end
