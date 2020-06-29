#!/usr/bin/env rspec

require_relative "../../test_helper"
require "yaml"
require "users/clients/auto"
Yast.import "Report"

describe Y2Users::Clients::Auto do
  let(:mode) { "autoinstallation" }
  let(:args) { [func] }

  before do
    allow(Yast).to receive(:import).and_call_original
    allow(Yast).to receive(:import).with("Ldap")
    allow(Yast).to receive(:import).with("LdapPopup")
    allow(Yast::Mode).to receive(:mode).and_return(mode)
    allow(Yast::WFM).to receive(:Args).and_return(args)
  end

  describe "#run" do
    context "Import" do
      let(:func) { "Import" }
      let(:args) { [func, users] }

      context "when double users have been given in the profile" do
        let(:users) { YAML.load_file(FIXTURES_PATH.join("users_error.yml")) }

        it "report error" do
          expect(Yast::Report).to receive(:Error)
            .with(_("Found users in profile with equal <username>."))
          expect(Yast::Report).to receive(:Error)
            .with(_("Found users in profile with equal <uid>."))
          expect(subject.run).to eq(true)
        end
      end

      context "when users without any UID are defined in the profile" do
        let(:users) { YAML.load_file(FIXTURES_PATH.join("users_no_error.yml")) }

        it "will not be checked for double UIDs" do
          expect(Yast::Report).not_to receive(:Error)
            .with(_("Found users in profile with equal <username>."))
          expect(Yast::Report).not_to receive(:Error)
            .with(_("Found users in profile with equal <uid>."))
          expect(subject.run).to eq(true)
        end
      end
    end

    context "Change" do
      let(:func) { "Change" }

      it "returns the 'summary' autosequence result" do
        expect(subject).to receive(:AutoSequence).and_return(:next)
        expect(subject.run).to eq(:next)
      end
    end

    context "Summary" do
      let(:func) { "Summary" }

      before do
        allow(Yast::Users).to receive(:Summary).and_return("summary")
      end

      it "returns the users summary" do
        expect(subject.run).to eq("summary")
      end
    end

    context "Export" do
      let(:func) { "Export" }
      let(:args) { [func] }

      let(:local_users) { double("local_users") }
      let(:all_users) { double("all_users") }

      before do
        allow(Yast::WFM).to receive(:Args).and_return(args)
        allow(Yast::Users).to receive(:Export).with("default")
          .and_return(all_users)
        allow(Yast::Users).to receive(:Export).with("compact")
          .and_return(local_users)
      end

      it "exports all users and groups" do
        expect(subject.run).to eq(all_users)
      end

      context "when 'compact' export is wanted" do
        let(:args) { [func, "target" => "compact"] }

        it "it exports only local users and groups" do
          expect(subject.run).to eq(local_users)
        end
      end
    end

    context "Modified" do
      let(:func) { "GetModified" }

      before do
        allow(Yast::Users).to receive(:Modified).and_return(true)
      end

      it "returns whether the data in Users module has been modified" do
        expect(subject.run).to eq(true)
      end
    end

    context "SetModified" do
      let(:func) { "SetModified" }

      it "sets the Users module as modified" do
        expect(Yast::Users).to receive(:SetModified).with(true)
        subject.run
      end
    end
  end
end
