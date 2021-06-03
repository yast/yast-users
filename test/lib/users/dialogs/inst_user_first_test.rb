#!/usr/bin/env rspec
# Copyright (c) [2018] SUSE LLC
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

require_relative "../../../test_helper"
require "users/dialogs/inst_user_first"

describe Yast::InstUserFirstDialog do
  subject(:dialog) { described_class.new }

  before do
    Users::UsersDatabase.all.clear

    allow(Yast::ShadowConfig).to receive(:fetch)
    allow(Yast::ShadowConfig).to receive(:fetch).with(:sys_uid_max).and_return("499")

    # Mock access time: files in root2 are more recent than files in root3
    allow(File).to receive(:atime).with(/root2/).and_return(Time.new(2018))
    allow(File).to receive(:atime).with(/root3/).and_return(Time.new(2017))
  end

  describe "#run" do
    context "when local users are disabled" do
      before do
        allow(Yast::ProductFeatures).to receive(:GetBooleanFeatureWithFallback)
          .with("globals", "enable_local_users", true).and_return(false)
      end

      it "returns :auto" do
        expect(dialog.run).to eq(:auto)
      end

      it "clears the users list" do
        expect(dialog).to receive(:clean_users_info).and_call_original
        dialog.run
      end
    end
  end

  describe "#choose_users_handler" do
    let(:users_to_import_dialog) { instance_double(Yast::UsersToImportDialog, run: nil) }
    let(:root2_path) { FIXTURES_PATH.join("root2") }
    let(:root3_path) { FIXTURES_PATH.join("root3") }

    context "when there is a previous Linux installation" do
      before do
        Users::UsersDatabase.import(root3_path)
      end

      it "displays a dialog with importable users found" do
        expect(Yast::UsersToImportDialog).to receive(:new)
          .with(["b_user", "c_user"], [])
          .and_return(users_to_import_dialog)

        dialog.choose_users_handler
      end
    end

    context "when there are multiple previous Linux installations" do
      before do
        Users::UsersDatabase.import(FIXTURES_PATH.join("root2"))
        Users::UsersDatabase.import(FIXTURES_PATH.join("root3"))
      end

      it "displays a dialog with importable users found on the most recently accessed" do
        expect(Yast::UsersToImportDialog).to receive(:new)
          .with(["a_user"], [])
          .and_return(users_to_import_dialog)

        dialog.choose_users_handler
      end
    end
  end
end
