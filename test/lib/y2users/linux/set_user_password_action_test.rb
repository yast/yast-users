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

require "y2users/linux/set_user_password_action"
require "y2users/user"
require "y2users/password"

describe Y2Users::Linux::SetUserPasswordAction do
  subject { described_class.new(user) }

  let(:user) do
    Y2Users::User.new("test").tap do |user|
      user.password = password
    end
  end

  let(:password) do
    Y2Users::Password.new(value).tap do |password|
      password.aging = aging
      password.minimum_age = minimum_age
      password.maximum_age = maximum_age
      password.warning_period = warning_period
      password.inactivity_period = inactivity_period
      password.account_expiration = account_expiration
    end
  end

  let(:value) { Y2Users::PasswordPlainValue.new("s3cr3t") }

  let(:aging) { nil }

  let(:minimum_age) { nil }

  let(:maximum_age) { nil }

  let(:warning_period) { nil }

  let(:inactivity_period) { nil }

  let(:account_expiration) { nil }

  describe "#perform" do
    before do
      allow(Yast::Execute).to receive(:on_target!)
    end

    it "set the password and then set the attributes" do
      password.maximum_age = "10"

      expect(Yast::Execute).to receive(:on_target!).with(/chpasswd/, any_args).ordered
      expect(Yast::Execute).to receive(:on_target!).with(/chage/, any_args).ordered

      subject.perform
    end

    # If we would have used the --password argument of useradd, the encrypted password would
    # have been visible in the list of system processes (since it's part of the command)
    it "executes chpasswd without leaking the password to the list of processes" do
      expect(Yast::Execute).to receive(:on_target!).with(/chpasswd/, any_args) do |*args|
        leak_arg = args.find { |arg| arg.include?(password.value.content) }
        expect(leak_arg).to be_nil
      end

      subject.perform
    end

    context "when the password is not encrypted" do
      it "executes chpasswd without -e option" do
        expect(Yast::Execute).to receive(:on_target!).with(/chpasswd/, any_args) do |*args|
          expect(args).to_not include("-e")
        end

        subject.perform
      end
    end

    context "when the password is encrypted" do
      let(:value) { Y2Users::PasswordEncryptedValue.new("$12343dfa") }

      it "executes chpasswd with -e option" do
        expect(Yast::Execute).to receive(:on_target!).with(/chpasswd/, any_args) do |*args|
          expect(args).to include("-e")
        end

        subject.perform
      end
    end

    context "if the password has minimum age" do
      let(:minimum_age) { "10" }

      it "executes chage with --mindays option" do
        expect(Yast::Execute).to receive(:on_target!).with(/chage/, "--mindays", "10", "test")

        subject.perform
      end
    end

    context "if the password has no minimum age" do
      let(:minimum_age) { nil }
      let(:maximum_age) { "10" }

      it "executes chage without --mindays option" do
        expect(Yast::Execute).to receive(:on_target!).with(/chage/, any_args) do |*args|
          expect(args).to_not include("--mindays")
        end

        subject.perform
      end
    end

    context "if the password has maximum age" do
      let(:maximum_age) { "10" }

      it "executes chage with --maxdays option" do
        expect(Yast::Execute).to receive(:on_target!).with(/chage/, "--maxdays", "10", "test")

        subject.perform
      end
    end

    context "if the password has no maximum age" do
      let(:minimum_age) { "10" }
      let(:maximum_age) { nil }

      it "executes chage without --maxdays option" do
        expect(Yast::Execute).to receive(:on_target!).with(/chage/, any_args) do |*args|
          expect(args).to_not include("--maxdays")
        end

        subject.perform
      end
    end

    context "if the password has warning period" do
      let(:warning_period) { "10" }

      it "executes chage with --warndays option" do
        expect(Yast::Execute).to receive(:on_target!).with(/chage/, "--warndays", "10", "test")

        subject.perform
      end
    end

    context "if the password has no warning period" do
      let(:minimum_age) { "10" }
      let(:warning_period) { nil }

      it "executes chage without --warndays option" do
        expect(Yast::Execute).to receive(:on_target!).with(/chage/, any_args) do |*args|
          expect(args).to_not include("--warndays")
        end

        subject.perform
      end
    end

    context "if the password has inactivity period" do
      let(:inactivity_period) { "10" }

      it "executes chage with --inactive option" do
        expect(Yast::Execute).to receive(:on_target!).with(/chage/, "--inactive", "10", "test")

        subject.perform
      end
    end

    context "if the password has no inactivity period" do
      let(:minimum_age) { "10" }
      let(:inactivity_period) { nil }

      it "executes chage without --inactive option" do
        expect(Yast::Execute).to receive(:on_target!).with(/chage/, any_args) do |*args|
          expect(args).to_not include("--inactive")
        end

        subject.perform
      end
    end

    context "if the password has account expiration" do
      let(:account_expiration) do
        Y2Users::AccountExpiration.new.tap do |exp|
          exp.date = Date.new(2021, 8, 12)
        end
      end

      let(:shadow_date) { Y2Users::ShadowDate.new(account_expiration.date).to_s }

      it "executes chage with --expiredate option" do
        expect(Yast::Execute).to receive(:on_target!)
          .with(/chage/, "--expiredate", shadow_date, "test")

        subject.perform
      end
    end

    context "if the password has no account expiration" do
      let(:minimum_age) { "10" }
      let(:account_expiration) { nil }

      it "executes chage without --expiredate option" do
        expect(Yast::Execute).to receive(:on_target!).with(/chage/, any_args) do |*args|
          expect(args).to_not include("--expiredate")
        end

        subject.perform
      end
    end

    context "if the password has aging" do
      let(:aging) do
        Y2Users::PasswordAging.new.tap do |aging|
          aging.last_change = Date.new(2021, 8, 12)
        end
      end

      let(:shadow_date) { Y2Users::ShadowDate.new(aging.last_change).to_s }

      it "executes chage with --lastday option" do
        expect(Yast::Execute).to receive(:on_target!)
          .with(/chage/, "--lastday", shadow_date, "test")

        subject.perform
      end
    end

    context "if the password has no aging" do
      let(:minimum_age) { "10" }
      let(:aging) { nil }

      it "executes chage without --lastday option" do
        expect(Yast::Execute).to receive(:on_target!).with(/chage/, any_args) do |*args|
          expect(args).to_not include("--lastday")
        end

        subject.perform
      end
    end

    it "returns result without success and with issues if chpasswd failed" do
      expect(Yast::Execute).to receive(:on_target!).with(/chpasswd/, any_args)
        .and_raise(Cheetah::ExecutionFailed.new(nil, double(exitstatus: 1), nil, nil))

      result = subject.perform
      expect(result.success?).to eq false
      expect(result.issues).to_not be_empty
    end

    it "returns result without success and with issues if chage failed" do
      password.minimum_age = 5

      expect(Yast::Execute).to receive(:on_target!).with(/chage/, any_args)
        .and_raise(Cheetah::ExecutionFailed.new(nil, double(exitstatus: 1), nil, nil))

      result = subject.perform
      expect(result.success?).to eq false
      expect(result.issues).to_not be_empty
    end

  end
end
