#!/usr/bin/env rspec

require_relative "test_helper"
require "fileutils"
require "yaml"
require "users/clients/users_finish"

Yast.import "Users"

describe Yast::UsersFinishClient do
  Yast.import "WFM"
  Yast.import "UsersPasswd"
  Yast.import "UsersSimple"
  Yast.import "Autologin"
  Yast.import "Report"

  describe "#run" do
    before do
      allow(Yast::WFM).to receive(:Args).with(no_args).and_return(args)
      allow(Yast::WFM).to receive(:Args) { |n| n.nil? ? args : args[n] }
    end

    context "Info" do
      let(:args) { ["Info"] }

      it "returns a hash describing the client" do
        expect(subject.run).to be_kind_of(Hash)
      end
    end

    context "Write" do
      let(:args) { ["Write"] }
      let(:users) { YAML.load_file(FIXTURES_PATH.join("users.yml")) }

      before do
        allow(Yast::Mode).to receive(:autoinst).and_return(autoinst)
        allow(Yast::Execute).to receive(:on_target!).and_return("")
      end

      around do |example|
        change_scr_root(FIXTURES_PATH.join("root")) { example.run }
        FileUtils.rm_rf(FIXTURES_PATH.join("root", "var"))
      end

      xcontext "in autoinst mode" do
        let(:autoinst) { true }

        before do
          # Writing users involves executing commands (cp, chmod, etc.) and those
          # calls can't be mocked (Perl code).
          allow(Yast::Users).to receive(:Write).and_return("")
          Yast::Users.Import(users)
        end

        it "add users specified in the profile" do
          subject.run

          yast_user = Yast::Users.GetUsers("uid", "local").fetch("yast")
          expect(yast_user).to_not be_nil
        end

        it "updates root account" do
          subject.run

          root_user = Yast::Users.GetUsers("uid", "system").fetch("root")
          expect(root_user["userPassword"]).to_not be_empty
        end

        it "preserves system accounts passwords" do
          subject.run

          shadow = Yast::UsersPasswd.GetShadow("system")
          passwords = shadow.values.map { |u| u["userPassword"] }
          expect(passwords).to all(satisfy { |v| !v.empty? })
        end
      end

      context "not in autoinst mode" do
        let(:autoinst) { false }

        before do
          # Mocking to avoid to write to the system
          allow_any_instance_of(Y2Users::Linux::Writer).to receive(:write).and_return(issues)

          # Mocking to avoid to read from the system
          allow(Y2Users::ConfigManager.instance).to receive(:system).and_return(system_config)

          allow(system_config).to receive(:merge).and_return(target_config)

          # Mocking to avoid to write to the system
          allow(Yast::Autologin).to receive(:Write)

          allow(Yast::UsersSimple).to receive(:AutologinUsed).and_return(autologin)
          allow(Yast::UsersSimple).to receive(:GetAutologinUser).and_return(autologin_user)
        end

        let(:system_config) { Y2Users::Config.new }

        let(:target_config) { Y2Users::Config.new }

        let(:autologin) { nil }

        let(:autologin_user) { nil }

        let(:writer) { instance_double(Y2Users::Linux::Writer, write: issues) }

        let(:issues) { [] }

        it "calls the linux writer with the expected configs" do
          expect(Y2Users::Linux::Writer).to receive(:new).with(target_config, system_config)
            .and_return(writer)

          expect(writer).to receive(:write)

          subject.run
        end

        context "when the writer does not report issues" do
          let(:issues) { [] }

          it "does not report errors to the user" do
            expect(Yast::Report).to_not receive(:Error)

            subject.run
          end
        end

        context "when the writer reports issues" do
          let(:issues) { [issue1, issue2] }

          let(:issue1) { Y2Issues::Issue.new("error 1") }

          let(:issue2) { Y2Issues::Issue.new("error 2") }

          it "reports all errors to the user" do
            expect(Yast::Report).to receive(:Error).with("error 1\n\nerror 2")

            subject.run
          end
        end

        context "when a user is configured for auto-login" do
          let(:autologin) { true }

          let(:autologin_user) { true }

          it "configures auto-login for that user" do
            expect(Yast::Autologin).to receive(:Disable)
            expect(Yast::Autologin).to receive(:user=).with(autologin_user)
            expect(Yast::Autologin).to receive(:Use).with(true)

            subject.run
          end

          it "writes the auto-login config" do
            expect(Yast::Autologin).to receive(:Write)

            subject.run
          end
        end

        context "when no user is configured for auto-login" do
          let(:autologin) { false }

          it "configures auto-login for no user" do
            expect(Yast::Autologin).to receive(:Disable)
            expect(Yast::Autologin).to_not receive(:user=)
            expect(Yast::Autologin).to_not receive(:Use)

            subject.run
          end

          it "writes the auto-login config" do
            expect(Yast::Autologin).to receive(:Write)

            subject.run
          end
        end
      end
    end
  end
end
