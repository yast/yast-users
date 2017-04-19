#!/usr/bin/env rspec

require_relative "test_helper"
require "fileutils"
require "yaml"
require "users/clients/users_finish"

describe Yast::UsersFinishClient do
  Yast.import "WFM"
  Yast.import "UsersPasswd"

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
      let(:users_path) do
        p = FIXTURES_PATH.join("users.yml")
        puts "USERSPATH"
        puts "#{p}"
        puts "ENDUSERSPATH"
        p
      end
      let(:users) { YAML.load_file(users_path) }

      before { allow(Yast::Mode).to receive(:autoinst).and_return(autoinst) }

      around do |example|
        change_scr_root(FIXTURES_PATH.join("root")) { example.run }
        FileUtils.rm_rf(FIXTURES_PATH.join("root", "var"))
      end

      context "in autoinst mode" do
        let(:autoinst) { true }

        before do
          # Writing users involves executing commands (cp, chmod, etc.) and those
          # calls can't be mocked (Perl code).
          allow(Yast::Users).to receive(:Write).and_return("")
          puts "USERS"
          puts "#{users}"
          puts "ENDUSERS"
          ir = Yast::Users.Import(users)
	  puts "IMPORTRESULT #{ir}"
          puts "GETUSERS1"
          puts "#{Yast::Users.GetUsers("uid", "local")}"
          puts "ENDGETUSERS1"
        end

        it "add users specified in the profile" do
          subject.run

          puts "GETUSERS2"
          puts "#{Yast::Users.GetUsers("uid", "local")}"
          puts "ENDGETUSERS2"
          yast_user = Yast::Users.GetUsers("uid", "local").fetch("yast")
          expect(yast_user).to_not be_nil
        end

=begin
        it "updates root account" do
          subject.run

          root_user = Yast::Users.GetUsers("uid", "system").fetch("root")
          expect(root_user["userPassword"]).to_not be_empty
        end

        it "preserves system accounts passwords" do
          subject.run

          shadow = Yast::UsersPasswd.GetShadow("system")
          passwords = shadow.values.map { |u| u["userPassword"] }
          expect(passwords).to all(satisfy { |v| !v.empty? })
        end
=end
      end

      context "not in autoinst mode" do
        let(:autoinst) { false }

        before do
          allow(subject).to receive(:setup_all_users).and_return(user_added)
        end

        context "when a new user is added" do
          let(:user_added) { true }

          it "write root password and users" do
            # write root password
            expect(Yast::UsersSimple).to receive(:Write)
            # write users
            expect(Yast::Users).to receive(:Write)
            subject.run
          end
        end

        context "when no new user is added" do
          let(:user_added) { false }

          it "write root password" do
            # write root password
            expect(Yast::UsersSimple).to receive(:Write)
            # do not write users
            expect(Yast::Users).to_not receive(:Write)
            subject.run
          end
        end
      end
    end
  end
end
