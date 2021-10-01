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

require "date"
require "y2users/config"
require "y2users/user"
require "y2users/group"
require "y2users/password"
require "y2users/linux/writer"
require "y2users/commit_config"
require "y2users/commit_config_collection"

describe Y2Users::Linux::Writer do
  subject(:writer) { described_class.new(config, initial_config, commit_configs) }

  describe "#write" do
    let(:initial_config) do
      config = Y2Users::Config.new
      config.attach(users)
      config.attach(groups)
      config
    end

    let(:config) { initial_config.copy }

    let(:commit_configs) { Y2Users::CommitConfigCollection.new }

    let(:users) { [] }

    let(:user) do
      user = Y2Users::User.new(username)
      user.password = password
      user
    end

    let(:groups) { [] }

    let(:group) do
      Y2Users::Group.new("users").tap do |group|
        group.gid = "100"
        group.users_name = [user.name]
      end
    end

    let(:password) { Y2Users::Password.new(pwd_value) }

    let(:username) { "testuser" }
    let(:pwd_value) { Y2Users::PasswordEncryptedValue.new("$6$3HkB4uLKri75$Qg6Pp") }

    before do
      allow(File).to receive(:exist?)
      allow(Yast::Execute).to receive(:on_target!)
    end

    RSpec.shared_examples "using btrfs subvolume" do
      context "when a btrfs subvolume must be used as home" do
        before do
          config.users.by_id(user.id).home&.btrfs_subvol = true
        end

        it "executes useradd with with --btrfs-subvolume-home argument" do
          expect(Yast::Execute).to receive(:on_target!).with(/useradd/, any_args) do |*args|
            expect(args.last).to eq user.name
            expect(args).to include("--btrfs-subvolume-home")
          end

          writer.write
        end
      end

      context "when home is not requested to be a btrfs subvolume" do
        it "executes useradd with no --btrfs-subvolume-home argument" do
          expect(Yast::Execute).to receive(:on_target!).with(/useradd/, any_args) do |*args|
            expect(args).to_not include("--btrfs-subvolume-home")
          end

          writer.write
        end
      end
    end

    RSpec.shared_examples "setting password attributes" do
      context "setting some password attributes" do
        before do
          password.aging = aging
          password.account_expiration = towel_day
          password.minimum_age = minimum_age
        end

        let(:towel_day) { Date.new(2001, 5, 25) }
        let(:minimum_age) { 20 }

        context "but not the one about password aging" do
          let(:aging) { nil }

          it "executes 'chage' to set the attributes but excluding 'lastday'" do
            expect(Yast::Execute).to receive(:on_target!).with(/chage/, any_args) do |*args|
              options = Hash[*(args[1..-2])]

              expect(options["--mindays"]).to eq minimum_age.to_s
              expect(options["--expiredate"]).to eq "2001-05-25"
              expect(options.keys).to_not include("--lastday")
            end

            writer.write
          end
        end

        context "including the password last change" do
          let(:aging) { Y2Users::PasswordAging.new(towel_day) }

          it "executes 'chage' to set the attributes including 'lastday'" do
            expect(Yast::Execute).to receive(:on_target!).with(/chage/, any_args) do |*args|
              options = Hash[*(args[1..-2])]

              expect(options["--mindays"]).to eq minimum_age.to_s
              expect(options["--expiredate"]).to eq "2001-05-25"
              expect(options["--lastday"]).to eq "11467"
            end

            writer.write
          end
        end

        context "including the need to change the password" do
          let(:aging) do
            age = Y2Users::PasswordAging.new
            age.force_change
            age
          end

          it "executes 'chage' to set the attributes including 'lastday' (to zero)" do
            expect(Yast::Execute).to receive(:on_target!).with(/chage/, any_args) do |*args|
              options = Hash[*(args[1..-2])]

              expect(options["--mindays"]).to eq minimum_age.to_s
              expect(options["--expiredate"]).to eq "2001-05-25"
              expect(options["--lastday"]).to eq "0"
            end

            writer.write
          end
        end

        context "but disabling password aging" do
          let(:aging) do
            age = Y2Users::PasswordAging.new
            age.disable
            age
          end

          it "executes 'chage' to set the attributes and to reset 'lastday'" do
            expect(Yast::Execute).to receive(:on_target!).with(/chage/, any_args) do |*args|
              options = Hash[*(args[1..-2])]

              expect(options["--mindays"]).to eq minimum_age.to_s
              expect(options["--expiredate"]).to eq "2001-05-25"
              expect(options["--lastday"]).to eq "-1"
            end

            writer.write
          end
        end
      end

      context "with default password attributes" do
        it "does not execute 'chage'" do
          expect(Yast::Execute).to_not receive(:on_target!).with(/chage/)

          writer.write
        end
      end
    end

    RSpec.shared_examples "setting password" do
      context "which has a password set" do
        let(:pwd_value) { Y2Users::PasswordEncryptedValue.new("$6$3HkB4uLKri75$Qg6Pp") }

        # If we would have used the --password argument of useradd, the encrypted password would
        # have been visible in the list of system processes (since it's part of the command)
        it "executes chpasswd without leaking the password to the list of processes" do
          expect(Yast::Execute).to receive(:on_target!).with(/chpasswd/, any_args) do |*args|
            leak_arg = args.find { |arg| arg.include?(pwd_value.content) }
            expect(leak_arg).to be_nil
          end

          writer.write
        end

        context "and the password is not encrypted" do
          let(:pwd_value) { Y2Users::PasswordPlainValue.new("S3cr3T") }

          it "executes chpasswd with a plain password" do
            expect(Yast::Execute).to receive(:on_target!).with(/chpasswd/, any_args) do |*args|
              expect(args).to_not include("-e")
            end

            writer.write
          end
        end

        context "and the new password is encrypted" do
          let(:pwd_value) { Y2Users::PasswordEncryptedValue.new("$6$3HkB4uLKri75$Qg6Pp") }

          it "executes chpasswd with an encrypted password" do
            expect(Yast::Execute).to receive(:on_target!).with(/chpasswd/, any_args) do |*args|
              expect(args).to include("-e")
            end

            writer.write
          end
        end
      end

      context "which does not have a password set" do
        let(:pwd_value) { nil }

        it "does not execute chpasswd" do
          expect(Yast::Execute).to_not receive(:on_target!).with(/chpasswd/, any_args)

          writer.write
        end
      end
    end

    describe "editing an existing user" do
      let(:users) { [user] }

      it "does not execute useradd" do
        expect(Yast::Execute).to_not receive(:on_target!).with(/useradd/, any_args)

        writer.write
      end

      context "whose name has changed" do
        before do
          current_user = config.users.by_id(user.id)
          current_user.name = "test2"
        end

        it "executes usermod with --login option" do
          expect(Yast::Execute).to receive(:on_target!).with(
            /usermod/, "--login", "test2", user.name
          )

          writer.write
        end
      end

      context "whose gid was changed" do
        before do
          current_user = config.users.by_id(user.id)
          current_user.gid = "1000"
        end

        it "executes usermod with the new values" do
          expect(Yast::Execute).to receive(:on_target!).with(
            /usermod/, "--gid", "1000", user.name
          )

          writer.write
        end
      end

      context "whose home was changed" do
        let(:current_user) { config.users.by_id(user.id) }

        before do
          user.gid = group.gid
          current_user.home = Y2Users::Home.new("/home/new")
          commit_configs.add(commit_config)

          allow(File).to receive(:exist?).with(current_user.home.path).and_return(true)
        end

        let(:commit_config) { Y2Users::CommitConfig.new.tap { |c| c.username = user.name } }

        it "executes usermod with the new values" do
          expect(Yast::Execute).to receive(:on_target!).with(
            /usermod/, "--home", "/home/new", user.name
          )

          writer.write
        end

        context "and set for moving content to the new location" do
          before { commit_config.move_home = true }

          it "executes usermod with --move-home argument" do
            expect(Yast::Execute).to receive(:on_target!).with(
              /usermod/, "--home", "/home/new", "--move-home", user.name
            )

            writer.write
          end
        end

        context "and set for taking ownership of new location" do
          before { commit_config.adapt_home_ownership = true }

          it "executes chown over home path" do
            expect(Yast::Execute).to receive(:on_target!).with(
              /chown/, "-R", "testuser:100", current_user.home.path
            )

            writer.write
          end
        end
      end

      context "whose shell was changed" do
        before do
          current_user = config.users.by_id(user.id)
          current_user.shell = "/usr/bin/fish"
        end

        it "executes usermod with the new values" do
          expect(Yast::Execute).to receive(:on_target!).with(
            /usermod/, "--shell", "/usr/bin/fish", user.name
          )

          writer.write
        end
      end

      context "whose gecos was changed" do
        let(:gecos) { ["Jane", "Doe"] }

        before do
          user.gecos = ["Admin"]
          current_user = config.users.by_id(user.id)
          current_user.gecos = gecos
        end

        it "executes usermod with the new values" do
          expect(Yast::Execute).to receive(:on_target!).with(
            /usermod/, "--comment", "Jane,Doe", user.name
          )

          writer.write
        end

        context "and the new value is empty" do
          let(:gecos) { [] }

          it "executes usermod with the new values" do
            expect(Yast::Execute).to receive(:on_target!).with(
              /usermod/, "--comment", "", user.name
            )

            writer.write
          end
        end
      end

      context "whose groups were changed" do
        let(:wheel_group) do
          Y2Users::Group.new("wheel").tap do |group|
            group.users_name = user.name
          end
        end

        let(:other_group) do
          Y2Users::Group.new("other").tap do |group|
            group.users_name = user.name
          end
        end

        let(:users) { [user] }

        before do
          config.attach(wheel_group, other_group)
          allow(Yast::Execute).to receive(:on_target!).with(/groupadd/, any_args)
        end

        it "executes usermod with the new values" do
          expect(Yast::Execute).to receive(:on_target!).with(
            /usermod/, "--groups", "other,wheel", user.name
          )

          writer.write
        end
      end

      context "whose password was edited" do
        before do
          current_user = config.users.by_id(user.id)
          current_user.password = new_password
        end

        context "and the new password is not encrypted" do
          let(:new_password) { Y2Users::Password.create_plain("S3cr3T") }

          it "executes chpasswd with a plain password" do
            expect(Yast::Execute).to receive(:on_target!).with(/chpasswd/, any_args) do |*args|
              expect(args).to_not include("-e")
            end

            writer.write
          end
        end

        context "and the new password is encrypted" do
          let(:new_password) { Y2Users::Password.create_encrypted("$6$3HkB4uLKri7aersa") }

          it "executes chpasswd with an encrypted password" do
            expect(Yast::Execute).to receive(:on_target!).with(/chpasswd/, any_args) do |*args|
              expect(args).to include("-e")
            end

            writer.write
          end
        end
      end

      context "whose password was removed" do
        before do
          current_user = config.users.by_id(user.id)
          current_user.password = nil
        end

        it "executes passwd with --delete option" do
          expect(Yast::Execute).to receive(:on_target!).with(/passwd/, "--delete", user.name)

          writer.write
        end
      end

      context "whose password was not edited" do
        it "does not execute chpasswd" do
          expect(Yast::Execute).to_not receive(:on_target!).with(/chpasswd/, any_args)

          writer.write
        end

        it "does not execute chage" do
          expect(Yast::Execute).to_not receive(:on_target!).with(/chage/, any_args)

          writer.write
        end
      end
    end

    describe "creating a new regular user with all the attributes" do
      before do
        user.uid = "1001"
        user.gid = "2001"
        user.shell = "/bin/y2shell"
        user.gecos = ["First line of", "GECOS"]
        user.home = Y2Users::Home.new("/home/y2test")
        user.home.permissions = "777"

        config.attach(user)
        config.attach(group)
      end

      include_examples "setting password"
      include_examples "setting password attributes"
      include_examples "using btrfs subvolume"

      it "executes useradd with all the parameters, including creation of home directory" do
        expect(Yast::Execute).to receive(:on_target!).with(/useradd/, any_args) do |*args|
          expect(args.last).to eq username
          expect(args).to include(
            "--uid", "--gid", "--shell", "--home-dir", "--create-home", "--groups"
          )
          expect(args.join(" ")).to include "--key HOME_MODE=777"
        end

        writer.write
      end

      describe "reusing an existing home set for ownershiping it" do
        let(:commit_config) do
          Y2Users::CommitConfig.new.tap do |config|
            config.username = user.name
          end
        end

        before do
          allow(File).to receive(:exist?).with(user.home.path).and_return(true)

          commit_config.adapt_home_ownership = adapt_home_ownership
          commit_configs.add(commit_config)
        end

        context "and set for taking ownership" do
          let(:adapt_home_ownership) { true }

          it "executes chown over home path" do
            expect(Yast::Execute).to receive(:on_target!).with(
              /chown/, "-R", "testuser:2001", user.home.path
            )

            writer.write
          end
        end

        context "but not set for taking ownership" do
          let(:adapt_home_ownership) { false }

          it "does not execute chown over home path" do
            expect(Yast::Execute).to_not receive(:on_target!).with(
              /chown/, "-R", "testuser:2001", user.home.path
            )

            writer.write
          end
        end
      end

      describe "skipping copy of skel files" do
        let(:commit_config) do
          Y2Users::CommitConfig.new.tap do |config|
            config.username = user.name
            config.home_without_skel = skip_skel
          end
        end

        before do
          commit_configs.add(commit_config)
        end

        context "when creating a home directory" do
          before do
            # The first call checks that the home can be created and the second that
            # it was already created
            allow(File).to receive(:exist?).with(user.home.path).and_return(false, true)
          end

          context "and the user specified skel files are not wanted" do
            let(:skip_skel) { true }

            it "removes all the home content" do
              expect(Yast::Execute).to receive(:on_target!).with(/find/, any_args) do |*args|
                expect(args).to include(user.home.path)
                expect(args).to include("-delete")
              end

              writer.write
            end
          end

          context "and there is no special setting for skel files" do
            let(:skip_skel) { false }

            it "does not remove home content" do
              expect(Yast::Execute).to_not receive(:on_target!).with(/find/, any_args)

              writer.write
            end
          end
        end

        context "when home already existed" do
          before do
            allow(File).to receive(:exist?).with(user.home.path).and_return(true)
          end

          context "and the user specified skel files are not wanted" do
            let(:skip_skel) { true }

            it "does not try to remove home content" do
              expect(Yast::Execute).to_not receive(:on_target!).with(/find/, any_args)

              writer.write
            end
          end

          context "and there is no special setting for skel files" do
            let(:skip_skel) { false }

            it "does not try to remove home content" do
              expect(Yast::Execute).to_not receive(:on_target!).with(/find/, any_args)

              writer.write
            end
          end
        end

        context "when no home is wanted" do
          before do
            user.home = nil
          end

          let(:skip_skel) { true }

          it "does not try to remove home content" do
            expect(Yast::Execute).to_not receive(:on_target!).with(/find/, any_args)

            writer.write
          end
        end
      end
    end

    describe "creating a new regular user with no optional attributes specified" do
      before do
        config.attach(user)
      end

      let(:username) { "test" }

      include_examples "setting password"
      include_examples "setting password attributes"

      it "creates the default user home" do
        expect(Yast::Execute).to receive(:on_target!).with(/useradd/, any_args) do |*args|
          args = args.join(" ")
          expect(args).to include("--home-dir /home/test")
          expect(args).to include("--create-home")
        end

        writer.write
      end
    end

    describe "creating users both with specified uid and without uid" do
      before do
        user1 = Y2Users::User.new("test1")
        user1.uid = nil

        user2 = Y2Users::User.new("test2")
        user2.uid = "1001"

        config.attach(user1, user2, group)
      end

      it "executes useradd for user with uid before user without it" do
        expect(Yast::Execute).to receive(:on_target!).ordered.with(/useradd/, any_args, "test2")

        expect(Yast::Execute).to receive(:on_target!).ordered.with(/useradd/, any_args, "test1")

        writer.write
      end
    end

    describe "creating a new system user" do
      before do
        user.home = Y2Users::Home.new("/var/lib/y2test")
        user.system = true

        config.attach(user)
      end

      it "executes useradd with the 'system' parameter and without creating a home directory" do
        expect(Yast::Execute).to receive(:on_target!).with(/useradd/, any_args) do |*args|
          expect(args.last).to eq username
          expect(args).to_not include "--create-home"
          expect(args).to_not include "--btrfs-subvolume-home"
          expect(args).to include "--system"
        end

        writer.write
      end
    end

    describe "creating a new group" do
      before { config.attach(group) }

      it "executes groupadd" do
        expect(Yast::Execute).to receive(:on_target!)
          .with(/groupadd/, "--non-unique", "--gid", "100", "users")
        writer.write
      end
    end
  end
end
