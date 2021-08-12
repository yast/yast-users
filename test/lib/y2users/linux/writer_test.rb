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
require "y2users/useradd_config"
require "y2users/login_config"
require "y2users/linux/writer"

describe Y2Users::Linux::Writer do
  subject(:writer) { described_class.new(config, initial_config) }

  describe "#write" do
    let(:initial_config) do
      config = Y2Users::Config.new
      config.attach(users)
      config.attach(groups)
      config
    end

    let(:config) { initial_config.copy }

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
    let(:keyring) { instance_double(Yast::Users::SSHAuthorizedKeyring, write_keys: true) }

    let(:initial_useradd) { Y2Users::UseraddConfig.new(initial_useradd_attrs) }
    let(:initial_useradd_attrs) do
      { group: "150", home: "/users", umask: "123", skel: "/etc/skeleton" }
    end

    before do
      initial_config.useradd = initial_useradd

      allow(Yast::Execute).to receive(:on_target!)
      allow(Yast::Users::SSHAuthorizedKeyring).to receive(:new).and_return(keyring)
      allow(Yast::Autologin).to receive(:Write)
    end

    RSpec.shared_examples "writing authorized keys" do
      let(:home) { "/home/y2test" }

      before do
        current_user = config.users.by_id(user.id)
        current_user.home = home
      end

      context "when home is defined" do
        it "requests to write authorized keys" do
          expect(keyring).to receive(:write_keys)

          writer.write
        end
      end

      context "when home is not defined" do
        let(:home) { nil }

        it "does not request to write authorized keys" do
          expect(keyring).to_not receive(:write_keys)

          writer.write
        end
      end
    end

    RSpec.shared_examples "using btrfs subvolume" do
      context "when a btrfs subvolume must be used as home" do
        before do
          config.users.by_id(user.id).btrfs_subvolume_home = true
        end

        it "executes useradd with the right --btrfs-subvolume-home argument" do
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

    context "for an existing user" do
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
        before do
          current_user = config.users.by_id(user.id)
          current_user.home = "/home/new"
        end

        it "executes usermod with the new values" do
          expect(Yast::Execute).to receive(:on_target!).with(
            /usermod/, "--home", "/home/new", "--move-home", user.name
          )

          writer.write
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

      context "when modifying a user attribute fails" do
        before do
          allow(Yast).to receive(:y2_logger)

          current_user = config.users.by_id(user.id)
          current_user.home = "/home/new"
          allow(Yast::Execute).to receive(:on_target!)
            .with(/usermod/, any_args)
            .and_raise(Cheetah::ExecutionFailed.new("", "", "", ""))
        end

        it "returns an issue" do
          expect(Yast).to receive(:y2_logger).with(any_args, /Error modifying user '#{user.name}'/)
          issues = writer.write
          expect(issues.first.message).to match("The user '#{user.name}' could not be modified")
        end
      end

      context "whose authorized keys were edited" do
        before do
          current_user = config.users.by_id(user.id)
          current_user.authorized_keys = ["ssh-rsa new-key"]
        end

        include_examples "writing authorized keys"
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

    context "for a new regular user with all the attributes" do
      before do
        user.uid = "1001"
        user.gid = "2001"
        user.shell = "/bin/y2shell"
        user.home = "/home/y2test"
        user.gecos = ["First line of", "GECOS"]

        config.attach(user)
        config.attach(group)
      end

      include_examples "setting password"
      include_examples "setting password attributes"
      include_examples "writing authorized keys"
      include_examples "using btrfs subvolume"

      it "executes useradd with all the parameters, including creation of home directory" do
        expect(Yast::Execute).to receive(:on_target!).with(/useradd/, any_args) do |*args|
          expect(args.last).to eq username
          expect(args).to include(
            "--uid", "--gid", "--shell", "--home-dir", "--create-home", "--groups"
          )
        end

        writer.write
      end
    end

    context "for a new regular user with no optional attributes specified" do
      before do
        config.attach(user)
      end

      include_examples "setting password"
      include_examples "setting password attributes"
      include_examples "using btrfs subvolume"

      it "executes useradd only with the argument to create the home directory" do
        expect(Yast::Execute).to receive(:on_target!).with(/useradd/, "--create-home", username)

        writer.write
      end
    end

    context "for mix of user with specified uid and without uid" do
      before do
        user2 = Y2Users::User.new("testuser2")

        user.uid = "1001"
        user.gid = "2001"
        user.shell = "/bin/y2shell"
        user.home = "/home/y2test"
        user.gecos = ["First line of", "GECOS"]

        config.attach(user2)
        config.attach(user)
        config.attach(group)
      end

      it "executes useradd for user with uid before user without it" do
        expect(Yast::Execute).to receive(:on_target!).ordered.with(/useradd/, any_args) do |*args|
          expect(args.last).to eq username
          expect(args).to include(
            "--uid", "--gid", "--shell", "--home-dir", "--create-home", "--groups", "--non-unique"
          )
        end

        expect(Yast::Execute).to receive(:on_target!).ordered
          .with(/useradd/, "--create-home", "testuser2")

        writer.write
      end
    end

    context "for a new system user" do
      before do
        user.home = "/var/lib/y2test"
        user.system = true

        config.attach(user)
      end

      include_examples "writing authorized keys"

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

    context "when there are no login settings" do
      before do
        config.login = nil
      end

      it "does not write auto-login config" do
        expect(Yast::Autologin).to_not receive(:Write)

        writer.write
      end
    end

    context "when there are login settings" do
      before do
        config.login = Y2Users::LoginConfig.new
        config.login.autologin_user = Y2Users::User.new("test")
        config.login.passwordless = true
      end

      it "configures auto-login according to the settings" do
        writer.write

        expect(Yast::Autologin.user).to eq("test")
        expect(Yast::Autologin.pw_less).to eq(true)
      end

      it "writes auto-login config" do
        expect(Yast::Autologin).to receive(:Write)

        writer.write
      end
    end

    context "when executed with no errors" do
      before do
        config.attach(user)
      end

      it "returns an empty issues list" do
        result = writer.write

        expect(result).to be_a(Y2Issues::List)
        expect(result).to be_empty
      end
    end

    context "when there is any error adding users" do
      let(:exit_double) { instance_double(Process::Status) }
      let(:error) { Cheetah::ExecutionFailed.new("", exit_double, "", "", "initial error") }

      before do
        config.attach(user)
        allow(exit_double).to receive(:exitstatus).and_return exitstatus

        call_count = 0
        allow(Yast::Execute).to receive(:on_target!).with(/useradd/, any_args) do |*args|
          call_count += 1
          raise(error) if call_count == 1

          second_call.call(*args)
        end
      end

      context "and there is no specific handling for the error" do
        let(:exitstatus) { 1 }
        let(:second_call) { ->(*args) {} }

        it "returns an issue notifying the user was not created" do
          result = writer.write

          expect(result).to be_a(Y2Issues::List)
          expect(result).to_not be_empty
          expect(result.map(&:message)).to include(/user.*could not be created/)
        end

        it "does not perform a second attempt to call useradd" do
          expect(second_call).to_not receive(:call)
          writer.write
        end
      end

      context "and the error was a problem creating the home" do
        let(:exitstatus) { 12 }
        let(:second_call) do
          lambda do |*args|
            expect(args.last).to eq user.name
            expect(args).to_not include "--create-home"
            expect(args).to include "--no-create-home"
          end
        end

        it "executes useradd again explicitly avoiding the home creation" do
          expect(second_call).to receive(:call).and_call_original
          writer.write
        end

        context "and the second useradd calls succeeds" do
          it "returns an issue notifying the user was created without home" do
            result = writer.write

            expect(result).to be_a(Y2Issues::List)
            expect(result.to_a.size).to eq 1
            expect(result.first.message).to match(/create home/)
          end
        end

        context "and the second useradd call also fails" do
          let(:second_error) { Cheetah::ExecutionFailed.new("", "", "", "", "second error") }
          let(:second_call) { ->(*_args) { raise(second_error) } }

          it "returns an issue notifying the user was not created" do
            result = writer.write

            expect(result).to be_a(Y2Issues::List)
            expect(result.to_a.size).to eq 1
            expect(result.first.message).to match(/could not be created/)
          end
        end
      end
    end

    context "when there is any error setting passwords" do
      let(:error) { Cheetah::ExecutionFailed.new("", "", "", "", "error") }

      before do
        config.attach(user)

        allow(Yast::Execute).to receive(:on_target!)
          .with(/chpasswd/, any_args)
          .and_raise(error)
      end

      it "returns an issues list containing the issue" do
        result = writer.write

        expect(result).to be_a(Y2Issues::List)
        expect(result).to_not be_empty
        expect(result.map(&:message)).to include(/password.*could not be set/)
      end
    end

    context "when there is any error setting the password attributes" do
      let(:error) { Cheetah::ExecutionFailed.new("", "", "", "", "error") }
      let(:aging) do
        age = Y2Users::PasswordAging.new
        age.force_change
        age
      end

      before do
        user.password.aging = aging
        config.attach(user)

        allow(Yast::Execute).to receive(:on_target!)
          .with(/chage/, any_args)
          .and_raise(error)
      end

      it "returns an issues list containing the issue" do
        result = writer.write

        expect(result).to be_a(Y2Issues::List)
        expect(result).to_not be_empty
        expect(result.map(&:message)).to include(/Error setting the properties of the password/)
      end
    end

    context "when there is any error writing the authorized keys" do
      let(:error) { Yast::Users::SSHAuthorizedKeyring::HomeDoesNotExist.new user.home }

      before do
        user.home = "/home/y2test"
        config.attach(user)

        allow(keyring).to receive(:write_keys).and_raise(error)
      end

      it "returns an issues list containing the issue" do
        result = writer.write

        expect(result).to be_a(Y2Issues::List)
        expect(result).to_not be_empty
        expect(result.map(&:message)).to include(/Error writing authorized keys/)
      end
    end

    context "for a new group" do
      before do
        config.attach(group)
      end

      it "executes groupadd" do
        expect(Yast::Execute).to receive(:on_target!)
          .with(/groupadd/, "--non-unique", "--gid", "100", "users")
        writer.write
      end

      context "when creating the groupadd fails" do
        before do
          allow(Yast).to receive(:y2_logger)

          allow(Yast::Execute).to receive(:on_target!)
            .with(/groupadd/, any_args)
            .and_raise(Cheetah::ExecutionFailed.new("", "", "", ""))
        end

        it "returns an issue" do
          expect(Yast).to receive(:y2_logger).with(any_args, /Error creating group '#{group.name}'/)
          issues = writer.write
          expect(issues.first.message).to match("The group '#{group.name}' could not be created")
        end
      end
    end

    context "when the useradd configuration has not changed" do
      it "does not alter the useradd configuration" do
        expect(Yast::Execute).to_not receive(:on_target!).with(/useradd/, any_args)
        expect(Yast::ShadowConfig).to_not receive(:set)
        expect(Yast::ShadowConfig).to_not receive(:write)

        writer.write
      end
    end

    context "when the umask for useradd has changed" do
      it "writes the change to login.defs" do
        expect(Yast::ShadowConfig).to receive(:set).with(:umask, "321")
        expect(Yast::ShadowConfig).to receive(:write)

        config.useradd.umask = "321"
        writer.write
      end
    end

    context "when some useradd configuration parameters have changed" do
      let(:error) { Cheetah::ExecutionFailed.new("", "", "", "", "error") }

      it "writes all the known parameters to the useradd configuration" do
        expect(Yast::Execute).to receive(:on_target!).with(/useradd/, "-D", "--gid", "users")
        expect(Yast::Execute).to receive(:on_target!).with(/useradd/, "-D", "--expiredate", "")
        expect(Yast::Execute).to receive(:on_target!).with(/useradd/, "-D", "--base-dir", "/users")

        config.useradd.group = "users"
        config.useradd.expiration = ""
        writer.write
      end

      it "reports an issue if writing some parameter fails" do
        allow(Yast::Execute).to receive(:on_target!).with(/useradd/, "-D", "--gid", "users")
          .and_raise(error)

        config.useradd.group = "users"
        result = writer.write
        expect(result.first.message).to match(/went wrong writing.*--gid/)
      end
    end
  end
end
