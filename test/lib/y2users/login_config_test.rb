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

require_relative "test_helper"
require "y2users"

describe Y2Users::LoginConfig do
  subject { described_class.new }

  describe "#new" do
    it "creates a login config withouth a user for autologin" do
      expect(subject.autologin?).to eq(false)
    end

    it "creates a login config withouth passwordless" do
      expect(subject.passwordless?).to eq(false)
    end
  end

  describe "#autologin?" do
    before do
      subject.autologin_user = user
    end

    context "when there is no user for autologin" do
      let(:user) { nil }

      it "returns false" do
        expect(subject.autologin?).to eq(false)
      end
    end

    context "when there is a user for autologin" do
      let(:user) { Y2Users::User.new("test") }

      it "returns true" do
        expect(subject.autologin?).to eq(true)
      end
    end
  end

  describe "#passwordless?" do
    before do
      subject.passwordless = passwordless
    end

    context "when the login is not configured for passwordless login" do
      let(:passwordless) { false }

      it "returns false" do
        expect(subject.passwordless?).to eq(false)
      end
    end

    context "when the login is configured for passwordless login" do
      let(:passwordless) { true }

      it "returns true" do
        expect(subject.passwordless?).to eq(true)
      end
    end
  end

  describe "#copy_to" do
    before do
      subject.autologin_user = autologin_user
      subject.passwordless = passwordless
    end

    let(:autologin_user) { nil }

    let(:passwordless) { false }

    let(:config) { Y2Users::Config.new }

    context "when the given config has already a login config" do
      before do
        config.login = Y2Users::LoginConfig.new
      end

      let(:passwordless) { true }

      it "replaces the current login config with a new login config" do
        login_config = config.login

        subject.copy_to(config)

        expect(config.login).to be_a(Y2Users::LoginConfig)
        expect(config.login).to_not eq(login_config)
        expect(config.login).to_not eq(subject)
      end

      it "copies the passwordless value into the new login config" do
        subject.copy_to(config)

        expect(config.login.passwordless?).to eq(true)
      end

      context "when the login config has no autologin user" do
        let(:autologin_user) { nil }

        it "does not copy an autologin user into the new login config" do
          subject.copy_to(config)

          expect(config.login.autologin?).to eq(false)
        end
      end

      context "when the login config has an autologin user" do
        let(:autologin_user) { Y2Users::User.new("test") }

        before do
          config.attach(Y2Users::User.new(username))
        end

        context "and the target config has no a user with the same name" do
          let(:username) { "other" }

          it "does not copy an autologin user into the new login config" do
            subject.copy_to(config)

            expect(config.login.autologin?).to eq(false)
          end
        end

        context "and the target config has a user with the same name" do
          let(:username) { "test" }

          it "assigns that user to the new login config" do
            subject.copy_to(config)

            expect(config.login.autologin?).to eq(true)
            expect(config.login.autologin_user.name).to eq("test")
          end
        end
      end
    end
  end
end
