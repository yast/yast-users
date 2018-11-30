#! /usr/bin/env rspec
# Copyright (c) 2016 SUSE LLC.
#  All Rights Reserved.

#  This program is free software; you can redistribute it and/or
#  modify it under the terms of version 2 or 3 of the GNU General
#  Public License as published by the Free Software Foundation.

#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
#  GNU General Public License for more details.

#  You should have received a copy of the GNU General Public License
#  along with this program; if not, contact SUSE LLC.

#  To contact SUSE about this file by physical or electronic mail,
#  you may find current contact information at www.suse.com

require_relative "../../test_helper"
require "users/local_password"

describe Users::LocalPassword do
  before do
    # For testing purposes, password starting with "Bad" will generate errors
    allow(Yast::UsersSimple).to receive(:CheckPasswordUI) do |args|
      args["userPassword"].start_with?("Bad") ? ["Error"] : []
    end
    allow(subject.ca_validator).to receive(:enabled?).and_return ca_enabled
  end
  let(:ca_enabled) { true }

  describe "#valid?" do
    it "returns true if no errors were found" do
      allow(subject).to receive(:errors).and_return []
      expect(subject.valid?).to eq true
    end

    it "returns false if some error was found" do
      allow(subject).to receive(:errors).and_return ["error"]
      expect(subject.valid?).to eq false
    end
  end

  describe "#errors" do
    before do
      allow(Yast::UsersSimple).to receive(:LoadCracklib).and_return true
      allow(Yast::UsersSimple).to receive(:UnLoadCracklib)
    end

    it "disables cracklib if it couldn't be loaded" do
      allow(Yast::UsersSimple).to receive(:LoadCracklib).and_return false
      expect(Yast::UsersSimple).to receive(:UseCrackLib).with false
      Users::LocalPassword.new(username: "irrelevant").errors
    end

    context "when checking the root password" do
      subject { Users::LocalPassword.new(username: "root") }

      it "calls UsersSimple with the expected arguments" do
        expect(Yast::UsersSimple).to receive(:CheckPasswordUI)
          .with("uid" => "root", "userPassword" => "", "type" => "system")
        subject.errors
      end

      context "if CA check is enabled" do
        let(:ca_enabled) { true }

        it "returns two errors for a bad, short password" do
          subject.plain = "Bad"
          expect(subject.errors.size).to eq 2
        end

        it "returns one error for a bad, long password" do
          subject.plain = "BadButLong"
          expect(subject.errors.size).to eq 1
        end

        it "returns one error for a good, short password" do
          subject.plain = "Ok"
          expect(subject.errors.size).to eq 1
        end

        it "returns no errors for a good, long password" do
          subject.plain = "OkAndLong"
          expect(subject.errors.size).to eq 0
        end
      end

      context "if CA check is enabled" do
        let(:ca_enabled) { false }

        it "returns one error for a bad, short password" do
          subject.plain = "Bad"
          expect(subject.errors.size).to eq 1
        end

        it "returns one error for a bad, long password" do
          subject.plain = "BadButLong"
          expect(subject.errors.size).to eq 1
        end

        it "returns no errors for a good, short password" do
          subject.plain = "Ok"
          expect(subject.errors.size).to eq 0
        end

        it "returns no errors for a good, long password" do
          subject.plain = "OkAndLong"
          expect(subject.errors.size).to eq 0
        end
      end
    end

    context "when reusing a user password for root" do
      subject { Users::LocalPassword.new(username: "user", also_for_root: true) }

      it "calls UsersSimple with the expected arguments" do
        expect(Yast::UsersSimple).to receive(:CheckPasswordUI)
          .with("uid" => "user", "userPassword" => "", "type" => "local", "root" => true)
        subject.errors
      end

      context "if CA check is enabled" do
        let(:ca_enabled) { true }

        it "returns two errors for a bad, short password" do
          subject.plain = "Bad"
          expect(subject.errors.size).to eq 2
        end

        it "returns one error for a bad, long password" do
          subject.plain = "BadButLong"
          expect(subject.errors.size).to eq 1
        end

        it "returns one error for a good, short password" do
          subject.plain = "Ok"
          expect(subject.errors.size).to eq 1
        end

        it "returns no errors for a good, long password" do
          subject.plain = "OkAndLong"
          expect(subject.errors.size).to eq 0
        end
      end

      context "if CA check is enabled" do
        let(:ca_enabled) { false }

        it "returns one error for a bad, short password" do
          subject.plain = "Bad"
          expect(subject.errors.size).to eq 1
        end

        it "returns one error for a bad, long password" do
          subject.plain = "BadButLong"
          expect(subject.errors.size).to eq 1
        end

        it "returns no errors for a good, short password" do
          subject.plain = "Ok"
          expect(subject.errors.size).to eq 0
        end

        it "returns no errors for a good, long password" do
          subject.plain = "OkAndLong"
          expect(subject.errors.size).to eq 0
        end
      end
    end

    context "when checking a regular user password" do
      subject { Users::LocalPassword.new(username: "user", also_for_root: false) }

      it "calls UsersSimple with the expected arguments" do
        expect(Yast::UsersSimple).to receive(:CheckPasswordUI)
          .with("uid" => "user", "userPassword" => "", "type" => "local", "root" => false)
        subject.errors
      end

      context "if CA check is enabled" do
        let(:ca_enabled) { true }

        it "returns one error for a bad, short password" do
          subject.plain = "Bad"
          expect(subject.errors.size).to eq 1
        end

        it "returns one error for a bad, long password" do
          subject.plain = "BadButLong"
          expect(subject.errors.size).to eq 1
        end

        it "returns no errors for a good, short password" do
          subject.plain = "Ok"
          expect(subject.errors.size).to eq 0
        end

        it "returns no errors for a good, long password" do
          subject.plain = "OkAndLong"
          expect(subject.errors.size).to eq 0
        end
      end

      context "if CA check is enabled" do
        let(:ca_enabled) { false }

        it "returns one error for a bad, short password" do
          subject.plain = "Bad"
          expect(subject.errors.size).to eq 1
        end

        it "returns one error for a bad, long password" do
          subject.plain = "BadButLong"
          expect(subject.errors.size).to eq 1
        end

        it "returns no errors for a good, short password" do
          subject.plain = "Ok"
          expect(subject.errors.size).to eq 0
        end

        it "returns no errors for a good, long password" do
          subject.plain = "OkAndLong"
          expect(subject.errors.size).to eq 0
        end
      end
    end
  end
end
