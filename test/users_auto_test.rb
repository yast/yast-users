#!/usr/bin/env rspec

require_relative "test_helper"
require "yaml"

describe "Yast::UsersAutoClient" do
  Yast.import "WFM"
  Yast.import "Users"
  Yast.import "Users"
  Yast.import "Report"

  subject { Yast::UsersAutoClient.new }
  let(:mode) { "autoinstallation" }

  before do
    allow(Yast).to receive(:import).and_call_original
    allow(Yast).to receive(:import).with("Ldap")
    allow(Yast).to receive(:import).with("LdapPopup")

    allow(Yast::Mode).to receive(:mode).and_return(mode)

    # this actually executes the client 8-O
    require_relative "../src/clients/users_auto"
  end

  describe "#AutoYaST" do
    context "Import" do
      before do
        allow(Yast::WFM).to receive(:Args).with(no_args).and_return([func, users])
        allow(Yast::WFM).to receive(:Args).with(0).and_return(func)
        allow(Yast::WFM).to receive(:Args).with(1).and_return(users)
      end

      let(:func) { "Import" }

      context "when double users have been given in the profile" do
        let(:users) { YAML.load_file(FIXTURES_PATH.join("users_error.yml")) }
        it "report error" do
          expect(Yast::Report).to receive(:Error).with(_("Found users in profile with equal <username>."))
          expect(Yast::Report).to receive(:Error).with(_("Found users in profile with equal <uid>."))
          expect(subject.main).to eq(true)
        end
      end
      context "when users without any UID are defined in the profile" do
        let(:users) { YAML.load_file(FIXTURES_PATH.join("users_no_error.yml")) }
        it "will not be checked for double UIDs" do
          expect(Yast::Report).not_to receive(:Error).with(_("Found users in profile with equal <username>."))
          expect(Yast::Report).not_to receive(:Error).with(_("Found users in profile with equal <uid>."))
          expect(subject.main).to eq(true)
        end
      end
    end
  end
end
