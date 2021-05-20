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

  let(:users_simple_writer) { instance_double(Y2Users::UsersSimple::Writer, write: true) }
  let(:dialog) { instance_double(Yast::InstRootFirstDialog, run: dialog_result) }
  let(:dialog_result) { :auto }

  before do
    allow(Yast::InstRootFirstDialog).to receive(:new).and_return(dialog)
    allow(Y2Users::UsersSimple::Writer).to receive(:new).and_return(users_simple_writer)
  end

  describe "#run" do
    it "returns the dialog result" do
      expect(subject.run).to eq(dialog_result)
    end

    context "when dialog result is :next" do
      let(:dialog_result) { :next }

      it "writes users configuration when dialog result is :next" do
        expect(users_simple_writer).to receive(:write)

        subject.run
      end
    end
  end
end
