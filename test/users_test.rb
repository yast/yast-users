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

  describe "#ImportUser" do
    let(:user) do
      {
        "username" => "root", "home" => "/root", "uid" => 0, "gid" => 0,
        "authorized_keys" => [ssh_public_key]
      }
    end

    let(:ssh_public_key) { File.read(FIXTURES_PATH.join("id_rsa.pub")) }

    it "returns a hash which represents a user with the given values" do
      imported = users.ImportUser(user)
      expect(imported).to include(
        "uid" => "root",
        "homeDirectory" => "/root",
        "authorized_keys" => [ssh_public_key]
      )
    end

    context "when no authorized keys are specified" do
      let(:user) do
        { "username" => "root", "home" => "/root", "uid" => 0, "gid" => 0 }
      end

      it "sets 'authorized_keys' as an empty array" do
        imported = users.ImportUser(user)
        expect(imported["authorized_keys"]).to eq([])
      end
    end
  end
end
