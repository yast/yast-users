#!/usr/bin/env rspec

require_relative "test_helper"
require "users/widgets"

def stub_widget_value(id, value)
  allow(Yast::UI).to receive(:QueryWidget).with(Id(id), :Value).and_return(value)
end

describe Users::PasswordWidget do
  let(:root_user) { Y2Users::User.new("root") }

  before do
    allow(root_user).to receive(:root?).and_return(true)
    allow(subject).to receive(:root_user).and_return(root_user)
    allow(subject).to receive(:user_to_validate).and_return(root_user)
  end

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

    it "reports error if password does not validate" do
      stub_widget_value(:pw1, "mimic_forbidden")
      stub_widget_value(:pw2, "mimic_forbidden")

      fatal_issue = Y2Issues::Issue.new("Invalid password", severity: :fatal)
      issues = Y2Issues::List.new([fatal_issue])

      allow(root_user).to receive(:password_issues).and_return(issues)

      expect(Yast::Report).to receive(:Error)
      expect(Yast::UI).to receive(:SetFocus).with(Id(:pw1))

      expect(subject.validate).to eq false
    end

    it "asks for confirmation if password validates with warnings" do
      stub_widget_value(:pw1, "a")
      stub_widget_value(:pw2, "a")

      warning_issue = Y2Issues::Issue.new("Not strong password")
      issues = Y2Issues::List.new([warning_issue])
      allow(root_user).to receive(:password_issues).and_return(issues)

      expect(Yast::UI).to receive(:SetFocus).with(Id(:pw1))
      expect(Yast::Popup).to receive(:YesNo).and_return(false)

      expect(subject.validate).to eq false
    end

    it "asks for confirmation only once for same password" do
      stub_widget_value(:pw1, "a")
      stub_widget_value(:pw2, "a")

      warning_issue = Y2Issues::Issue.new("Not strong password")
      issues = Y2Issues::List.new([warning_issue])
      allow(root_user).to receive(:password_issues).and_return(issues)

      expect(Yast::UI).to receive(:SetFocus).with(Id(:pw1))
      expect(Yast::Popup).to receive(:YesNo).and_return(true).once

      expect(subject.validate).to eq true
      expect(subject.validate).to eq true
    end

    it "is valid otherwise" do
      stub_widget_value(:pw1, "a")
      stub_widget_value(:pw2, "a")

      issues = Y2Issues::List.new
      allow(root_user).to receive(:password_issues).and_return(issues)

      expect(subject.validate).to eq true
    end
  end

  it "stores its value" do
    stub_widget_value(:pw1, "new cool password")

    expect(root_user).to receive(:password=) do |password|
      expect(password).to be_a(Y2Users::Password)
      expect(password.value.plain?).to eq true
      expect(password.value.content).to eq "new cool password"
    end

    subject.store
  end

  context "when the widget is allowed to be empty" do
    subject { described_class.new(allow_empty: true) }

    let(:root_user) { double(Y2Users::User) }

    before do
      allow(subject).to receive(:root_user).and_return(root_user)
    end

    it "does not validate the password" do
      stub_widget_value(:pw1, "")
      stub_widget_value(:pw2, "")

      expect(root_user).to_not receive(:password_issues)
      expect(subject.validate).to eq(true)
    end

    it "does not store the value if empty" do
      stub_widget_value(:pw1, "")
      stub_widget_value(:pw2, "")

      expect(root_user).to_not receive(:password=)
      subject.store
    end

    it "stores the value if not empty" do
      stub_widget_value(:pw1, "new cool password")
      stub_widget_value(:pw2, "new cool password")

      expect(root_user).to receive(:password=) do |password|
        expect(password).to be_a(Y2Users::Password)
        expect(password.value.plain?).to eq true
        expect(password.value.content).to eq "new cool password"
      end

      subject.store
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
