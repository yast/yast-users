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
require "y2users/password"
require "y2users/shadow_date"
require "date"

describe Y2Users::Password do
  describe ".create_plain" do
    it "creates a new password with a plain value" do
      password = described_class.create_plain("S3cr3T")

      expect(password).to be_a(Y2Users::Password)
      expect(password.value).to be_a(Y2Users::PasswordPlainValue)
      expect(password.value.content).to eq("S3cr3T")
    end
  end

  describe ".create_encrypted" do
    it "creates a new password with an encrypted value" do
      password = described_class.create_encrypted("$1$asf98as388xffx")

      expect(password).to be_a(Y2Users::Password)
      expect(password.value).to be_a(Y2Users::PasswordEncryptedValue)
      expect(password.value.content).to eq("$1$asf98as388xffx")
    end
  end

  describe "#copy" do
    subject { described_class.create_plain("S3cr3T") }

    before do
      subject.minimum_age = "10"
      subject.inactivity_period = "20"
    end

    it "generates a new password with the same values" do
      password = subject.copy

      expect(password).to be_a(Y2Users::Password)
      expect(password).to eq(subject)
    end

    it "generates a new password with an independent password value" do
      password = subject.copy

      password.value.content = "other"

      expect(password.value.content).to_not eq(subject.value.content)
    end

    it "generates a new password with an independent aging value" do
      subject.aging = Y2Users::PasswordAging.new(Date.new(2021, 1, 2))

      password = subject.copy
      password.aging.last_change = Date.new(2021, 1, 10)

      expect(password.aging).to_not eq(subject.aging)
    end

    it "generates a new password with an independent account expiration value" do
      subject.account_expiration = Y2Users::AccountExpiration.new(Date.new(2021, 1, 2))

      password = subject.copy
      password.account_expiration.date = Date.new(2021, 1, 10)

      expect(password.account_expiration).to_not eq(subject.account_expiration)
    end
  end

  describe "#==" do
    subject { described_class.create_plain("S3cr3T") }

    before do
      subject.aging = Y2Users::PasswordAging.new(Date.new(2021, 1, 2))
      subject.minimum_age = "10"
      subject.maximum_age = "20"
      subject.warning_period = "30"
      subject.inactivity_period = "40"
      subject.account_expiration = Y2Users::AccountExpiration.new(Date.new(2021, 1, 2))
    end

    let(:other) { subject.copy }

    context "when the given object is not a password" do
      let(:other) { "This is not a password" }

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end

    context "when the #value does not match" do
      before do
        other.value.content = "other"
      end

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end

    context "when the #aging does not match" do
      before do
        other.aging.last_change = Date.new(2021, 1, 10)
      end

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end

    context "when the #minimum_age does not match" do
      before do
        other.minimum_age = "11"
      end

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end

    context "when the #maximum_age does not match" do
      before do
        other.maximum_age = "21"
      end

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end

    context "when the #warning_period does not match" do
      before do
        other.warning_period = "31"
      end

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end

    context "when the #inactivity_period does not match" do
      before do
        other.inactivity_period = "41"
      end

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end

    context "when the #account_expiration does not match" do
      before do
        other.account_expiration.date = Date.new(2021, 1, 10)
      end

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end

    context "when all the attributes are equal" do
      it "returns true" do
        expect(subject == other).to eq(true)
      end
    end
  end
end

shared_examples "password value comparison" do
  describe "#==" do
    let(:other) { described_class.new(other_content) }

    context "when the #content matches" do
      let(:other_content) { subject.content }

      it "returns true" do
        expect(subject == other).to eq(true)
      end
    end

    context "when the #content does not match" do
      let(:other_content) { "other" }

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end

    context "when the given object is not a password value" do
      let(:other) { "This is not a password value" }

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end
  end
end

describe Y2Users::PasswordPlainValue do
  subject { described_class.new("S3cr3T") }

  describe "#plain?" do
    it "returns true" do
      expect(subject.plain?).to eq(true)
    end
  end

  describe "#encrypted?" do
    it "returns false" do
      expect(subject.encrypted?).to eq(false)
    end
  end

  include_examples "password value comparison"
end

describe Y2Users::PasswordEncryptedValue do
  subject { described_class.new(content) }

  let(:content) { "$1$xfa3555asf" }

  describe "#plain?" do
    it "returns false" do
      expect(subject.plain?).to eq(false)
    end
  end

  describe "#encrypted?" do
    it "returns true" do
      expect(subject.encrypted?).to eq(true)
    end
  end

  describe "#locked?" do
    context "when the content starts with '!$'" do
      let(:content) { "!$1$afeefadf" }

      it "returns true" do
        expect(subject.locked?).to eq(true)
      end
    end

    context "when the content does not start with '!$'" do
      let(:content) { "$1$afeefadf" }

      it "returns false" do
        expect(subject.locked?).to eq(false)
      end
    end
  end

  describe "#disabled?" do
    let(:content) { "*" }

    context "when the content is '*'" do
      it "returns true" do
        expect(subject.disabled?).to eq(true)
      end
    end

    context "when the content is '!'" do
      let(:content) { "!" }

      it "returns true" do
        expect(subject.disabled?).to eq(true)
      end
    end

    context "when the content is neither '*' nor '!'" do
      let(:content) { "!$1$a*feefadf" }

      it "returns false" do
        expect(subject.disabled?).to eq(false)
      end
    end
  end

  include_examples "password value comparison"
end

describe Y2Users::PasswordAging do
  subject { described_class.new(value) }

  describe ".new" do
    context "when an empty string is given" do
      let(:value) { "" }

      it "creates a disabled aging" do
        expect(subject.enabled?).to eq(false)
      end
    end

    context "when the '0' string is given" do
      let(:value) { "0" }

      it "creates an aging which forces to chage the password" do
        expect(subject.force_change?).to eq(true)
      end
    end

    context "when a shadow date is given" do
      let(:value) { "1234" }

      let(:shadow_date) { Y2Users::ShadowDate.new(value) }

      it "creates an aging with a date equivalent to the given shadow date" do
        expect(subject.last_change).to eq(shadow_date.to_date)
      end
    end

    context "when a date object is given" do
      let(:value) { Date.new(2021, 1, 2) }

      it "creates an aging with the given date" do
        expect(subject.last_change).to eq(value)
      end
    end
  end

  describe "#enabled?" do
    context "when the content is empty" do
      let(:value) { "" }

      it "returns false" do
        expect(subject.enabled?).to eq(false)
      end
    end

    context "when the content is not empty" do
      let(:value) { "1111" }

      it "returns true" do
        expect(subject.enabled?).to eq(true)
      end
    end
  end

  describe "#disable" do
    context "when the aging is already disabled" do
      let(:value) { "" }

      it "keeps it as disabled" do
        subject.disable

        expect(subject.enabled?).to eq(false)
      end
    end

    context "when the aging is enabled" do
      let(:value) { "1111" }

      it "sets it as disabled" do
        expect { subject.disable }.to change { subject.enabled? }.from(true).to(false)
      end
    end
  end

  describe "#force_change?" do
    context "when the content is 0" do
      let(:value) { "0" }

      it "returns true" do
        expect(subject.force_change?).to eq(true)
      end
    end

    context "when the content is not 0" do
      let(:value) { "1111" }

      it "returns false" do
        expect(subject.force_change?).to eq(false)
      end
    end
  end

  describe "#force_change" do
    context "when the aging is already set to force the password change" do
      let(:value) { "0" }

      it "keeps it set to force the password change" do
        subject.force_change

        expect(subject.force_change?).to eq(true)
      end
    end

    context "when the aging is not set to force the password change" do
      let(:value) { "1111" }

      it "sets it to force the password change" do
        expect { subject.force_change }.to change { subject.force_change? }.from(false).to(true)
      end
    end
  end

  describe "#last_change" do
    let(:value) { "1234" }

    it "returns the date of the last change" do
      date = Y2Users::ShadowDate.new(value).to_date

      expect(subject.last_change).to eq(date)
    end

    context "when the aging is disabled" do
      before do
        subject.disable
      end

      it "returns nil" do
        expect(subject.last_change).to be_nil
      end
    end

    context "when the aging is set to force the password change" do
      before do
        subject.force_change
      end

      it "returns nil" do
        expect(subject.last_change).to be_nil
      end
    end
  end

  describe "#last_change=" do
    let(:value) { "" }

    it "sets the given date as the last password change" do
      shadow_date = Y2Users::ShadowDate.new(Date.new(2021, 1, 2))

      subject.last_change = shadow_date.to_date

      expect(subject.last_change).to eq(shadow_date.to_date)
      expect(subject.to_s).to eq(shadow_date.to_s)
    end
  end
end

describe Y2Users::AccountExpiration do
  subject { described_class.new(value) }

  describe ".new" do
    context "when an empty string is given" do
      let(:value) { "" }

      it "creates an account expiration without expiration date" do
        expect(subject.date).to be_nil
      end
    end

    context "when a shadow date is given" do
      let(:value) { "1234" }

      let(:shadow_date) { Y2Users::ShadowDate.new(value) }

      it "creates an account expiration with a date equivalent to the given shadow date" do
        expect(subject.date).to eq(shadow_date.to_date)
      end
    end

    context "when a date object is given" do
      let(:value) { Date.new(2021, 1, 2) }

      it "creates an account expiration with the given date" do
        expect(subject.date).to eq(value)
      end
    end
  end

  describe "#expire?" do
    context "when there is no expiration date" do
      let(:value) { "" }

      it "returns false" do
        expect(subject.expire?).to eq(false)
      end
    end

    context "when there is an expiration date" do
      let(:value) { "1111" }

      it "returns true" do
        expect(subject.expire?).to eq(true)
      end
    end
  end

  describe "#disable" do
    context "when there is no expiration date" do
      let(:value) { "" }

      it "keeps it without expiration date" do
        subject.disable

        expect(subject.expire?).to eq(false)
      end
    end

    context "when there is an expiration date" do
      let(:value) { "1111" }

      it "removes the expiration date" do
        expect { subject.disable }.to change { subject.expire? }.from(true).to(false)
      end
    end
  end

  describe "#date" do
    context "when there is no expiration date" do
      let(:value) { "" }

      it "returns nil" do
        expect(subject.date).to be_nil
      end
    end

    context "when there is an expiration date" do
      let(:value) { Date.new(2021, 1, 2) }

      it "returns the date" do
        expect(subject.date).to eq(value)
      end
    end
  end
end
