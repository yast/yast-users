#!/usr/bin/env rspec

# Copyright (c) [2016-2021] SUSE LLC
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
require "users/widgets"
require "y2users"

def stub_widget_value(id, value)
  allow(Yast::UI).to receive(:QueryWidget).with(Id(id), :Value).and_return(value)
end

describe Users::PasswordWidget do
  subject { described_class.new(root_user) }

  let(:root_user) { Y2Users::User.create_root }

  it "has help text" do
    expect(subject.help).to_not be_empty
  end

  it "has valid content" do
    expect(subject.contents).to be_a(Yast::Term)
  end

  context "initialization" do
    let(:password) { Y2Users::Password.create_plain(pwd) }
    let(:pwd) { "paranoic" }

    before do
      allow(root_user).to receive(:password).and_return(password)
    end

    it "initializes password to current value" do
      expect(Yast::UI).to receive(:ChangeWidget).with(Id(:pw1), :Value, pwd)
      expect(Yast::UI).to receive(:ChangeWidget).with(Id(:pw2), :Value, pwd)

      subject.init
    end

    it "sets focus to first widget if focus: parameter set to object" do
      subject = described_class.new(root_user, focus: true)
      expect(Yast::UI).to receive(:SetFocus).with(Id(:pw1))
      subject.init
    end

    it "does not modify focus without focus: parameter" do
      expect(Yast::UI).to_not receive(:SetFocus).with(Id(:pw1))
      subject.init
    end
  end

  context "validation" do
    it "reports error if password is empty" do
      stub_widget_value(:pw1, "")
      stub_widget_value(:pw2, "")

      expect(Yast::Popup).to receive(:Error)
      expect(Yast::UI).to receive(:SetFocus).with(Id(:pw1))

      expect(subject.validate).to eq false
    end

    it "reports error if passwords do not match" do
      stub_widget_value(:pw1, "a")
      stub_widget_value(:pw2, "b")

      expect(Yast::Popup).to receive(:Message)
      expect(Yast::UI).to receive(:SetFocus).with(Id(:pw2))

      expect(subject.validate).to eq false
    end

    it "reports error if password does not validate" do
      stub_widget_value(:pw1, "mimic·forbidden")
      stub_widget_value(:pw2, "mimic·forbidden")

      expect(Yast::Report).to receive(:Error)
      expect(Yast::UI).to receive(:SetFocus).with(Id(:pw1))

      expect(subject.validate).to eq false
    end

    it "asks for confirmation if password validates with warnings" do
      stub_widget_value(:pw1, "a")
      stub_widget_value(:pw2, "a")

      expect(Yast::UI).to receive(:SetFocus).with(Id(:pw1))
      expect(Yast::Popup).to receive(:YesNo).and_return(false)

      expect(subject.validate).to eq false
    end

    it "asks for confirmation only once for same password" do
      stub_widget_value(:pw1, "a")
      stub_widget_value(:pw2, "a")

      expect(Yast::UI).to receive(:SetFocus).with(Id(:pw1))
      expect(Yast::Popup).to receive(:YesNo).and_return(true).once

      expect(subject.validate).to eq true
      expect(subject.validate).to eq true
    end

    it "is valid otherwise" do
      stub_widget_value(:pw1, "s3cr3t")
      stub_widget_value(:pw2, "s3cr3t")

      expect(subject.validate).to eq true
    end

    context "when the widget is allowed to be empty" do
      subject { described_class.new(root_user, allow_empty: true) }

      it "does not validate the password" do
        stub_widget_value(:pw1, "")
        stub_widget_value(:pw2, "")

        expect(Y2Users::Password).to_not receive(:create_plain)
        expect(subject.validate).to eq(true)
      end
    end
  end

  describe "#empty?" do
    let(:pw1) { "" }
    let(:pw2) { "" }

    before do
      stub_widget_value(:pw1, pw1)
      stub_widget_value(:pw2, pw2)
    end

    context "when no password has been introduced" do
      it "returns true" do
        expect(subject.empty?).to eq(true)
      end
    end

    context "when a password was introduced in the password field" do
      let(:pw1) { "secret" }

      it "returns false" do
        expect(subject.empty?).to eq(false)
      end
    end

    context "when a password was introduced in the confirmation field" do
      let(:pw2) { "secret" }

      it "returns false" do
        expect(subject.empty?).to eq(false)
      end
    end
  end
end
