#!/usr/bin/env rspec

require_relative "test_helper"
require "fileutils"
require "yaml"
require "users/clients/users_finish"

Yast.import "WFM"
Yast.import "UsersSimple"
Yast.import "Autologin"
Yast.import "Report"

describe Yast::UsersFinishClient do
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

      context "in autoinst mode" do
        let(:autoinst) { true }
        let(:initial_stage) { true }

        let(:ay_config) do
          Y2Users::Config.new.tap { |c| c.attach(ay_root) }
        end

        let(:ay_root) do
          Y2Users::User.new("root").tap do |user|
            user.uid = "1"
            user.gecos = ["Superuser"]
          end
        end

        let(:system_config) do
          Y2Users::Config.new.tap { |c| c.attach(system_root) }
        end

        let(:system_root) do
          Y2Users::User.new("root").tap do |user|
            user.uid = "0"
            user.shell = "/bin/bash"
          end
        end

        let(:writer) { instance_double(Y2Users::Linux::Writer, write: []) }

        before do
          allow(Yast::Stage).to receive(:initial).and_return(initial_stage)
          allow(Y2Users::ConfigManager.instance).to receive(:config)
            .with(:autoinst).and_return(ay_config)
          allow(Y2Users::ConfigManager.instance).to receive(:system)
            .with(force_read: true).and_return(system_config)
        end

        context "during the 1st stage" do
          it "merges system and AutoYaST configuration keeping the original uids/gids" do
            expect(Y2Users::Linux::Writer).to receive(:new) do |target, sys|
              root = target.users.first
              expect(root.uid).to eq("0")
              expect(root.gecos).to eq(["Superuser"])
              expect(root.shell).to eq("/bin/bash")
              expect(sys).to eq(system_config)
              writer
            end
            expect(writer).to receive(:write).and_return([])
            subject.run
          end
        end

        context "on an installed system" do
          let(:initial_stage) { false }

          it "merges system and AutoYaST configuration updating the uids/gids" do
            expect(Y2Users::Linux::Writer).to receive(:new) do |target, sys|
              root = target.users.first
              expect(root.uid).to eq("1")
              expect(root.gecos).to eq(["Superuser"])
              # TODO: should we use the default value?
              # expect(root.shell).to eq("/bin/bash")
              expect(sys).to eq(system_config)
              writer
            end
            expect(writer).to receive(:write).and_return([])
            subject.run
          end
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
        end

        let(:system_config) { Y2Users::Config.new }

        let(:target_config) { Y2Users::Config.new }

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
      end
    end
  end
end
