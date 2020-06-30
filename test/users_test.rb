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
        "uid"             => "root",
        "homeDirectory"   => "/root",
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

  describe "#Export" do
    let(:root_user) { { "username" => "root", "uid" => "0" } }
    let(:local_user) { { "username" => "user1", "uid" => "1000" } }
    let(:system_user) { { "username" => "messagebus", "uid" => "499" } }

    let(:local_group) { { "groupname" => "devops", "gid" => "1000" } }
    let(:users_group) { { "groupname" => "users", "gid" => "100" } }
    let(:system_group) { { "groupname" => "messagebus", "gid" => "480" } }

    before do
      Yast::Users.Import(
        "users"          => [root_user, local_user, system_user],
        "groups"         => [users_group, local_group, system_group],
        "login_settings" => { "autologin_user" => "root", "password_less_login" => true },
        "user_defaults"  => { "group" => "100", "home" => "/srv/Users" }
      )
    end

    it "exports users" do
      exported = subject.Export
      expect(exported["users"]).to contain_exactly(
        a_hash_including(root_user),
        a_hash_including(local_user),
        a_hash_including(system_user)
      )
    end

    it "exports groups" do
      exported = subject.Export
      expect(exported["groups"]).to contain_exactly(
        a_hash_including(users_group),
        a_hash_including(local_group),
        a_hash_including(system_group)
      )
    end

    it "export login settings" do
      exported = subject.Export
      expect(exported["login_settings"]).to eq(
        "autologin_user" => "root", "password_less_login" => true
      )
    end

    it "exports user defaults" do
      exported = subject.Export
      expect(exported["user_defaults"]).to include("home" => "/srv/Users")
    end

    context "when 'compact' target is required" do
      it "exports 'root' and local users" do
        exported = subject.Export("compact")
        expect(exported["users"]).to contain_exactly(
          a_hash_including(root_user),
          a_hash_including(local_user)
        )
      end

      it "exports 'users' and local groups" do
        exported = subject.Export("compact")
        expect(exported["groups"]).to contain_exactly(
          a_hash_including(users_group),
          a_hash_including(local_group)
        )
      end
    end
  end
end
