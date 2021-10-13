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

require "y2users/linux/login_config_writer"
require "y2users/login_config"
require "y2users/user"

describe Y2Users::Linux::LoginConfigWriter do
  subject { described_class.new(login_config) }

  let(:login_config) do
    Y2Users::LoginConfig.new.tap do |config|
      config.autologin_user = Y2Users::User.new("test")
      config.passwordless = true
    end
  end

  describe "#write" do
    before do
      # Prevents changes into the system
      allow(Yast::Autologin).to receive(:Write)
    end

    it "configures Autologin module" do
      subject.write

      expect(Yast::Autologin.user).to eq("test")
      expect(Yast::Autologin.pw_less).to eq(true)
    end

    it "writes autologin" do
      expect(Yast::Autologin).to receive(:Write)

      subject.write
    end
  end
end
