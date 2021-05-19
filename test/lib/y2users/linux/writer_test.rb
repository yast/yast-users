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
require "y2users/password"
require "y2users/linux/writer"

describe Y2Users::Linux::Writer do
  subject(:writer) { described_class.new(config, initial_config) }

  describe "#write" do
    let(:initial_config) do
      config = Y2Users::Config.new
      config.attach(users)
      config
    end

    let(:config) { initial_config.copy }

    let(:users) { [] }

    let(:user) do
      user = Y2Users::User.new(username)
      user.password = password
      user
    end

    let(:password) { Y2Users::Password.new(pwd_value) }

    let(:username) { "testuser" }
    let(:pwd_value) { Y2Users::PasswordEncryptedValue.new("$6$3HkB4uLKri75$Qg6Pp") }
    let(:keyring) { instance_double(Yast::Users::SSHAuthorizedKeyring, write_keys: true) }

    before do
      allow(Yast::Execute).to receive(:on_target!)
      allow(Yast::Users::SSHAuthorizedKeyring).to receive(:new).and_return(keyring)
    end

    RSpec.shared_examples "writing authorized keys" do
      let(:home) { "/home/y2test" }

      before do
        current_user = config.users.find { |u| u.id == user.id }
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
        it "executes 'chage' to clean-up all fields except 'lastday'" do
          expect(Yast::Execute).to receive(:on_target!).with(/chage/, any_args) do |*args|
            options = Hash[*(args[1..-2])]

            expect(options.keys).to contain_exactly(
              "--mindays", "--maxdays", "--warndays", "--inactive", "--expiredate"
            )
            expect(options.values).to all(eq("-1"))
          end

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

      context "whose authorized keys were edited" do
        before do
          current_user = config.users.find { |u| u.id == user.id }
          current_user.authorized_keys = ["ssh-rsa new-key"]
        end

        include_examples "writing authorized keys"
      end

      context "whose password was edited" do
        before do
          current_user = config.users.find { |u| u.id == user.id }
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

      context "whose password was not edited" do
        it "does not execute chpasswd" do
          expect(Yast::Execute).to_not receive(:on_target!).with(/chpasswd/, any_args)

          writer.write
        end
      end
    end

    context "for a new regular user with all the attributes" do
      before do
        user.uid = 1001
        user.gid = 2001
        user.shell = "/bin/y2shell"
        user.home = "/home/y2test"
        user.gecos = ["First line of", "GECOS"]

        config.attach(user)
      end

      include_examples "setting password"
      include_examples "setting password attributes"
      include_examples "writing authorized keys"

      it "executes useradd with all the parameters, including creation of home directory" do
        expect(Yast::Execute).to receive(:on_target!).with(/useradd/, any_args) do |*args|
          expect(args.last).to eq username
          expect(args).to include("--uid", "--gid", "--shell", "--home-dir", "--create-home")
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

      it "executes useradd only with the argument to create the home directory" do
        expect(Yast::Execute).to receive(:on_target!).with(/useradd/, "--create-home", username)

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
          expect(args).to include "--system"
        end

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
      before do
        config.attach(user)
      end

      let(:error) { Cheetah::ExecutionFailed.new("", "", "", "", "error") }

      before do
        allow(Yast::Execute).to receive(:on_target!)
          .with(/useradd/, any_args)
          .and_raise(error)
      end

      it "returns an issues list containing the issue" do
        result = writer.write

        expect(result).to be_a(Y2Issues::List)
        expect(result).to_not be_empty
        expect(result.map(&:message)).to include(/user.*could not be created/)
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

      before do
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
  end
end
