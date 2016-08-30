#!/usr/bin/env rspec

require_relative "test_helper"
require "yaml"
require_relative "../src/clients/users_auto"

describe Yast::UsersAutoClient do
  Yast.import "WFM"
  Yast.import "Users"
  Yast.import "Users"
  Yast.import "Report"

  let(:mode) { "autoinstallation" }

  before do
    allow(Yast::Mode).to receive(:mode).and_return(mode)
  end

  describe "#AutoYaST" do

    context "Import" do
      let(:func) { "Import" }

      context "when double users have been given in the profile" do
        let(:users) { YAML.load_file(FIXTURES_PATH.join("users_error.yml")) }

        before do
          allow(Yast::WFM).to receive(:Args).with(no_args).and_return([func,users])
          allow(Yast::WFM).to receive(:Args).with(0).and_return(func)
          allow(Yast::WFM).to receive(:Args).with(1).and_return(users)
        end

        it "report error" do
          expect(Yast::Report).to receive(:Error).with(_("Found users in profile with equal <username>."))
          expect(Yast::Report).to receive(:Error).with(_("Found users in profile with equal <uid>."))
          expect(subject.main).to eq(true)
        end
      end
    end
  end
end
