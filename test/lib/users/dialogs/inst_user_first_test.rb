#!/usr/bin/env rspec

# Copyright (c) [2018-2021] SUSE LLC
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

require_relative "../../../test_helper"
require "users/dialogs/inst_user_first"
require "y2users"

describe Yast::InstUserFirstDialog do
  subject(:dialog) { described_class.new(config, user: user) }

  let(:config) { Y2Users::Config.new }

  let(:user) { nil }

  before do
    Users::UsersDatabase.all.clear

    allow(Yast::ShadowConfig).to receive(:fetch)
    allow(Yast::ShadowConfig).to receive(:fetch).with(:sys_uid_max).and_return("499")

    # Mock access time: files in root2 are more recent than files in root3
    allow(File).to receive(:atime).with(/root2/).and_return(Time.new(2018))
    allow(File).to receive(:atime).with(/root3/).and_return(Time.new(2017))
  end

  describe "#run" do
    context "when local users are disabled" do
      before do
        allow(Yast::ProductFeatures).to receive(:GetBooleanFeatureWithFallback)
          .with("globals", "enable_local_users", true).and_return(false)
      end

      it "returns :auto" do
        expect(dialog.run).to eq(:auto)
      end
    end
  end

  describe "#choose_users_handler" do
    let(:users_to_import_dialog) { instance_double(Yast::UsersToImportDialog, run: nil) }
    let(:root3_path) { FIXTURES_PATH.join("root3") }

    context "when there is a previous Linux installation" do
      before do
        Users::UsersDatabase.import(root3_path)
      end

      it "displays a dialog with importable users found" do
        expect(Yast::UsersToImportDialog).to receive(:new)
          .with(["b_user", "c_user"], [])
          .and_return(users_to_import_dialog)

        dialog.choose_users_handler
      end
    end

    context "when there are multiple previous Linux installations" do
      before do
        Users::UsersDatabase.import(FIXTURES_PATH.join("root2"))
        Users::UsersDatabase.import(FIXTURES_PATH.join("root3"))
      end

      it "displays a dialog with importable users found on the most recently accessed" do
        expect(Yast::UsersToImportDialog).to receive(:new)
          .with(["a_user"], [])
          .and_return(users_to_import_dialog)

        dialog.choose_users_handler
      end
    end
  end

  describe "next_handler" do
    before do
      allow(subject).to receive(:action).and_return(action)

      allow(Yast::UI).to receive(:QueryWidget)
      allow(Yast::UI).to receive(:QueryWidget).with(Id(:username), :Value).and_return(username)
      allow(Yast::UI).to receive(:QueryWidget).with(Id(:pw1), :Value).and_return(password1)
      allow(Yast::UI).to receive(:QueryWidget).with(Id(:pw2), :Value).and_return(password2)
      allow(Yast::UI).to receive(:QueryWidget).with(Id(:autologin), :Value).and_return(autologin)
      allow(Yast::UI).to receive(:QueryWidget).with(Id(:root_pw), :Value).and_return(root_pw)

      ::Users::UsersDatabase.import(FIXTURES_PATH.join("root3"))
      allow(::Users::UsersDatabase.all.first).to receive(:config).and_return(importing_config)
    end

    let(:username) { nil }

    let(:password1) { nil }

    let(:password2) { nil }

    let(:autologin) { nil }

    let(:root_pw) { nil }

    let(:importing_config) { Y2Users::Config.new.attach(importable_users) }

    let(:importable_users) { [] }

    shared_examples "form error" do |error|
      before do
        allow(Yast::Report).to receive(:Error)
      end

      it "reports an error" do
        expect(Yast::Report).to receive(:Error).with(/#{error}/)

        subject.next_handler
      end
    end

    context "when the option for creating a new user is selected" do
      let(:action) { :new_user }

      context "and no username is given" do
        let(:username) { "" }

        include_examples "form error", "cannot be blank"
      end

      context "and the given username already exists" do
        before do
          config.attach(Y2Users::User.new("test"))
        end

        let(:username) { "test" }
        let(:password1) { "SuperS3cr3T" }
        let(:password2) { "SuperS3cr3T" }

        include_examples "form error", "existing username"
      end

      context "when no password is given" do
        let(:username) { "test" }
        let(:password1) { "" }
        let(:password2) { "" }

        include_examples "form error"
      end

      context "when the given password does not match" do
        let(:username) { "test" }
        let(:password1) { "s3cr3t" }
        let(:password2) { "secret" }

        include_examples "form error", "do not match"
      end

      context "when the given password is not valid" do
        let(:username) { "test" }
        let(:password1) { "1234á" }
        let(:password2) { "1234á" }

        include_examples "form error"
      end

      context "when the form has no errors" do
        let(:username) { "test" }
        let(:password1) { "SuperS3cr3T" }
        let(:password2) { "SuperS3cr3T" }
        let(:autologin) { true }

        it "adds the user to the config" do
          subject.next_handler

          expect(config.users.by_name("test")).to_not be_nil
        end

        it "configures the autologin" do
          subject.next_handler

          expect(config.login).to_not be_nil
          expect(config.login.autologin?).to eq(true)
        end

        context "when the option \"use passwor for root\" is selected" do
          let(:root_pw) { true }

          it "assigns the same password to the root user" do
            subject.next_handler

            expect(config.users.root.password.value.content).to eq("SuperS3cr3T")
          end
        end

        context "when the option \"use passwor for root\" is not selected" do
          let(:root_pw) { false }

          context "but it was initially selected" do
            before do
              root = Y2Users::User.create_root
              root.password = Y2Users::Password.create_plain("initialS3cr3T")

              user.password = Y2Users::Password.create_plain("initialS3cr3T")

              config.attach(root)
            end

            let(:user) { Y2Users::User.new("test") }

            it "resets the root password" do
              subject.next_handler

              expect(config.users.root.password).to be_nil
            end
          end

          context "but the new password matches with the curren root password" do
            before do
              root = Y2Users::User.create_root
              root.password = Y2Users::Password.create_plain("SuperS3cr3T")

              config.attach(root)
            end

            it "resets the root password" do
              subject.next_handler

              expect(config.users.root.password).to be_nil
            end
          end
        end

        context "when there were imported users" do
          let(:importable_users) do
            [
              Y2Users::User.new("imported1"),
              Y2Users::User.new("imported2")
            ]
          end

          before do
            config.attach(importable_users.map(&:copy))
          end

          it "removes the imported users" do
            subject.next_handler

            expect(config.users.by_name("imported1")).to be_nil
            expect(config.users.by_name("imported2")).to be_nil
          end
        end
      end
    end

    context "when the option for importing users is selected" do
      let(:action) { :import }

      let(:importable_users) do
        [
          Y2Users::User.new("imported1"),
          Y2Users::User.new("imported2"),
          Y2Users::User.new("imported3"),
          Y2Users::User.new("imported4")
        ]
      end

      before do
        allow(Yast::UsersToImportDialog).to receive(:new).and_return(import_dialog)

        imported = [
          importing_config.users.by_name("imported1"),
          importing_config.users.by_name("imported3")
        ]

        config.attach(imported.map(&:copy))

        config.login = Y2Users::LoginConfig.new
        config.login.autologin_user = user
      end

      let(:import_dialog) { instance_double(Yast::UsersToImportDialog, run: selected_names) }

      let(:selected_names) { ["imported2", "imported4"] }

      let(:user) { Y2Users::User.new("test") }

      it "removes previously configued user" do
        subject.choose_users_handler
        subject.next_handler

        expect(config.users.by_name("test")).to be_nil
      end

      it "removes previously imported users" do
        subject.choose_users_handler
        subject.next_handler

        expect(config.users.by_name("imported1")).to be_nil
        expect(config.users.by_name("imported3")).to be_nil
      end

      it "imports the new selected users" do
        subject.choose_users_handler
        subject.next_handler

        expect(config.users.by_name("imported2")).to_not be_nil
        expect(config.users.by_name("imported4")).to_not be_nil
      end

      it "disables autologin" do
        subject.choose_users_handler
        subject.next_handler

        expect(config.login.autologin?).to eq(false)
      end
    end

    context "when the option for skipping user creation is selected" do
      let(:action) { :skip }

      let(:importable_users) do
        [
          Y2Users::User.new("imported1"),
          Y2Users::User.new("imported2")
        ]
      end

      before do
        config.attach(importable_users.map(&:copy))

        config.login = Y2Users::LoginConfig.new
        config.login.autologin_user = user
      end

      let(:user) { Y2Users::User.new("test") }

      it "removes previously configued user" do
        subject.next_handler

        expect(config.users.by_name("test")).to be_nil
      end

      it "removes previously imported users" do
        subject.next_handler

        expect(config.users.by_name("imported1")).to be_nil
        expect(config.users.by_name("imported2")).to be_nil
      end

      it "disables autologin" do
        subject.next_handler

        expect(config.login.autologin?).to eq(false)
      end
    end
  end
end
