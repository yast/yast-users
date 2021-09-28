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

require "y2users/config"
require "y2users/user"
require "y2users/useradd_config"
require "y2users/login_config"
require "y2users/linux/writer"
require "y2users/commit_config_collection"

describe Y2Users::Linux::Writer do
  subject(:writer) { described_class.new(config, initial_config, commit_configs) }

  describe "Modifying the system configuration via #write" do
    let(:initial_config) do
      config = Y2Users::Config.new
      config
    end

    let(:config) { initial_config.copy }

    let(:commit_configs) { Y2Users::CommitConfigCollection.new }

    let(:initial_useradd) { Y2Users::UseraddConfig.new(initial_useradd_attrs) }
    let(:initial_useradd_attrs) do
      { group: "150", home: "/users", umask: "123", skel: "/etc/skeleton" }
    end

    before do
      initial_config.useradd = initial_useradd

      allow(Yast::Execute).to receive(:on_target!)
      allow(Yast::Autologin).to receive(:Write)
    end

    context "when there are no login settings" do
      before do
        config.login = nil
      end

      it "does not write auto-login config" do
        expect(Yast::Autologin).to_not receive(:Write)

        writer.write
      end
    end

    context "when there are login settings" do
      before do
        config.login = Y2Users::LoginConfig.new
        config.login.autologin_user = Y2Users::User.new("test")
        config.login.passwordless = true
      end

      it "configures auto-login according to the settings" do
        writer.write

        expect(Yast::Autologin.user).to eq("test")
        expect(Yast::Autologin.pw_less).to eq(true)
      end

      it "writes auto-login config" do
        expect(Yast::Autologin).to receive(:Write)

        writer.write
      end
    end

    context "when the useradd configuration has not changed" do
      it "does not alter the useradd configuration" do
        expect(Yast::Execute).to_not receive(:on_target!).with(/useradd/, any_args)
        expect(Yast::ShadowConfig).to_not receive(:set)
        expect(Yast::ShadowConfig).to_not receive(:write)

        writer.write
      end
    end

    context "when the umask for useradd has changed" do
      it "writes the change to login.defs" do
        expect(Yast::ShadowConfig).to receive(:set).with(:umask, "321")
        expect(Yast::ShadowConfig).to receive(:write)

        config.useradd.umask = "321"
        writer.write
      end
    end

    context "when some useradd configuration parameters have changed" do
      let(:error) { Cheetah::ExecutionFailed.new("", "", "", "", "error") }

      it "writes all the known parameters to the useradd configuration" do
        expect(Yast::Execute).to receive(:on_target!).with(/useradd/, "-D", "--gid", "users")
        expect(Yast::Execute).to receive(:on_target!).with(/useradd/, "-D", "--expiredate", "")
        expect(Yast::Execute).to receive(:on_target!).with(/useradd/, "-D", "--base-dir", "/users")

        config.useradd.group = "users"
        config.useradd.expiration = ""
        writer.write
      end

      it "reports an issue if writing some parameter fails" do
        allow(Yast::Execute).to receive(:on_target!).with(/useradd/, "-D", "--gid", "users")
          .and_raise(error)

        config.useradd.group = "users"
        result = writer.write
        expect(result.first.message).to match(/went wrong writing.*--gid/)
      end
    end
  end
end
