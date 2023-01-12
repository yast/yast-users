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

require_relative "test_helper"
require "y2users/user_commit_config_collection"
require "y2users/user_commit_config"

describe Y2Users::UserCommitConfigCollection do
  subject { described_class.new(elements) }

  let(:commit_config1) { Y2Users::UserCommitConfig.new.tap { |c| c.username = "test1" } }
  let(:commit_config2) { Y2Users::UserCommitConfig.new.tap { |c| c.username = "test2" } }

  describe "#by_username" do
    context "if the collection contains a commit config for the given username" do
      let(:elements) { [commit_config1, commit_config2] }

      it "returns the commit config for the given username" do
        expect(subject.by_username("test2")).to eq(commit_config2)
      end
    end

    context "if the collection does not contain a commit config for the given username" do
      let(:elements) { [commit_config1] }

      it "returns nil" do
        expect(subject.by_username("test2")).to be_nil
      end
    end
  end
end
