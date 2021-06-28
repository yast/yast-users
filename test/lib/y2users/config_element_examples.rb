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
require "y2users"

shared_examples "config element" do
  describe ".new" do
    it "generates an element with a new id" do
      id1 = described_class.new("test1").id
      id2 = described_class.new("test2").id
      id3 = described_class.new("test3").id

      ids = [id1, id2, id3]

      expect(ids).to all(be_a(Integer))
      expect(ids.uniq.size).to eq(3)
    end
  end

  describe "#attached?" do
    context "if the element is not attached to any config" do
      before do
        subject.assign_config(nil)
      end

      it "returns false" do
        expect(subject.attached?).to eq(false)
      end
    end

    context "if the element is attached to a config" do
      before do
        config.attach(subject)
      end

      let(:config) { Y2Users::Config.new }

      it "returns true" do
        expect(subject.attached?).to eq(true)
      end
    end
  end

  describe "#is?" do
    let(:other) { element_class.new("other") }

    let(:element_class) { subject.is_a?(Y2Users::User) ? Y2Users::User : Y2Users::Group }

    context "if the other element has a different class" do
      let(:element_class) { subject.is_a?(Y2Users::User) ? Y2Users::Group : Y2Users::User }

      it "returns false" do
        expect(subject.is?(other)).to eq(false)
      end
    end

    context "if the other element has the same id" do
      before do
        allow(other).to receive(:id).and_return(subject.id)
      end

      it "returns true" do
        expect(subject.is?(other)).to eq(true)
      end
    end

    context "if the other element has a different id" do
      before do
        allow(other).to receive(:id).and_return(subject.id + 1)
      end

      it "returns false" do
        expect(subject.is?(other)).to eq(false)
      end
    end
  end

  describe "#copy" do
    before do
      subject.assign_config(Y2Users::Config.new)
    end

    it "returns an equal element" do
      element = subject.copy

      expect(element).to eq(subject)
    end

    it "returns a detached element" do
      expect(subject.copy.attached?).to eq(false)
    end

    it "returns an element with the same id" do
      expect(subject.copy.id).to eq(subject.id)
    end
  end
end
