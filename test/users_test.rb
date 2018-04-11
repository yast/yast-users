#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "Users"

describe "Users" do
  subject(:users) { Yast::Users }

  describe "#WriteAuthorizedKeys" do
    context "when no user is defined" do
      it "returns true" do
        expect(users.WriteAuthorizedKeys).to eq(true)
      end
    end
  end
end
