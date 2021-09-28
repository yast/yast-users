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
require "y2users/password"
require "y2users/linux/writer"

describe Y2Users::Linux::Writer do
  subject(:writer) { described_class.new(config, initial_config) }

  describe "Writing root aliases" do
    subject(:writer) { Y2Users::Linux::Writer.new(config, initial_config) }

    let(:initial_config) { Y2Users::Config.new }
    let(:config) { initial_config.copy }

    let(:user) do
      user = Y2Users::User.new(username)
      user.password = Y2Users::Password.new(pwd_value)
      user.password.maximum_age = 30
      user.receive_system_mail = receiving_system_mails
      user.system = system_user
      user.authorized_keys = ["ssh-rsa key"]
      user
    end
    let(:pwd_value) { Y2Users::PasswordEncryptedValue.new("$6$3HkB4uLKri75$Qg6Pp") }
    let(:system_user) { false }

    def raise_error_for(command)
      exit_double = instance_double(Process::Status)
      allow(exit_double).to receive(:exitstatus).and_return(2)
      allow(Yast::Execute).to receive(:on_target!)
        .with(/#{command}/, any_args)
        .and_raise(Cheetah::ExecutionFailed.new("", exit_double, "", "", "error"))
    end

    def raise_authorized_keys_error
      keyring = instance_double(Yast::Users::SSHAuthorizedKeyring, write_keys: true)
      error = Yast::Users::SSHAuthorizedKeyring::HomeDoesNotExist.new("/home/user")

      allow(Yast::Users::SSHAuthorizedKeyring).to receive(:new).and_return(keyring)
      allow(keyring).to receive(:write_keys).and_return(error)
    end

    RSpec.shared_examples "set root alias for" do |username|
      it "includes #{username} as root alias" do
        expect(Yast::MailAliases).to receive(:SetRootAlias).with(kind_of(String)) do |arg|
          expect(arg).to include(username)
        end

        writer.write
      end
    end

    RSpec.shared_examples "does not set root alias for" do |username|
      it "does not include #{username} as root alias" do
        expect(Yast::MailAliases).to receive(:SetRootAlias).with(kind_of(String)) do |arg|
          expect(arg).to_not include(username)
        end

        writer.write
      end
    end

    RSpec.shared_examples "creates new user" do |type|
      let(:system_user) { type == :system }

      let(:username) { "new-user" }

      before { config.attach(user) }

      context "which has not been set to receive system mails" do
        let(:receiving_system_mails) { false }

        include_examples "does not set root alias for", "new-user"
      end

      context "which has been set to receive system mails" do
        let(:receiving_system_mails) { true }

        context "and it was created successfully" do
          include_examples "set root alias for", "new-user"

          context "but setting password value fails" do
            before { raise_error_for(:chpasswd) }

            include_examples "set root alias for", "new-user"
          end

          context "but setting password attributes fails" do
            before { raise_error_for(:chage) }

            include_examples "set root alias for", "new-user"
          end

          context "but setting authorized keys fails" do
            before { raise_authorized_keys_error }

            include_examples "set root alias for", "new-user"
          end
        end

        context "but it couldn't be created" do
          before { raise_error_for(:useradd) }

          include_examples "does not set root alias for", "new-user"
        end
      end
    end

    before do
      allow(Yast::Execute).to receive(:on_target!)
    end

    describe "when creating a new system user" do
      include_examples "creates new user", :system
    end

    describe "when creating a new regular user" do
      include_examples "creates new user", :regular
    end

    describe "when editing an existing user" do
      let(:username) { "existing-user" }
      let(:edited_user) { config.users.by_id(user.id) }

      before do
        initial_config.attach(user)
        edited_user.name = "edited-user"
        edited_user.receive_system_mail =  should_receive_system_mails
        edited_user.password.value = Y2Users::PasswordEncryptedValue.new("$6$3HkB4uLKri75")
        edited_user.password.maximum_age = 60
        edited_user.authorized_keys = ["ssh-rsa new-key"]
      end

      context "which was already set as root alias" do
        let(:receiving_system_mails) { true }

        context "and has been changed to stop receiving system mails" do
          let(:should_receive_system_mails) { false }

          context "and it was updated successfully" do
            include_examples "does not set root alias for", "edited-user"

            context "but setting password value fails" do
              before { raise_error_for(:chpasswd) }

              include_examples "does not set root alias for", "edited-user"
            end

            context "but setting password attributes fails" do
              before { raise_error_for(:chage) }

              include_examples "does not set root alias for", "edited-user"
            end

            context "but setting authorized keys fails" do
              before { raise_authorized_keys_error }

              include_examples "does not set root alias for", "edited-user"
            end
          end

          context "but it couldn't be updated" do
            before { raise_error_for(:usermod) }

            include_examples "set root alias for", "existing-user"
            include_examples "does not set root alias for", "edited-user"
          end
        end

        context "and it should keep receiving system mails" do
          let(:should_receive_system_mails) { true }

          context "and it was updated successfully" do
            include_examples "set root alias for", "edited-user"
            include_examples "does not set root alias for", "existing-user"

            context "but setting password value fails" do
              before { raise_error_for(:chpasswd) }

              include_examples "set root alias for", "edited-user"
              include_examples "does not set root alias for", "existing-user"
            end

            context "but setting password attributes fails" do
              before { raise_error_for(:chage) }

              include_examples "set root alias for", "edited-user"
              include_examples "does not set root alias for", "existing-user"
            end

            context "but setting authorized keys fails" do
              before { raise_authorized_keys_error }

              include_examples "set root alias for", "edited-user"
              include_examples "does not set root alias for", "existing-user"
            end
          end

          context "but it couldn't be updated" do
            before { raise_error_for(:usermod) }

            include_examples "set root alias for", "existing-user"
            include_examples "does not set root alias for", "edited-user"
          end
        end
      end

      context "which was not set as root alias" do
        let(:receiving_system_mails) { false }

        context "and has been changed to start receiving system mails" do
          let(:should_receive_system_mails) { true }

          context "and it was updated successfully" do
            include_examples "set root alias for", "edited-user"

            context "but setting password value fails" do
              before { raise_error_for(:chpasswd) }

              include_examples "set root alias for", "edited-user"
            end

            context "but setting password attributes fails" do
              before { raise_error_for(:chage) }

              include_examples "set root alias for", "edited-user"
            end

            context "but setting authorized keys fails" do
              before { raise_authorized_keys_error }

              include_examples "set root alias for", "edited-user"
            end
          end

          context "but it couldn't be updated" do
            before { raise_error_for(:usermod) }

            include_examples "does not set root alias for", "existing-user"
            include_examples "does not set root alias for", "edited-user"
          end
        end

        context "and it should keep not receiving system mails" do
          let(:should_receive_system_mails) { false }

          context "and it was updated successfully" do
            include_examples "does not set root alias for", "edited-user"

            context "but setting password value fails" do
              before { raise_error_for(:chpasswd) }

              include_examples "does not set root alias for", "edited-user"
            end

            context "but setting password attributes fails" do
              before { raise_error_for(:chage) }

              include_examples "does not set root alias for", "edited-user"
            end

            context "but setting authorized keys fails" do
              before { raise_authorized_keys_error }

              include_examples "does not set root alias for", "edited-user"
            end
          end

          context "but it couldn't be updated" do
            before { raise_error_for(:usermod) }

            include_examples "does not set root alias for", "existing-user"
            include_examples "does not set root alias for", "edited-user"
          end
        end
      end
    end

    describe "handling the result of SetRootAlias" do
      before do
        allow(Yast::MailAliases).to receive(:SetRootAlias).and_return(set_root_alias_result)
      end

      context "when setting root aliases returns true" do
        let(:set_root_alias_result) { true }

        it "returns an empty issues list" do
          result = writer.write

          expect(result).to be_a(Y2Issues::List)
          expect(result).to be_empty
        end
      end

      context "when setting root aliases returns false" do
        let(:set_root_alias_result) { false }

        it "returns an empty list holding an explanatory issue" do
          result = writer.write

          expect(result).to be_a(Y2Issues::List)
          expect(result).to_not be_empty
          expect(result.first.message).to match(/Error.*root mail aliases/)
        end
      end
    end
  end
end
