#!/usr/bin/env rspec

# Copyright (c) [2018-2021] SUSE LLC
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
require "users/dialogs/inst_root_first"
require "y2users/user"
require "cwm/rspec"

describe Yast::InstRootFirstDialog do
  subject(:dialog) { described_class.new(root_user) }
  let(:root_user) { Y2Users::User.create_root }

  include_examples "CWM::Dialog"

  describe "#abort_handler" do
    it "requests confirmation for aborting the process" do
      expect(Yast::Popup).to receive(:ConfirmAbort)
      subject.abort_handler
    end
  end
end
