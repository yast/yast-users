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

require "y2issues/list"
require "y2issues/issue"
require "y2users/linux/users_writer"
require "y2users/config"
require "y2users/commit_config_collection"
require "y2users/commit_config"
require "y2users/user"
require "y2users/password"
require "y2users/linux/delete_user_action"
require "y2users/linux/action_result"

describe Y2Users::Linux::UsersWriter do
  subject { described_class.new(target_config, initial_config, commit_configs) }

  let(:initial_config) do
    Y2Users::Config.new.tap do |config|
      config.attach(users)
    end
  end

  let(:target_config) { initial_config.copy }

  let(:commit_configs) { Y2Users::CommitConfigCollection.new([commit_config]) }

  let(:users) { [test1, test2] }

  let(:test1) { Y2Users::User.new("test1") }

  let(:test2) { Y2Users::User.new("test2") }

  let(:commit_config) { Y2Users::CommitConfig.new }

  describe "#write" do
    let(:create_user_action) { Y2Users::Linux::CreateUserAction }

    let(:edit_user_action) { Y2Users::Linux::EditUserAction }

    let(:delete_user_action) { Y2Users::Linux::DeleteUserAction }

    let(:set_user_password_action) { Y2Users::Linux::SetUserPasswordAction }

    let(:delete_user_password_action) { Y2Users::Linux::DeleteUserPasswordAction }

    let(:remove_home_content_action) { Y2Users::Linux::RemoveHomeContentAction }

    let(:set_home_ownership_action) { Y2Users::Linux::SetHomeOwnershipAction }

    let(:set_auth_keys_action) { Y2Users::Linux::SetAuthKeysAction }

    def mock_action(action, result, *users)
      action_instance = instance_double(action, perform: result)

      allow(action).to receive(:new).with(*users, anything).and_return(action_instance)

      action_instance
    end

    def success(*messages)
      Y2Users::Linux::ActionResult.new(true, issues(messages))
    end

    def failure(*messages)
      Y2Users::Linux::ActionResult.new(false, issues(messages))
    end

    def issues(messages)
      issues = messages.map { |m| Y2Issues::Issue.new(m) }

      Y2Issues::List.new(issues)
    end

    before do
      # Prevent to perform real actions into the system
      allow_any_instance_of(Y2Users::Linux::Action).to receive(:perform).and_return(success)
      allow(Yast::MailAliases).to receive(:SetRootAlias)
    end

    it "deletes, edits and creates users in that order" do
      deleted_user = target_config.users.by_id(test2.id)
      target_config.detach(deleted_user)

      edited_user = target_config.users.by_id(test1.id)
      edited_user.name = "new_name"

      new_user = Y2Users::User.new("test3")
      target_config.attach(new_user)

      delete_action = mock_action(delete_user_action, success, test2)
      edit_action = mock_action(edit_user_action, success, test1, edited_user)
      create_action = mock_action(create_user_action, success, new_user)

      expect(delete_action).to receive(:perform).ordered
      expect(edit_action).to receive(:perform).ordered
      expect(create_action).to receive(:perform).ordered

      subject.write
    end

    context "when a user is deleted from the target config" do
      let(:deleted_user) { target_config.users.by_id(test2.id) }

      before do
        target_config.detach(deleted_user)
      end

      it "performs the action for deleting the user" do
        action = mock_action(delete_user_action, success, test2)

        expect(action).to receive(:perform)

        subject.write
      end

      it "returns the generated issues" do
        mock_action(delete_user_action, success("deleting user issue"), test2)

        issues = subject.write

        expect(issues.map(&:message)).to include(/deleting user issue/)
      end
    end

    context "when a user is edited in the target config" do
      let(:initial_user) { test2 }

      let(:target_user) { target_config.users.by_id(initial_user.id) }

      before do
        target_user.name = "new_name"
      end

      it "performs the action for editing the user" do
        action = mock_action(edit_user_action, success, initial_user, target_user)

        expect(action).to receive(:perform)

        subject.write
      end

      it "returns the generated issues" do
        mock_action(edit_user_action, success("issue editing user"), initial_user, target_user)

        issues = subject.write

        expect(issues.map(&:message)).to include(/issue editing user/)
      end

      context "and the new home path already exists" do
        before do
          target_user.home.path = "/home/new_home"

          allow(File).to receive(:exist?)
          allow(File).to receive(:exist?).with("/home/new_home").and_return(true)
        end

        let(:commit_config) do
          Y2Users::CommitConfig.new.tap do |config|
            config.username = target_user.name
            config.move_home = true
          end
        end

        it "forces to not move the content of the current home" do
          action = instance_double(edit_user_action, perform: success)

          expect(edit_user_action)
            .to receive(:new).with(initial_user, target_user, anything) do |*args|
              commit_config = args.last
              expect(commit_config.move_home?).to eq(false)
            end.and_return(action)

          expect(action).to receive(:perform)

          subject.write
        end
      end

      context "and the action for editing the user successes" do
        before do
          mock_action(edit_user_action, success, initial_user, target_user)

          allow(File).to receive(:exist?).and_call_original
        end

        let(:commit_config) do
          Y2Users::CommitConfig.new.tap do |config|
            config.username = target_user.name
            config.adapt_home_ownership = adapt_home_ownership
          end
        end

        let(:adapt_home_ownership) { nil }

        context "and the home ownership should be set" do
          let(:adapt_home_ownership) { true }

          before do
            allow(File).to receive(:exist?).with(target_user.home.path).and_return(exist_home)
          end

          context "and the user home exists" do
            let(:exist_home) { true }

            it "performs the action for setting the home ownership" do
              action = mock_action(set_home_ownership_action, success, target_user)

              expect(action).to receive(:perform)

              subject.write
            end

            it "returns the generated issues" do
              mock_action(set_home_ownership_action,
                success("issue adapting ownership"), target_user)

              issues = subject.write

              expect(issues.map(&:message)).to include(/issue adapting ownership/)
            end
          end

          context "and the user home does not exist" do
            let(:exist_home) { false }

            it "does not perform the action for setting the home ownership" do
              expect_any_instance_of(set_home_ownership_action).to_not receive(:perform)

              subject.write
            end
          end
        end

        context "and the home ownership should not be set" do
          let(:adapt_home_ownership) { false }

          it "does not perform the action for setting the home ownership" do
            expect_any_instance_of(set_home_ownership_action).to_not receive(:perform)

            subject.write
          end
        end

        context "and the user password has changed" do
          before do
            target_user.password = password
          end

          context "and the user has a password" do
            let(:password) { Y2Users::Password.create_plain("s3cr3t") }

            it "performs the action for setting the password" do
              action = mock_action(set_user_password_action, success, target_user)

              expect(action).to receive(:perform)

              subject.write
            end

            it "returns the generated issues" do
              mock_action(set_user_password_action, success("issue setting password"), target_user)

              issues = subject.write

              expect(issues.map(&:message)).to include(/issue setting password/)
            end
          end

          context "and the user has no password" do
            let(:password) { nil }

            before do
              initial_user.password = Y2Users::Password.new("s3cr3t")
            end

            it "performs the action for deleting the password" do
              action = mock_action(delete_user_password_action, success, target_user)

              expect(action).to receive(:perform)

              subject.write
            end

            it "returns the generated issues" do
              mock_action(delete_user_password_action,
                success("issue deleting password"), target_user)

              issues = subject.write

              expect(issues.map(&:message)).to include(/issue deleting password/)
            end
          end
        end

        context "and the user password has not changed" do
          it "does not perform the action for setting the password" do
            expect_any_instance_of(set_user_password_action).to_not receive(:perform)

            subject.write
          end

          it "does not perform the action for deleting the password" do
            expect_any_instance_of(delete_user_password_action).to_not receive(:perform)

            subject.write
          end
        end

        context "and the authorized keys has changed" do
          before do
            target_user.authorized_keys = ["new-key"]
          end

          context "and the user home exists" do
            before do
              allow(File).to receive(:exist?).with(target_user.home.path).and_return(true)
            end

            it "performs the action for setting the authorized keys" do
              action = mock_action(set_auth_keys_action, success, target_user)

              expect(action).to receive(:perform)

              subject.write
            end

            it "returns the generated issues" do
              mock_action(set_auth_keys_action, success("issue auth keys"), target_user)

              issues = subject.write

              expect(issues.map(&:message)).to include(/issue auth keys/)
            end
          end

          context "and the user home does not exist" do
            before do
              allow(File).to receive(:exist?).with(target_user.home.path).and_return(false)
            end

            it "does not perform the action for setting the authorized keys" do
              expect_any_instance_of(set_auth_keys_action).to_not receive(:perform)

              subject.write
            end
          end
        end

        context "and the authorized keys has not changed" do
          it "does not perform the action for setting the authorized keys" do
            expect_any_instance_of(set_auth_keys_action).to_not receive(:perform)

            subject.write
          end
        end
      end

      context "and the action for editing the user fails" do
        before do
          mock_action(edit_user_action, failure, initial_user, target_user)
        end

        it "does not perform more actions" do
          expect_any_instance_of(Y2Users::Linux::Action).to_not receive(:perform)

          subject.write
        end
      end
    end

    context "after working with users" do
      # Initial config is empty
      let(:users) { [] }

      before do
        # Successfully created user
        test1 = Y2Users::User.new("test1").tap { |u| u.receive_system_mail = true }
        target_config.attach(test1)
        mock_action(create_user_action, success, test1)

        # Successfully created, but does not receive system mail
        test2 = Y2Users::User.new("test2")
        target_config.attach(test2)
        mock_action(create_user_action, success, test2)

        # Create failure
        test3 = Y2Users::User.new("test3").tap { |u| u.receive_system_mail = true }
        target_config.attach(test3)
        mock_action(create_user_action, failure, test3)

        # Successfully edited
        test4 = Y2Users::User.new("test4").tap { |u| u.receive_system_mail = true }
        initial_config.attach(test4)
        target_test4 = test4.copy.tap { |u| u.name = "test4_edited" }
        target_config.attach(target_test4)
        mock_action(edit_user_action, success, test4, target_test4)

        # Successfully edited, but does not receive system mail
        test5 = Y2Users::User.new("test5")
        initial_config.attach(test5)
        target_test5 = test5.copy.tap { |u| u.name = "test5_edited" }
        target_config.attach(target_test5)
        mock_action(edit_user_action, success, test5, target_test5)

        # Edit failure
        test6 = Y2Users::User.new("test6").tap { |u| u.receive_system_mail = true }
        initial_config.attach(test6)
        target_test6 = test6.copy.tap { |u| u.name = "test6_edited" }
        target_config.attach(target_test6)
        mock_action(edit_user_action, failure, test6, target_test6)

        # Edit failure, but does not receive system mail
        test7 = Y2Users::User.new("test7")
        initial_config.attach(test7)
        target_test7 = test7.copy.tap { |u| u.name = "test7_edited" }
        target_config.attach(target_test7)
        mock_action(edit_user_action, failure, test7, target_test7)

        # Not edited
        test8 = Y2Users::User.new("test8").tap { |u| u.receive_system_mail = true }
        initial_config.attach(test8)
        target_config.attach(test8.copy)

        # Not edited, but does not receive system mail
        test9 = Y2Users::User.new("test9")
        initial_config.attach(test9)
        target_config.attach(test9.copy)

        # Successfully deleted
        test10 = Y2Users::User.new("test10").tap { |u| u.receive_system_mail = true }
        initial_config.attach(test10)
        mock_action(delete_user_action, success, test10)

        # Delete failure
        test11 = Y2Users::User.new("test11").tap { |u| u.receive_system_mail = true }
        initial_config.attach(test11)
        mock_action(delete_user_action, failure, test11)

        # Delete failure, but does not receive system mail
        test12 = Y2Users::User.new("test12")
        initial_config.attach(test12)
        mock_action(delete_user_action, failure, test12)
      end

      it "writes the root aliases" do
        # Root aliases should contain:
        #   * Successfully created users
        #   * Successfully edited users
        #   * Users that could not be edited (the initial user is added)
        #   * Users that could not be deleted
        #   * Not edited users
        expect(Yast::MailAliases).to receive(:SetRootAlias)
          .with("test1, test11, test4_edited, test6, test8")

        subject.write
      end

      context "when setting the root aliases fails" do
        before do
          allow(Yast::MailAliases).to receive(:SetRootAlias).and_return(false)
        end

        it "returns an issue" do
          issues = subject.write

          expect(issues.map(&:message)).to include(/Error setting root mail aliases/)
        end
      end
    end

    context "when a user is added to the target config" do
      let(:test3) { Y2Users::User.new("test3") }

      before do
        target_config.attach(test3)
      end

      it "performs the action for creating the user" do
        action = mock_action(create_user_action, success, test3)

        expect(action).to receive(:perform)

        subject.write
      end

      it "returns the generated issues" do
        mock_action(create_user_action, success("creating user issue"), test3)

        issues = subject.write

        expect(issues.map(&:message)).to include(/creating user issue/)
      end

      context "and the action for creating the user successes" do
        before do
          mock_action(create_user_action, success, test3)
        end

        let(:commit_config) do
          Y2Users::CommitConfig.new.tap do |config|
            config.username = test3.name
            config.home_without_skel = home_without_skel
            config.adapt_home_ownership = adapt_home_ownership
          end
        end

        let(:home_without_skel) { nil }

        let(:adapt_home_ownership) { nil }

        before do
          allow(File).to receive(:exist?).and_call_original
        end

        context "and the user home should be created without skel" do
          let(:home_without_skel) { true }

          before do
            allow(File).to receive(:exist?).with(test3.home.path).and_return(exist_home)
          end

          context "and the home already existed on disk" do
            let(:exist_home) { true }

            it "does not perform the action for removing the home content" do
              expect_any_instance_of(remove_home_content_action).to_not receive(:perform)

              subject.write
            end
          end

          context "and the home did not exist on disk yet" do
            let(:exist_home) { false }

            context "and the home was created" do
              before do
                allow(File).to receive(:exist?).with(test3.home.path).and_return(exist_home, true)
              end

              it "performs the action for removing the home content" do
                action = mock_action(remove_home_content_action, success, test3)

                expect(action).to receive(:perform)

                subject.write
              end

              it "returns the generated issues" do
                mock_action(remove_home_content_action, success("issue removing home"), test3)

                issues = subject.write

                expect(issues.map(&:message)).to include(/issue removing home/)
              end
            end
          end
        end

        context "and the user home should be created with skel" do
          let(:home_without_skel) { false }

          it "does not perform the action for removing the home content" do
            expect_any_instance_of(remove_home_content_action).to_not receive(:perform)

            subject.write
          end
        end

        context "and the home ownership should be set" do
          let(:adapt_home_ownership) { true }

          before do
            allow(File).to receive(:exist?).with(test3.home.path).and_return(exist_home)
          end

          context "and the home was created" do
            let(:exist_home) { true }

            it "performs the action for setting the home ownership" do
              action = mock_action(set_home_ownership_action, success, test3)

              expect(action).to receive(:perform)

              subject.write
            end

            it "returns the generated issues" do
              mock_action(set_home_ownership_action, success("issue adapting ownership"), test3)

              issues = subject.write

              expect(issues.map(&:message)).to include(/issue adapting ownership/)
            end
          end

          context "and the home was not created" do
            let(:exist_home) { false }

            it "does not perform the action for setting the home ownership" do
              expect_any_instance_of(set_home_ownership_action).to_not receive(:perform)

              subject.write
            end
          end
        end

        context "and the home ownership should not be set" do
          let(:adapt_home_ownership) { false }

          it "does not perform the action for setting the home ownership" do
            expect_any_instance_of(set_home_ownership_action).to_not receive(:perform)

            subject.write
          end
        end

        context "and the user has a password" do
          before do
            test3.password = Y2Users::Password.create_plain("s3cr3t")
          end

          it "performs the action for setting the password" do
            action = mock_action(set_user_password_action, success, test3)

            expect(action).to receive(:perform)

            subject.write
          end

          it "returns the generated issues" do
            mock_action(set_user_password_action, success("issue setting password"), test3)

            issues = subject.write

            expect(issues.map(&:message)).to include(/issue setting password/)
          end
        end

        context "and the user has no password" do
          before do
            test3.password = nil
          end

          it "does not perform the action for setting the password" do
            expect_any_instance_of(set_user_password_action).to_not receive(:perform)

            subject.write
          end
        end

        context "and the user home exists" do
          before do
            allow(File).to receive(:exist?).with(test3.home.path).and_return(true)
          end

          it "performs the action for setting the authorized keys" do
            action = mock_action(set_auth_keys_action, success, test3)

            expect(action).to receive(:perform)

            subject.write
          end

          it "returns the generated issues" do
            mock_action(create_user_action, success("issue auth keys"), test3)

            issues = subject.write

            expect(issues.map(&:message)).to include(/issue auth keys/)
          end
        end

        context "and the user home does not exist" do
          before do
            allow(File).to receive(:exist?).with(test3.home.path).and_return(false)
          end

          it "does not perform the action for setting the authorized keys" do
            expect_any_instance_of(set_auth_keys_action).to_not receive(:perform)

            subject.write
          end
        end
      end

      context "and the action for creating the user fails" do
        before do
          mock_action(create_user_action, failure, test3)
        end

        it "does not perform more actions" do
          expect_any_instance_of(Y2Users::Linux::Action).to_not receive(:perform)

          subject.write
        end
      end
    end
  end
end
