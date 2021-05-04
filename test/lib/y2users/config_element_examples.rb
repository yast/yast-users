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
require "y2users"

shared_examples "config element" do
  describe "#attached?" do
    before do
      subject.assign_internal_id(nil)
      subject.assign_config(nil)
    end

    context "if the element is not attached to any config" do
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
    context "if the other element has a different class" do
      let(:other) do
        klass = subject.is_a?(Y2Users::User) ? Y2Users::Group : Y2Users::User
        klass.new("other")
      end

      it "returns false" do
        expect(subject.is?(other)).to eq(false)
      end
    end

    context "if the other element has the same class" do
      let(:other) do
        klass = subject.is_a?(Y2Users::User) ? Y2Users::User : Y2Users::Group
        klass.new("other")
      end

      context "and the element has no id" do
        before do
          subject.assign_internal_id(nil)
          other.assign_internal_id(69)
        end

        it "returns false" do
          expect(subject.is?(other)).to eq(false)
        end
      end

      context "and the element has id" do
        before do
          subject.assign_internal_id(69)
        end

        context "but the other element has no id" do
          before do
            other.assign_internal_id(nil)
          end

          it "returns false" do
            expect(subject.is?(other)).to eq(false)
          end
        end

        context "and the other element has id" do
          before do
            other.assign_internal_id(other_id)
          end

          context "and the other element has not the same id as the element" do
            let(:other_id) { 19 }

            it "returns false" do
              expect(subject.is?(other)).to eq(false)
            end
          end

          context "and the other element has the same id as the element" do
            let(:other_id) { 69 }

            it "returns true" do
              expect(subject.is?(other)).to eq(true)
            end
          end
        end
      end
    end
  end

  describe "#clone" do
    before do
      subject.assign_internal_id(69)
      subject.assign_config(Y2Users::Config.new)
    end

    it "returns an equal element" do
      cloned = subject.clone

      expect(cloned).to eq(subject)
    end

    it "returns a detached element" do
      expect(subject.clone.attached?).to eq(false)
    end

    it "returns an element without id" do
      expect(subject.clone.id).to be_nil
    end
  end
end
