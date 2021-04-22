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

describe Users::CAPasswordValidator do
  describe "#enabled?" do
    before do
      allow(Yast::ProductFeatures).to receive(:GetBooleanFeature)
        .with("globals", "root_password_ca_check")
        .and_return(ca_check)
    end

    context "if CA password check is enabled" do
      let(:ca_check) { true }

      it "returns true" do
        expect(subject.enabled?).to eq true
      end
    end

    context "if ca password check is disabled" do
      let(:ca_check) { false }

      it "returns false" do
        expect(subject.enabled?).to eq false
      end
    end

    context "if ca password check is not set" do
      let(:ca_check) { nil }

      it "returns false" do
        expect(subject.enabled?).to eq false
      end
    end
  end

  describe "#help_text" do
    before do
      allow(subject).to(receive(:enabled?))
        .and_return enabled
    end

    context "if the CA check is disabled" do
      let(:enabled) { false }

      it "returns an empty string" do
        expect(subject.help_text).to eq ""
      end
    end

    context "if the CA check is enabled" do
      let(:enabled) { true }

      it "returns a set of html paragraphs" do
        expect(subject.help_text).to be_a String
        expect(subject.help_text).to start_with "<p>"
        expect(subject.help_text).to end_with "</p>"
      end
    end
  end

  describe "#errors_for" do
    before do
      allow(subject).to(receive(:enabled?))
        .and_return enabled
    end

    context "if the CA check is disabled" do
      let(:enabled) { false }

      it "returns empty list for a long password" do
        expect(subject.errors_for("aL0ngPassw0rd")).to eq []
      end

      it "returns empty list for a short password" do
        expect(subject.errors_for("a1b")).to eq []
      end
    end

    context "if the CA check is enabled" do
      let(:enabled) { true }

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
