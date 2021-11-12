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

require_relative "../test_helper"

require "y2users/linux/useradd_config_writer"
require "y2users/config"
require "y2users/useradd_config"

describe Y2Users::Linux::UseraddConfigWriter do
  subject { described_class.new(target_config, initial_config) }

  let(:initial_config) do
    Y2Users::Config.new.tap do |config|
      config.useradd = Y2Users::UseraddConfig.new(
        group: "test", home: "/home", shell: "/bin/bash", umask: "022", skel: "/etc/skel"
      )
    end
  end

  let(:target_config) { initial_config.copy }

  describe "#write" do
    before do
      allow(Yast::Execute).to receive(:on_target!)
    end

    context "when the useradd config has not changed in the target config" do
      it "does not write useradd config" do
        expect(Yast::Execute).to_not receive(:on_target!).with(/useradd/, any_args)

        subject.write
      end

      it "does not write shadow config" do
        expect(Yast::ShadowConfig).to_not receive(:write)

        subject.write
      end
    end

    context "when the umask has changed" do
      before do
        target_config.useradd.umask = "024"
      end

      it "writes the new umask to the shadow config" do
        expect(Yast::ShadowConfig).to receive(:set).with(:umask, "024")
        expect(Yast::ShadowConfig).to receive(:write)

        subject.write
      end
    end

    context "when the group has changed" do
      before do
        target_config.useradd.group = "new_group"
      end

      it "writes the new group to the useradd config" do
        expect(Yast::Execute).to receive(:on_target!)
          .with(/useradd/, "-D", "--gid", "new_group")

        subject.write
      end
    end

    context "when the home has changed" do
      before do
        target_config.useradd.home = "/new_home"
      end

      it "writes the new home to the useradd config" do
        expect(Yast::Execute).to receive(:on_target!)
          .with(/useradd/, "-D", "--base-dir", "/new_home")

        subject.write
      end
    end

    context "when the shell has changed" do
      before do
        target_config.useradd.shell = "/bin/zsh"
      end

      it "writes the new shell to the useradd config" do
        expect(Yast::Execute).to receive(:on_target!)
          .with(/useradd/, "-D", "--shell", "/bin/zsh")

        subject.write
      end
    end

    context "when the expiration has changed" do
      before do
        target_config.useradd.expiration = "2021-08-12"
      end

      it "writes the new expiration to the useradd config" do
        expect(Yast::Execute).to receive(:on_target!)
          .with(/useradd/, "-D", "--expiredate", "2021-08-12")

        subject.write
      end
    end

    context "when the inactivity period has changed" do
      before do
        target_config.useradd.inactivity_period = 10
      end

      it "writes the new inactivity period to the useradd config" do
        expect(Yast::Execute).to receive(:on_target!)
          .with(/useradd/, "-D", "--inactive", 10)

        subject.write
      end
    end

    context "when there is an error writing the useradd config" do
      before do
        target_config.useradd.group = "new_group"

        allow(Yast::Execute).to receive(:on_target!).with(/useradd/, any_args).and_raise(error)
      end

      let(:error) { Cheetah::ExecutionFailed.new("", "", "", "", "error") }

      it "reports an issue" do
        issues = subject.write

        expect(issues.first.message).to match(/went wrong writing.*--gid/)
      end
    end
  end
end
