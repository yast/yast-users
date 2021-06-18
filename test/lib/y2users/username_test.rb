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

require_relative "test_helper"
require "y2users/username"

describe Y2Users::Username do
  describe ".generate_from" do
    it "generates the username from the first given word" do
      expect(Y2Users::Username.generate_from("john brown")).to eq("john")
    end

    it "generates a lowercase name" do
      expect(Y2Users::Username.generate_from("John Brown")).to eq("john")
    end

    it "converts UTF-8 characters to similar ASCII ones" do
      expect(Y2Users::Username.generate_from("Jiří")).to eq("jiri")
      expect(Y2Users::Username.generate_from("Ærøskøbing")).to eq("aeroskobing")
    end

    it "deletes not allowed characters for username" do
      expect(Y2Users::Username.generate_from("t?ux")).to eq("tux")
      expect(Y2Users::Username.generate_from("日本語")).to eq("")
    end
  end
end
