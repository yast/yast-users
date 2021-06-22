#!/usr/bin/env rspec

# Copyright (c) [2016-2021] SUSE LLC
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
require "fileutils"
require "yaml"
require "users/clients/users_finish"

Yast.import "WFM"
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

        Y2Users::ConfigManager.instance.target = target_config

        allow(Y2Users::ConfigManager.instance).to receive(:system)
          .with(force_read: true).and_return(system_config)

        allow(Y2Users::Linux::Writer).to receive(:new).and_return(writer)
      end

      let(:writer) { instance_double(Y2Users::Linux::Writer, write: issues) }

      let(:issues) { [] }

      around do |example|
        change_scr_root(FIXTURES_PATH.join("root")) { example.run }
        FileUtils.rm_rf(FIXTURES_PATH.join("root", "var"))
      end

      let(:target_config) do
        Y2Users::Config.new.tap { |c| c.attach(target_root) }
      end

      let(:target_root) do
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

      shared_examples "issues report" do
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
            expect(Yast2::Popup).to receive(:show).with(/error 1.*error 2/, anything)

            subject.run
          end
        end
      end

      context "in autoinst mode" do
        let(:autoinst) { true }

        before do
          allow(Yast::Stage).to receive(:initial).and_return(initial_stage)
        end

        context "during the 1st stage" do
          let(:initial_stage) { true }

          it "merges system and AutoYaST configuration keeping the original uids/gids" do
            expect(Y2Users::Linux::Writer).to receive(:new) do |target, sys|
              root = target.users.root
              expect(root.uid).to eq("0")
              expect(root.gecos).to eq(["Superuser"])
              expect(root.shell).to eq("/bin/bash")
              expect(sys).to eq(system_config)
            end.and_return(writer)

            expect(writer).to receive(:write)

            subject.run
          end

          include_examples "issues report"
        end

        context "on an installed system" do
          let(:initial_stage) { false }

          it "merges system and AutoYaST configuration updating the uids/gids" do
            expect(Y2Users::Linux::Writer).to receive(:new) do |target, sys|
              root = target.users.root
              expect(root.uid).to eq("1")
              expect(root.gecos).to eq(["Superuser"])
              # TODO: should we use the default value?
              # expect(root.shell).to eq("/bin/bash")
              expect(sys).to eq(system_config)
            end.and_return(writer)

            expect(writer).to receive(:write)

            subject.run
          end

          include_examples "issues report"
        end
      end

      context "not in autoinst mode" do
        let(:autoinst) { false }

        it "merges system and target configuration" do
          expect(Y2Users::Linux::Writer).to receive(:new) do |target, sys|
            root = target.users.root
            expect(root.uid).to eq("1")
            expect(root.gecos).to eq(["Superuser"])
            expect(root.shell).to be_nil
            expect(sys).to eq(system_config)
          end.and_return(writer)

          expect(writer).to receive(:write)

          subject.run
        end

        include_examples "issues report"
      end
    end
  end
end
