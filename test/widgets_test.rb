#!/usr/bin/env rspec

require_relative "test_helper"
require "users/widgets"

def stub_widget_value(id, value)
  allow(Yast::UI).to receive(:QueryWidget).with(Id(id), :Value).and_return(value)
end

describe Users::PasswordWidget do
  subject { described_class.new(root_user) }

  let(:root_user) { Y2Users::User.new("root") }

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

  describe "#store" do
    # NOTE: testing only examples that make sense. I.e., those that happens when the widget
    # validates successfully, required condition to dispatch the #store method.
    let(:password) { "new cool password" }

    before do
      stub_widget_value(:pw1, password)
      stub_widget_value(:pw2, password)
    end

    it "writes chosen and validated password to the root user" do
      subject.validate
      subject.store

      expect(root_user.password).to be_a(Y2Users::Password)
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
