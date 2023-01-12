#!/usr/bin/env rspec

# Copyright (c) [2021-2023] SUSE LLC
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

require "y2users/user"
require "y2users/linux/delete_user_action"
require "y2users/user_commit_config"

describe Y2Users::Linux::DeleteUserAction do
  subject(:action) { described_class.new(user, commit_config) }
  let(:user) { Y2Users::User.new("test") }
  let(:commit_config) { nil }

  before do
    allow(Yast::Execute).to receive(:on_target!)
  end

  describe "#perform" do
    it "deletes user with userdel" do
      expect(Yast::Execute).to receive(:on_target!) do |cmd, *_args|
        expect(cmd).to eq "/usr/sbin/userdel"
      end

      action.perform
    end

    it "passes user name as last parameter" do
      expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
        expect(args.last).to eq "test"
      end

      action.perform
    end

    context "commit config contain remove_home" do
      let(:commit_config) { Y2Users::UserCommitConfig.new.tap { |c| c.remove_home = true } }

      it "passes --remove parameter" do
        expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
          expect(args).to include "--remove"
        end

        action.perform
      end
    end

    context "when the command for deleting the user fails" do
      before do
        allow(Yast::Execute).to receive(:on_target!)
          .and_raise(Cheetah::ExecutionFailed.new(nil, double(exitstatus: exit_status), nil, nil))
      end

      context "and error is because the user is logged in" do
        let(:exit_status) { 8 }

        it "returns a failed result with issue for logged in user" do
          result = action.perform

          expect(result.success?).to eq(false)
          expect(result.issues.first.message).to match(/is currently logged in/)
        end
      end

      context "and error is because some files cannot be deleted" do
        let(:exit_status) { 12 }

        it "returns a failed result with issue for files that cannot deleted" do
          result = action.perform

          expect(result.success?).to eq(false)
          expect(result.issues.first.message).to match(/home or mail spool/)
        end
      end

      context "and error is because other reason" do
        let(:exit_status) { 1 }

        it "returns a failed result with issue for deleting user" do
          result = action.perform

          expect(result.success?).to eq(false)
          expect(result.issues.first.message).to match(/cannot be deleted/)
        end
      end
    end
  end
end
