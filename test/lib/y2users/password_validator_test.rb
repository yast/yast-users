#!/usr/bin/env rspec
#
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

require "y2users/user"
require "y2users/password"
require "y2users/password_validator"
require "users/local_password"

Yast.import "UsersSimple"

describe Y2Users::PasswordValidator do
  subject(:validator) { described_class.new(user) }

  let(:user) { Y2Users::User.new("test") }

  before do
    allow(user).to receive(:password).and_return(password)
  end

  describe "#issues" do
    context "when validating an encrypted password" do
      let(:password) { Y2Users::Password.create_encrypted("") }

      it "returns an empty issues list" do
        expect(validator.issues).to be_empty
      end
    end

    context "when validating a plain password" do
      before do
        allow(Yast::UsersSimple).to receive(:CheckPassword).and_return(fatal_issues)
        allow(::Users::LocalPassword).to receive(:new).and_return(local_password_validator)
      end

      let(:password) { Y2Users::Password.create_plain(password_content) }
      let(:password_content) { "s3cr3T" }
      let(:password_errors) { "" }
      let(:local_password_validator) do
        double(::Users::LocalPassword, valid?: false, errors: warning_issues)
      end
      let(:fatal_issues) { "" }
      let(:warning_issues) { [] }

      it "returns a list of Y2Issues" do
        expect(validator.issues).to be_a(Y2Issues::List)
      end

      context "when there are fatal issues" do
        let(:fatal_issues) { "Yast::UsersSimple password validations failed" }
        let(:warning_issues) { ["too short!"] }

        it "contains a fatal issue" do
          issues = validator.issues

          expect(issues).to_not be_empty
          expect(issues.fatal?).to eq(true)
        end

        it "does not proceed with further validations" do
          issues = validator.issues

          expect(issues.map(&:message)).to_not include(*warning_issues)
        end
      end

      context "when there are no fatal issues" do
        it "does not contains a fatal issue" do
          issues = validator.issues

          expect(issues.fatal?).to eq(false)
        end

        context "and no warnings" do
          it "returns an empty issues list" do
            expect(validator.issues).to be_empty
          end
        end

        context "but any warning" do
          let(:warning_issues) { ["too short!", "includes the username"] }

          it "contains warning issues" do
            issues = validator.issues

            expect(issues).to_not be_empty
            expect(issues.map(&:severity).uniq).to eq([:warn])
            expect(issues.map(&:message)).to include(*warning_issues)
          end
        end
      end
    end
  end
end
