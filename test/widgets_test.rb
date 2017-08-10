#!/usr/bin/env rspec

require_relative "test_helper"
require "users/widgets"

def stub_widget_value(id, value)
  allow(Yast::UI).to receive(:QueryWidget).with(Id(id), :Value).and_return(value)
end

describe Users::PasswordWidget do
  it "has help text" do
    expect(subject.help).to_not be_empty
  end

  it "has valid content" do
    expect(subject.contents).to be_a(Yast::Term)
  end

  context "initialization" do
    it "initializes password to current value" do
      pwd = "paranoic"
      allow(Yast::UsersSimple).to receive(:GetRootPassword).and_return(pwd)
      expect(Yast::UI).to receive(:ChangeWidget).with(Id(:pw1), :Value, pwd)
      expect(Yast::UI).to receive(:ChangeWidget).with(Id(:pw2), :Value, pwd)

      subject.init
    end

    it "sets focus to first widget if focus: parameter set to object" do
      expect(Yast::UI).to receive(:SetFocus).with(Id(:pw1))
      subject = described_class.new(focus: true)
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

    it "reports error if password contain forbidden characters" do
      stub_widget_value(:pw1, "mimic_forbidden")
      stub_widget_value(:pw2, "mimic_forbidden")

      expect(Yast::UsersSimple).to receive(:CheckPassword).with("mimic_forbidden", "local").
        and_return("Invalid password")
      expect(Yast::Report).to receive(:Error)
      expect(Yast::UI).to receive(:SetFocus).with(Id(:pw1))

      expect(subject.validate).to eq false
    end

    it "asks for confirmation if password is not strong enough" do
      stub_widget_value(:pw1, "a")
      stub_widget_value(:pw2, "a")

      allow(Yast::UsersSimple).to receive(:CheckPassword).and_return("")
      allow(Users::LocalPassword).to receive(:new).and_return(double(valid?: false, errors: ["E"]))

      expect(Yast::UI).to receive(:SetFocus).with(Id(:pw1))
      expect(Yast::Popup).to receive(:YesNo).and_return(false)

      expect(subject.validate).to eq false
    end

    it "asks for confirmation only once for same password" do
      stub_widget_value(:pw1, "a")
      stub_widget_value(:pw2, "a")

      allow(Yast::UsersSimple).to receive(:CheckPassword).and_return("")
      allow(Users::LocalPassword).to receive(:new).and_return(double(valid?: false, errors: ["E"]))

      expect(Yast::UI).to receive(:SetFocus).with(Id(:pw1))
      expect(Yast::Popup).to receive(:YesNo).and_return(true).once

      expect(subject.validate).to eq true
      expect(subject.validate).to eq true
    end

    it "is valid otherwise" do
      stub_widget_value(:pw1, "a")
      stub_widget_value(:pw2, "a")

      allow(Yast::UsersSimple).to receive(:CheckPassword).and_return("")
      allow(Users::LocalPassword).to receive(:new).and_return(double(valid?: true))

      expect(subject.validate).to eq true
    end
  end

  it "stores its value" do
    stub_widget_value(:pw1, "new cool password")

    expect(Yast::UsersSimple).to receive(:SetRootPassword).with("new cool password")

    subject.store
  end
end
