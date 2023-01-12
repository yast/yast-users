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

require "date"
require "y2users/user"
require "y2users/linux/create_user_action"

describe Y2Users::Linux::CreateUserAction do
  subject(:action) { described_class.new(user) }
  let(:user) { Y2Users::User.new("test") }

  before do
    allow(Yast::Execute).to receive(:on_target!)
  end

  describe "#perform" do
    it "creates user with useradd" do
      expect(Yast::Execute).to receive(:on_target!) do |cmd, *_args|
        expect(cmd).to eq "/usr/sbin/useradd"
      end

      action.perform
    end

    it "passes --uid parameter" do
      user.uid = "1000"

      expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
        expect(args).to include "--uid"
        expect(args).to include "1000"
      end

      action.perform
    end

    it "passes --gid parameter" do
      user.gid = "100"

      expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
        expect(args).to include "--gid"
        expect(args).to include "100"
      end

      action.perform
    end

    it "passes --shell parameter" do
      user.shell = "bash"

      expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
        expect(args).to include "--shell"
        expect(args).to include "bash"
      end

      action.perform
    end

    it "passes --comment parameter" do
      user.gecos = ["full name"]

      expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
        expect(args).to include "--comment"
        expect(args).to include "full name"
      end

      action.perform
    end

    it "passes --groups parameter" do
      allow(user).to receive(:secondary_groups_name).and_return(["test", "users"])

      expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
        expect(args).to include "--groups"
        expect(args).to include "test,users"
      end

      action.perform
    end

    it "passes --system parameter for system users" do
      user.system = true

      expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
        expect(args).to include "--system"
      end

      action.perform
    end

    it "passes --non-unique if uid is defined" do
      user.uid = "1000"

      expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
        expect(args).to include "--non-unique"
      end

      action.perform
    end

    it "passes user name as final parameter" do
      expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
        expect(args.last).to eq "test"
      end

      action.perform
    end

    it "returns result without success and with issues if cmd failed" do
      allow(Yast::Execute).to receive(:on_target!)
        .and_raise(Cheetah::ExecutionFailed.new(nil, double(exitstatus: 1), nil, nil))

      result = action.perform
      expect(result.success?).to eq false
      expect(result.issues).to_not be_empty
    end

    shared_examples "home options" do
      it "passes --btrfs-subvolume-home parameter if btrfs home configured" do
        user.home.btrfs_subvol = true

        expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
          expect(args).to include "--btrfs-subvolume-home"
        end

        action.perform
      end

      it "overwrites home mode parameter if home permission specified" do
        user.home.permissions = "0533"

        expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
          expect(args).to include "--key"
          expect(args).to include "HOME_MODE=0533"
        end

        action.perform
      end
    end

    shared_examples "home creation failed" do
      it "retries to create user if home creation failed" do
        expect(Yast::Execute).to receive(:on_target!).twice do |_cmd, *args|
          if !args.include?("--no-create-home")
            raise Cheetah::ExecutionFailed.new([], double(exitstatus: 12), "", "")
          end
        end

        action.perform
      end
    end

    context "for a system user" do
      before do
        user.system = true
      end

      context "if the home path is known" do
        before do
          user.home.path = "/home/test"
        end

        it "passes --create-home parameter" do
          expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
            expect(args).to include("--create-home")
          end

          action.perform
        end

        it "passes --home-dir parameter" do
          user.home.path = "/home/test"

          expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
            expect(args).to include("--home-dir")
            expect(args).to include("/home/test")
          end

          action.perform
        end

        include_examples "home options"

        include_examples "home creation failed"
      end

      context "if the home path is unknown" do
        before do
          user.home.path = ""
        end

        it "does not pass --create-home parameter" do
          expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
            expect(args).to_not include("--create-home")
          end

          action.perform
        end

        it "does not pass --home-dir parameter" do
          expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
            expect(args).to_not include("--home-dir")
          end

          action.perform
        end
      end
    end

    context "for a local user" do
      it "passes --create-home parameter" do
        expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
          expect(args).to include("--create-home")
          expect(args).to_not include("--home-dir")
          expect(args).to_not include("--btrfs-subvolume-home")
          expect(args).to_not include("--key")
        end

        action.perform
      end

      it "passes --home-dir parameter if the home path is known" do
        user.home.path = "/home/test"

        expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
          expect(args).to include("--home-dir")
          expect(args).to include("/home/test")
        end

        action.perform
      end

      include_examples "home options"

      include_examples "home creation failed"
    end
  end
end
