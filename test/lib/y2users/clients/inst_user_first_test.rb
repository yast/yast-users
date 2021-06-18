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
require "y2users/clients/inst_user_first"

describe Y2Users::Clients::InstUserFirst do
  subject { described_class.new }

  before do
    allow_any_instance_of(Yast::InstUserFirstDialog).to receive(:run).and_return(dialog_result)
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

    let(:dialog_result) { :next }

    shared_examples "run dialog" do
      it "returns the dialog result" do
        expect(subject.run).to eq(dialog_result)
      end

      context "when the dialog returns :next" do
        let(:dialog_result) { :next }

        it "updates the target config" do
          config_before = Y2Users::ConfigManager.instance.target

          subject.run

          expect(Y2Users::ConfigManager.instance.target).to_not eq(config_before)
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

    context "when the target config has not no-root users" do
      let(:elements) { [root] }

      it "runs the dialog for configuring the user without giving a specific user" do
        expect(Yast::InstUserFirstDialog).to receive(:new).with(anything, user: nil)
          .and_call_original

        subject.run
      end

      include_examples "run dialog"
    end

    context "when the target config has no-root users" do
      let(:elements) { [root, user] }

      it "runs the dialog for configuring a specific user" do
        expect(Yast::InstUserFirstDialog).to receive(:new).with(anything, user: user)
          .and_call_original

        subject.run
      end

      include_examples "run dialog"
    end
  end
end
