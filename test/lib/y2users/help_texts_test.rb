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
require "y2users/help_texts"

describe Y2Users::HelpTexts do

  # Just a dumb class to test the mixin
  class DummyHelp
    include Y2Users::HelpTexts
  end

  describe "#ca_password_text" do
    subject(:help) { DummyHelp.new }

    before do
      allow(help.validation_config).to(receive(:check_ca?)).and_return enabled
    end

    context "if the CA check is disabled" do
      let(:enabled) { false }

      it "returns an empty string" do
        expect(help.ca_password_text).to eq ""
      end
    end

    context "if the CA check is enabled" do
      let(:enabled) { true }

      it "returns a set of html paragraphs" do
        text = help.ca_password_text
        expect(text).to be_a String
        expect(text).to start_with "<p>"
        expect(text).to end_with "</p>"
      end
    end
  end
end
