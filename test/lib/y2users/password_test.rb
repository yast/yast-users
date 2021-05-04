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

  describe "#clone" do
    subject { described_class.create_plain("S3cr3T") }

    before do
      subject.minimum_age = 10
      subject.inactivity_period = 20
    end

    it "generates a new password with the same values" do
      password = subject.clone

      expect(password).to be_a(Y2Users::Password)
      expect(password).to eq(subject)
    end

    it "generates a new password with an independent password value" do
      password = subject.clone

      password.value.content = "other"

      expect(password.value.content).to_not eq(subject.value.content)
    end
  end

  describe "#==" do
    subject { described_class.create_plain("S3cr3T") }

    before do
      subject.last_change = Date.today
      subject.minimum_age = 10
      subject.maximum_age = 20
      subject.warning_period = 30
      subject.inactivity_period = 40
      subject.account_expiration = Date.today + 100
    end

    let(:other) { subject.clone }

    context "when all the attributes are equal" do
      it "returns true" do
        expect(subject == other).to eq(true)
      end
    end

    context "when the #last_change does not match" do
      before do
        other.last_change = Date.today + 10
      end

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end

    context "when the #minimum_age does not match" do
      before do
        other.minimum_age = 11
      end

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end

    context "when the #maximum_age does not match" do
      before do
        other.maximum_age = 21
      end

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end

    context "when the #warning_period does not match" do
      before do
        other.warning_period = 31
      end

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end

    context "when the #inactivity_period does not match" do
      before do
        other.inactivity_period = 41
      end

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

  describe "#==" do
    let(:other) { described_class.new(content) }

    context "when the #content matches" do
      let(:content) { "S3cr3T" }

      it "returns true" do
        expect(subject == other).to eq(true)
      end
    end

    context "when the #content does not match" do
      let(:content) { "other" }

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end
  end
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
end
