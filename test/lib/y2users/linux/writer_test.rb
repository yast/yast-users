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
    let(:initial_config) { Y2Users::Config.new(:initial) }

    let(:config) { initial_config.clone_as(:desired) }
    let(:user) do
      user = Y2Users::User.new(config, username, **user_attrs)
      user.password = password

      user
    end
    let(:password) do
      pw_options = { value: pwd_value, account_expiration: expiration_date }

      Y2Users::Password.new(config, username, pw_options)
    end

    let(:username) { "testuser" }
    let(:user_attrs) { {} }
    let(:pwd_value) { "$6$3HkB4uLKri75$Qg6Pp" }
    let(:expiration_date) { nil }

    RSpec.shared_examples "setting expiration date" do
      context "with an expiration date" do
        let(:expiration_date) { Date.today }

        it "includes the --expiredate option" do
          expect(Yast::Execute).to receive(:on_target!) do |*args|
            expect(args).to include("--expiredate")
            expect(args).to include(expiration_date.to_s)
          end

          writer.write
        end
      end

      context "without an expiration date" do
        it "does not include the --expiredate option" do
          expect(Yast::Execute).to receive(:on_target!) do |*args|
            expect(args).to_not include("--expiredate")
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
      end

      context "which does not have a password set" do
        let(:pwd_value) { nil }

        it "does not execute chpasswd" do
          expect(Yast::Execute).to_not receive(:on_target!).with(/chpasswd/, any_args)

          writer.write
        end
      end
    end

    before do
      config.users << user

      allow(Yast::Execute).to receive(:on_target!)
    end

    context "for an existing user" do
      before do
        initial_config.users << user
      end

      it "does not execute useradd" do
        expect(Yast::Execute).to_not receive(:on_target!).with(/useradd/, any_args)

        writer.write
      end

      include_examples "setting password"
    end

    context "for a new regular user with all the attributes" do
      let(:user_attrs) do
        {
          uid: 1001, gid: 2001, shell: "/bin/y2shell", home: "/home/y2test",
          gecos: ["First line of", "GECOS"]
        }
      end

      include_examples "setting expiration date"
      include_examples "setting password"

      it "executes useradd with all the parameters, including creation of home directory" do
        expect(Yast::Execute).to receive(:on_target!).with(/useradd/, any_args) do |*args|
          expect(args.last).to eq username
          expect(args).to include("--uid", "--gid", "--shell", "--home-dir", "--create-home")
        end

        writer.write
      end
    end

    context "for a new regular user with no optional attributes specified" do
      let(:user_attrs) { {} }

      include_examples "setting expiration date"
      include_examples "setting password"

      it "executes useradd only with the argument to create the home directory" do
        expect(Yast::Execute).to receive(:on_target!).with(/useradd/, "--create-home", username)

        writer.write
      end
    end

    context "for a new system user" do
      let(:user_attrs) { { home: "/var/lib/y2test" } }

      before { user.system = true }

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
      it "returns an empty issues list" do
        result = writer.write

        expect(result).to be_a(Y2Issues::List)
        expect(result).to be_empty
      end
    end

    context "when there is any error adding users" do
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
  end
end
