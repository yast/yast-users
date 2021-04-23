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

  let(:config) { Y2Users::Configuration.new(:test) }

  def user_simple(name)
    Yast::UsersSimple.GetUsers.find { |u| u["uid"] == name }
  end

  describe "#write" do
    context "when the users config does not contain users" do
      before do
        config.users = []
      end

      it "does not store users into UsersSimple module" do
        subject.write

        expect(Yast::UsersSimple.GetUsers).to be_empty
      end
    end

    context "when the users config contains users" do
      before do
        config.users = [root, user]
        config.passwords = [root_password, user_password]
      end

      let(:root) { Y2Users::User.new(config, "root", **root_attrs) }

      let(:root_attrs) do
        {
          uid:   0,
          gid:   0,
          shell: "/bin/bash",
          home:  "/root",
          gecos: ["Root User"]
        }
      end

      let(:root_password) { Y2Users::Password.new(config, "root", value: "S3cr3T") }

      let(:user) { Y2Users::User.new(config, "test", **user_attrs) }

      let(:user_attrs) do
        {
          uid:   uid,
          gid:   gid,
          shell: shell,
          home:  home,
          gecos: gecos
        }
      end

      let(:uid) { 1000 }
      let(:gid) { 100 }
      let(:shell) { "/bin/zsh" }
      let(:home) { "/home/test" }
      let(:gecos) { ["Test User"] }

      let(:user_password) { Y2Users::Password.new(config, "test", value: "123456") }

      it "stores all users into UsersSimple module" do
        subject.write

        expect(Yast::UsersSimple.GetUsers.size).to eq(2)
      end

      it "stores the name of the users" do
        subject.write

        names = Yast::UsersSimple.GetUsers.map { |u| u["uid"] }

        expect(names).to contain_exactly("root", "test")
      end

      it "stores the uid of the users" do
        subject.write

        expect(user_simple("root")["uidNumber"]).to eq("0")
        expect(user_simple("test")["uidNumber"]).to eq("1000")
      end

      it "stores the gid of the users" do
        subject.write

        expect(user_simple("root")["gidNumber"]).to eq("0")
        expect(user_simple("test")["gidNumber"]).to eq("100")
      end

      it "stores the shell of the users" do
        subject.write

        expect(user_simple("root")["loginShell"]).to eq("/bin/bash")
        expect(user_simple("test")["loginShell"]).to eq("/bin/zsh")
      end

      it "stores the home directory of the users" do
        subject.write

        expect(user_simple("root")["homeDirectory"]).to eq("/root")
        expect(user_simple("test")["homeDirectory"]).to eq("/home/test")
      end

      it "stores the full name of the users" do
        subject.write

        expect(user_simple("root")["cn"]).to eq("Root User")
        expect(user_simple("test")["cn"]).to eq("Test User")
      end

      it "stores the password of the users" do
        subject.write

        expect(user_simple("root")["userPassword"]).to eq("S3cr3T")
        expect(user_simple("test")["userPassword"]).to eq("123456")
      end

      context "when a user has no uid" do
        let(:uid) { nil }

        it "does not store an user uid" do
          subject.write

          expect(user_simple("test")["uidNumber"]).to be_nil
        end
      end

      context "when a user has no gid" do
        let(:gid) { nil }

        it "does not store an user gid" do
          subject.write

          expect(user_simple("test")["gidNumber"]).to be_nil
        end
      end

      context "when a user has no shell" do
        let(:shell) { nil }

        it "does not store an user shell" do
          subject.write

          expect(user_simple("test")["loginShell"]).to be_nil
        end
      end

      context "when a user has no home" do
        let(:home) { nil }

        it "does not store an user home" do
          subject.write

          expect(user_simple("test")["homeDirectory"]).to be_nil
        end
      end

      context "when a user has no specific full name" do
        let(:gecos) { [] }

        it "stores the user name as full name" do
          subject.write

          expect(user_simple("test")["cn"]).to eq("test")
        end
      end

      context "when a user has no password" do
        let(:user_password) { Y2Users::Password.new(config, "test", value: nil) }

        it "does not store an user password" do
          subject.write

          expect(user_simple("test")["userPassword"]).to be_nil
        end
      end
    end
  end
end
