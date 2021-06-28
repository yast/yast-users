#!/usr/bin/env rspec
#
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

require_relative "../../../test_helper"
require "y2users/autoinst_profile/users_section"

describe Y2Users::AutoinstProfile::UsersSection do
  describe ".new_from_hashes" do
    it "returns an object containing given values" do
      section = described_class.new_from_hashes(
        [{ "username" => "suse" }, { "username" => "root" }]
      )

      expect(section.users).to contain_exactly(
        an_object_having_attributes("username" => "suse"),
        an_object_having_attributes("username" => "root")
      )
    end
  end
end
