#! /usr/bin/env rspec
# Copyright (c) 2016 SUSE LLC.
#  All Rights Reserved.

#  This program is free software; you can redistribute it and/or
#  modify it under the terms of version 2 or 3 of the GNU General
#  Public License as published by the Free Software Foundation.

#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
#  GNU General Public License for more details.

#  You should have received a copy of the GNU General Public License
#  along with this program; if not, contact SUSE LLC.

#  To contact SUSE about this file by physical or electronic mail,
#  you may find current contact information at www.suse.com

require_relative "../../test_helper"
require "users/ca_password_validator"
require "y2users/validation_config"

describe Users::CAPasswordValidator do
  let(:config) do
    double(Y2Users::ValidationConfig, check_ca?: check_ca, ca_min_password_length: 4)
  end

  describe "#errors_for" do
    before do
      allow(subject).to receive(:config).and_return(config)
    end

    context "if the CA check is disabled" do
      let(:check_ca) { false }

      it "returns empty list for a long password" do
        expect(subject.errors_for("aL0ngPassw0rd")).to eq []
      end

      it "returns empty list for a short password" do
        expect(subject.errors_for("a1b")).to eq []
      end
    end

    context "if the CA check is enabled" do
      let(:check_ca) { true }

      it "returns empty list for a long password" do
        expect(subject.errors_for("aL0ngPassw0rd")).to eq []
      end

      it "returns an error for a short password" do
        errors = subject.errors_for("a1b")
        expect(errors).not_to be_empty
        expect(errors[0]).to be_a String
      end
    end
  end
end
