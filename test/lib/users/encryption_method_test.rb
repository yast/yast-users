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
require "users/encryption_method"
Yast.import "UsersSimple"

describe Users::EncryptionMethod do
  before do
    allow(Yast::UsersSimple).to receive(:EncryptionMethod).and_return current_method
  end

  subject { Users::EncryptionMethod }

  describe ".current" do
    context "if an unknown method is returned by UsersSimple" do
      let(:current_method) { "plain" }

      it "raises an exception" do
        expect { subject.current }.to raise_error Users::EncryptionMethod::NotFoundError
      end
    end

    context "if a valid method is returned by UsersSimple" do
      let(:current_method) { "sha256" }

      it "returns the corresponding object" do
        expect(subject.current).to eq subject.new("sha256")
      end
    end
  end

  describe "#current?" do
    let(:current_method) { "des" }

    it "returns true if the method is the current one" do
      expect(subject.new("des").current?).to eq true
    end

    it "returns false if the method is not the current one" do
      expect(subject.new("sha512").current?).to eq false
    end
  end
end
