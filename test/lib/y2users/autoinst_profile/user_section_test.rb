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
require "y2users/autoinst_profile/user_section"

describe Y2Users::AutoinstProfile::UserSection do
  describe "#new_from_hashes" do
    it "returns an object containing given values" do
      section = described_class.new_from_hashes(
        "username" => "suse",
        "fullname" => "SUSE User",
        "uid"      => "1000",
        "gid"      => "100"
      )

      expect(section.username).to eq("suse")
      expect(section.fullname).to eq("SUSE User")
      expect(section.uid).to eq("1000")
      expect(section.gid).to eq("100")
    end

    it "sets authorized keys" do
      section = described_class.new_from_hashes("authorized_keys" => ["ssh-key ..."])
      expect(section.authorized_keys).to eq(["ssh-key ..."])
    end

    context "when authorized keys are not present" do
      it "sets authorized keys to an empty array" do
        section = described_class.new_from_hashes({})
        expect(section.authorized_keys).to eq([])
      end
    end

    it "sets password settings" do
      section = described_class.new_from_hashes("password_settings" => { "warn" => 60 })
      expect(section.password_settings.warn).to eq(60)
    end

    context "when password settings" do
      it "sets password settings to nil" do
        section = described_class.new_from_hashes({})
        expect(section.password_settings).to be_nil
      end
    end
  end
end
