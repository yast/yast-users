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
require "date"
require "y2users/configuration"
require "y2users/user"
require "y2users/password"
require "y2users/linux/writer"

describe Y2Users::Linux::Writer do
  subject(:writer) { described_class.new(configuration) }

  describe "#write" do
    let(:configuration) { Y2Users::Configuration.new(:test) }
    let(:user) { Y2Users::User.new(configuration, username, **user_attrs) }
    let(:password) do
      pw_options = { value: pwd_value, account_expiration: expiration_date }

      Y2Users::Password.new(configuration, username, pw_options)
    end

    let(:username) { "testuser" }
    let(:pwd_value) { "$6$3HkB4uLKri75$Qg6Pp" }
    let(:expiration_date) { nil }

    RSpec.shared_examples "setting expiration date" do
      context "without an expiration date" do
        it "does not include the --expiredate option" do
          expect(Yast::Execute).to receive(:on_target!) do |*args|
            expect(args).to_not include("--expiredate")
          end

          writer.write
        end
      end

      context "with an expiration date" do
        let(:expiration_date) { Date.today }

        it "includes the --expiredate option" do
          expect(Yast::Execute).to receive(:on_target!) do |*args|
            expect(args).to include("--expiredate")
            expect(args).to include(expiration_date.to_s)
          end

          writer.write
        end
      end
    end

    RSpec.shared_examples "setting password" do
      context "when the user has a password" do
        it "executes chpasswd for setting it" do
          expect(Yast::Execute).to receive(:on_target!)
            .with(/chpasswd/, "-e", stdin: "#{username}:#{pwd_value}", recorder: anything)

          writer.write
        end
      end

      context "when the user has not a password" do
        let(:pwd_value) { nil }

        it "does not execute chpasswd" do
          expect(Yast::Execute).to_not receive(:on_target!).with(/chpasswd/, any_args)

          writer.write
        end
      end
    end

    before do
      configuration.users << user
      configuration.passwords << password

      allow(Yast::Execute).to receive(:on_target!)
    end

    context "for a user with all the attributes" do
      let(:user_attrs) do
        {
          uid: 1001, gid: 2001, shell: "/bin/y2shell", home: "/home/y2test",
          gecos: ["First line of", "GECOS"]
        }
      end

      include_examples "setting expiration date"
      include_examples "setting password"

      it "executes useradd with all the parameters" do
        expect(Yast::Execute).to receive(:on_target!) do |*args|
          expect(args.first).to include "useradd"
          expect(args.last).to eq username
          expect(args).to include("--uid", "--gid", "--shell", "--home-dir")
        end

        writer.write
      end
    end

    context "for a user with no optional attributes specified" do
      let(:user_attrs) { {} }

      include_examples "setting expiration date"
      include_examples "setting password"

      it "executes useradd with no extra arguments" do
        expect(Yast::Execute).to receive(:on_target!).with(/useradd/, username)

        writer.write
      end
    end
  end
end
