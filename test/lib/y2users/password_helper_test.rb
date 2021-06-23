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

require "yast"
require "y2users/password_helper"
require "y2users/user"

class DummyDialog
  include Yast::I18n
  include Yast::UIShortcuts
  include Y2Users::PasswordHelper
end

describe Y2Users::PasswordHelper do
  subject { DummyDialog.new }

  describe "#valid_password_for?(user)" do
    let(:user) { Y2Users::User.new("dummy-user") }
    let(:issues_list) { Y2Issues::List.new(issues) }

    before do
      allow(Yast::Report).to receive(:Error)
      allow(Yast::Popup).to receive(:YesNo)
      allow(user).to receive(:password_issues).and_return(issues_list)
    end

    context "when there are no issues" do
      let(:issues) { [] }

      it "returns true" do
        expect(subject.valid_password_for?(user)).to eq(true)
      end
    end

    context "when there is any fatal issue" do
      let(:issues) { [Y2Issues::Issue.new("A fatal issue", severity: :error)] }

      it "reports an error" do
        expect(Yast::Report).to receive(:Error).with(/fatal issue/)

        subject.valid_password_for?(user)
      end

      it "returns false" do
        expect(subject.valid_password_for?(user)).to eq(false)
      end
    end

    context "if there are non-fatal issue" do
      let(:issues) { [Y2Issues::Issue.new("A non-fatal issue")] }
      let(:return_value) { true }

      before do
        allow(Yast::Popup).to receive(:YesNo).and_return(return_value)
      end

      it "does not report an error" do
        expect(Yast::Report).to_not receive(:Error)

        subject.valid_password_for?(user)
      end

      it "asks the user for confirmation" do
        expect(Yast::Popup).to receive(:YesNo).with(/A non-fatal issue.*Really use this password?/m)

        subject.valid_password_for?(user)
      end

      context "and the user wants to proceed anyway" do
        let(:return_value) { true }

        it "returns true" do
          expect(subject.valid_password_for?(user)).to eq(true)
        end
      end

      context "and the user decides to not proceed" do
        let(:return_value) { false }

        it "returns false" do
          expect(subject.valid_password_for?(user)).to eq(false)
        end
      end
    end
  end
end
