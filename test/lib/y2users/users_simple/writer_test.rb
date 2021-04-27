#!/usr/bin/env rspec

# Copyright (c) [2021] SUSE LLC
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

require_relative "../test_helper"

require "y2users"
require "y2users/users_simple/writer"

describe Y2Users::UsersSimple::Writer do
  subject { described_class.new(config) }

  let(:config) { Y2Users::Config.new(:test) }

  def user_simple(name)
    Yast::UsersSimple.GetUsers.find { |u| u["uid"] == name }
  end

  describe "#write" do
    before(:each) do
      Yast::UsersSimple.SetRootPassword("")
    end

    # Root user
    let(:root) do
      user = Y2Users::User.new(config, "root",
        uid:   0,
        gid:   0,
        shell: "/bin/bash",
        home:  "/root",
        gecos: ["Root User"])

      user.password = root_password
      user
    end

    let(:root_password) { nil }

    shared_examples "root" do
      it "does not store the root user into the list of users" do
        subject.write

        names = Yast::UsersSimple.GetUsers.map { |u| u["uid"] }

        expect(names).to_not include("root")
      end

      context "when root has no password" do
        let(:root_password) { nil }

        it "does not store a password for root" do
          subject.write

          expect(Yast::UsersSimple.GetRootPassword).to eq("")
        end
      end

      context "when root has password" do
        let(:root_password) do
          pwd = Y2Users::Password.new(config, "root")
          pwd.plain_value = "S3cr3T"
          pwd
        end

        it "stores the password for root" do
          subject.write

          expect(Yast::UsersSimple.GetRootPassword).to eq("S3cr3T")
        end
      end
    end

    context "when the users config does not contain users" do
      before do
        config.users = []
      end

      it "does not store users into UsersSimple module" do
        subject.write

        expect(Yast::UsersSimple.GetUsers).to be_empty
      end

      it "does not store a password for root" do
        subject.write

        expect(Yast::UsersSimple.GetRootPassword).to eq("")
      end
    end

    context "when the users config only contains root" do
      before do
        config.users = [root]
      end

      it "does not store users into UsersSimple module" do
        subject.write

        expect(Yast::UsersSimple.GetUsers).to be_empty
      end

      include_examples "root"
    end

    context "when the users config contains users" do
      before do
        config.users = [root, user1, user2]
      end

      # User

      let(:user1) do
        user = Y2Users::User.new(config, "test1",
          uid:   uid,
          gid:   gid,
          shell: shell,
          home:  home,
          gecos: gecos)

        user.password = user1_password
        user
      end

      let(:uid) { 1000 }
      let(:gid) { 100 }
      let(:shell) { "/bin/zsh" }
      let(:home) { "/home/test1" }
      let(:gecos) { ["Test User1"] }

      let(:user1_password) { Y2Users::Password.new(config, "test1", value: "123456") }

      # User

      let(:user2) do
        user = Y2Users::User.new(config, "test2",
          uid:   1001,
          gid:   101,
          shell: "/bin/bash",
          home:  "/home/test2",
          gecos: ["Test User2"])

        user.password = user2_password
        user
      end

      let(:user2_password) { Y2Users::Password.new(config, "test2", value: "654321") }

      it "stores all users into UsersSimple module" do
        subject.write

        expect(Yast::UsersSimple.GetUsers.size).to eq(2)
      end

      it "stores the name of the users" do
        subject.write

        names = Yast::UsersSimple.GetUsers.map { |u| u["uid"] }

        expect(names).to contain_exactly("test1", "test2")
      end

      it "stores the uid of the users" do
        subject.write

        expect(user_simple("test1")["uidNumber"]).to eq("1000")
        expect(user_simple("test2")["uidNumber"]).to eq("1001")
      end

      it "stores the gid of the users" do
        subject.write

        expect(user_simple("test1")["gidNumber"]).to eq("100")
        expect(user_simple("test2")["gidNumber"]).to eq("101")
      end

      it "stores the shell of the users" do
        subject.write

        expect(user_simple("test1")["loginShell"]).to eq("/bin/zsh")
        expect(user_simple("test2")["loginShell"]).to eq("/bin/bash")
      end

      it "stores the home directory of the users" do
        subject.write

        expect(user_simple("test1")["homeDirectory"]).to eq("/home/test1")
        expect(user_simple("test2")["homeDirectory"]).to eq("/home/test2")
      end

      it "stores the full name of the users" do
        subject.write

        expect(user_simple("test1")["cn"]).to eq("Test User1")
        expect(user_simple("test2")["cn"]).to eq("Test User2")
      end

      it "stores the password of the users" do
        subject.write

        expect(user_simple("test1")["userPassword"]).to eq("123456")
        expect(user_simple("test2")["userPassword"]).to eq("654321")
      end

      include_examples "root"

      context "when a user has no uid" do
        let(:uid) { nil }

        it "does not store an user uid" do
          subject.write

          expect(user_simple("test1")["uidNumber"]).to be_nil
        end
      end

      context "when a user has no gid" do
        let(:gid) { nil }

        it "does not store an user gid" do
          subject.write

          expect(user_simple("test1")["gidNumber"]).to be_nil
        end
      end

      context "when a user has no shell" do
        let(:shell) { nil }

        it "does not store an user shell" do
          subject.write

          expect(user_simple("test1")["loginShell"]).to be_nil
        end
      end

      context "when a user has no home" do
        let(:home) { nil }

        it "does not store an user home" do
          subject.write

          expect(user_simple("test1")["homeDirectory"]).to be_nil
        end
      end

      context "when a user has no specific full name" do
        let(:gecos) { [] }

        it "stores the user name as full name" do
          subject.write

          expect(user_simple("test1")["cn"]).to eq("test1")
        end
      end

      context "when a user has no password" do
        let(:user1_password) { nil }

        it "does not store an user password" do
          subject.write

          expect(user_simple("test1")["userPassword"]).to be_nil
        end
      end
    end
  end
end
