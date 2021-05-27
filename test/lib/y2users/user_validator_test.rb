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
require "y2users/user_validator"

Yast.import "UsersSimple"

describe Y2Users::UserValidator do
  subject(:validator) { described_class.new(user) }

  let(:user) { Y2Users::User.new(username) }
  let(:username) { "test" }
  let(:full_name) { "Test user" }
  let(:password) { Y2Users::Password.create_plain("s3cr3tpwd") }
  let(:password_issue) { Y2Issues::Issue.new("an issue from password validation") }

  before do
    allow(user).to receive(:password).and_return(password)
    allow(user).to receive(:password_issues).and_return(Y2Issues::List.new([password_issue]))

    user.gecos = [full_name]
  end

  describe "#issues" do
    let(:issues) { subject.issues(skip: skipped_attrs) }
    let(:fatal_issues_messages) { issues.map.select(&:fatal?).map(&:message) }
    let(:skipped_attrs) { [] }

    context "when not skipping the name attribute validations" do
      context "and using an empty username" do
        let(:username) { "" }

        it "includes a fatal issue for not entered username" do
          expect(fatal_issues_messages).to include(/No username entered/)
        end
      end

      context "and using too short username" do
        # See Yast::UsersSimple$min_length_login
        let(:username) { "y" }

        it "includes a fatal issue for the username length" do
          expect(fatal_issues_messages).to include(/username must be between/)
        end
      end

      context "and using too long username" do
        # See Yast::UsersSimple$max_length_login
        let(:username) { "ANTeLSIverIDEbUrcHROlDpIOlUSEYHOb" }

        it "includes a fatal issue for the username length" do
          expect(fatal_issues_messages).to include(/username must be between/)
        end
      end

      context "and using a conflicting username" do
        # See Yast::UsersSimple$system_users
        let(:username) { "ldap" }

        it "includes a fatal issue for the conflictive username" do
          expect(fatal_issues_messages).to include(/There is a conflict/)
        end
      end
    end

    context "when skipping the name attribure validations" do
      let(:skipped_attrs) { [:name] }

      context "and using an empty username" do
        let(:username) { "" }

        it "does not include a fatal issue for not entered username" do
          expect(fatal_issues_messages).to_not include(/No username entered/)
        end
      end

      context "and using too short username" do
        # See Yast::UsersSimple$min_length_login
        let(:username) { "y" }

        it "does not include a fatal issue for the username length" do
          expect(fatal_issues_messages).to_not include(/username must be between/)
        end
      end

      context "and using too long username" do
        # See Yast::UsersSimple$max_length_login
        let(:username) { "ANTeLSIverIDEbUrcHROlDpIOlUSEYHOb" }

        it "does not include a fatal issue for the username length" do
          expect(fatal_issues_messages).to_not include(/username must be between/)
        end
      end

      context "and using a conflicting username" do
        # See Yast::UsersSimple$system_users
        let(:username) { "ldap" }

        it "does not include a fatal issue for the conflictive username" do
          expect(fatal_issues_messages).to_not include(/There is a conflict/)
        end
      end
    end

    context "when not skipping the full_name attribute validations" do
      context "and including a comma in the full_name" do
        let(:full_name) { "Test,user" }

        it "includes an issue about forbidden characters" do
          expect(fatal_issues_messages).to include(/full name cannot contain/)
        end
      end

      context "and including a colon in the full_name" do
        let(:full_name) { "Test:user" }

        it "includes an issue about forbidden characters" do
          expect(fatal_issues_messages).to include(/full name cannot contain/)
        end
      end
    end

    context "when skipping the full_name attribute validations" do
      let(:skipped_attrs) { [:full_name] }

      context "and including a comma in the full_name" do
        let(:full_name) { "Test,user" }

        it "does not include an issue about forbidden characters" do
          expect(fatal_issues_messages).to_not include(/full name cannot contain/)
        end
      end

      context "and including a colon in the full_name" do
        let(:full_name) { "Test:user" }

        it "does not include an issue about forbidden characters" do
          expect(fatal_issues_messages).to_not include(/full name cannot contain/)
        end
      end
    end

    context "when not skipping the password attribute validations" do
      context "and the user have an associated password" do
        it "checks password issues" do
          expect(user).to receive(:password_issues)

          subject.issues
        end

        it "includes found password issues (if any)" do
          expect(subject.issues).to include(password_issue)
        end
      end

      context "but the user does not have an associated password yet" do
        let(:password) { nil }

        it "does not check the password issues" do
          expect(user).to_not receive(:password_issues)

          subject.issues
        end

        it "does not includes found password issues (if any)" do
          expect(subject.issues).to_not include(password_issue)
        end
      end
    end

    context "when skipping the password attribute validations" do
      it "does not check the password issues" do
        expect(user).to_not receive(:password_issues)

        subject.issues(skip: [:password])
      end

      it "does not includes found password issues (if any)" do
        expect(subject.issues(skip: [:password])).to_not include(password_issue)
      end
    end
  end
end
