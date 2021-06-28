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
require "y2users/clients/inst_root_first"

describe Y2Users::Clients::InstRootFirst do
  subject { described_class.new }

  before do
    allow_any_instance_of(Yast::InstRootFirstDialog).to receive(:run).and_return(dialog_result)
  end

  let(:dialog_result) { :auto }

  describe "#run" do
    before do
      config = Y2Users::Config.new
      config.attach(elements)
      Y2Users::ConfigManager.instance.target = config
    end

    let(:user) do
      Y2Users::User.new("test").tap do |user|
        user.password = Y2Users::Password.create_plain("s3cr3t")
      end
    end

    let(:root) { Y2Users::User.create_root }

    let(:elements) { [root, user] }

    context "when the root password matches with a user password" do
      before do
        root.password = user.password.copy
      end

      it "does not show the dialog" do
        expect_any_instance_of(Yast::InstRootFirstDialog).to_not receive(:run)

        subject.run
      end

      it "does not modify the target config" do
        config_before = Y2Users::ConfigManager.instance.target

        subject.run

        expect(Y2Users::ConfigManager.instance.target).to eq(config_before)
      end

      it "returns :auto" do
        expect(subject.run).to eq(:auto)
      end
    end

    shared_examples "run dialog" do
      it "runs the dialog for configuring the root password" do
        expect_any_instance_of(Yast::InstRootFirstDialog).to receive(:run)

        subject.run
      end

      it "returns the dialog result" do
        expect(subject.run).to eq(dialog_result)
      end

      context "when the dialog returns :next" do
        let(:dialog_result) { :next }

        it "updates the target config" do
          config_before = Y2Users::ConfigManager.instance.target

          subject.run

          expect(Y2Users::ConfigManager.instance.target).to_not eq(config_before)
          expect(Y2Users::ConfigManager.instance.target.users.root).to_not be_nil
        end
      end

      context "when the dialog does not return :next" do
        let(:dialog_result) { :abort }

        it "does not modify the target config" do
          config_before = Y2Users::ConfigManager.instance.target

          subject.run

          expect(Y2Users::ConfigManager.instance.target).to eq(config_before)
        end
      end
    end

    context "when the root password does not match with a user password" do
      before do
        root.password = root_password
      end

      let(:dialog_result) { :next }

      context "and root has no password yet" do
        let(:root_password) { nil }

        include_examples "run dialog"
      end

      context "and root has a password" do
        let(:root_password) { Y2Users::Password.create_plain("0th3r") }

        include_examples "run dialog"
      end
    end

    context "when there is no root user yet" do
      let(:elements) { [user] }

      include_examples "run dialog"
    end
  end
end
