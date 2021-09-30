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
require "y2users/user"
require "y2users/group"
require "y2users/password"
require "y2users/linux/writer"
require "y2users/commit_config_collection"

describe Y2Users::Linux::Writer do
  subject(:writer) { described_class.new(config, initial_config, commit_configs) }

  describe "Handling exit codes on #write" do
    let(:initial_config) do
      config = Y2Users::Config.new
      config.attach(users)
      config
    end
    let(:config) { initial_config.copy }

    let(:commit_configs) { Y2Users::CommitConfigCollection.new }

    let(:users) { [] }

    let(:user) do
      user = Y2Users::User.new("testuser")
      user.password = Y2Users::Password.new(pwd_value)
      user.receive_system_mail = false
      user
    end
    let(:pwd_value) { Y2Users::PasswordEncryptedValue.new("$6$3HkB4uLKri75$Qg6Pp") }

    let(:keyring) { instance_double(Yast::Users::SSHAuthorizedKeyring, write_keys: true) }

    before do
      allow(Yast::Execute).to receive(:on_target!)
      allow(Yast::Users::SSHAuthorizedKeyring).to receive(:new).and_return(keyring)
      allow(Yast::MailAliases).to receive(:SetRootAlias).and_return true
    end

    context "when #write is executed with no errors" do
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

    context "when there is any error creating a new group" do
      let(:group) do
        Y2Users::Group.new("users").tap do |group|
          group.gid = "100"
          group.users_name = [user.name]
        end
      end

      before do
        config.attach(group)

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

    context "when there is any error modifying a user attribute" do
      let(:users) { [user] }
      let(:current_user) { config.users.by_id(user.id) }

      before do
        allow(Yast).to receive(:y2_logger)

        current_user.home = Y2Users::Home.new("/home/new")
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
  end
end
