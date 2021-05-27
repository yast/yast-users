#!/usr/bin/env rspec
# Copyright (c) [2018] SUSE LLC
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
require "users/widgets/inst_root_first"
require "cwm/rspec"

describe Y2Users::Widgets::InstRootFirst do
  subject(:widget) { described_class.new(root_user) }

  let(:root_user) { Y2Users::User.new("root") }

  include_examples "CWM::CustomWidget"

  before do
    allow(Yast2::Popup).to receive(:show)
  end

  describe "#validate" do
    let(:password?) { false }
    let(:key?) { false }

    let(:password_widget) do
      instance_double(Users::PasswordWidget, empty?: !password?)
    end

    let(:public_key_selector) do
      instance_double(Y2Users::Widgets::PublicKeySelector, empty?: !key?)
    end

    before do
      allow(Users::PasswordWidget).to receive(:new).and_return(password_widget)
      allow(Y2Users::Widgets::PublicKeySelector).to receive(:new).and_return(public_key_selector)
    end

    context "when neither a password nor public key was given" do
      before do
      end

      it "returns false" do
        expect(widget.validate).to eq(false)
      end

      it "displays an error" do
        expect(Yast2::Popup).to receive(:show)
          .with(/to provide at least a password/, headline: :error)
        widget.validate
      end
    end

    context "when a password was given" do
      let(:password?) { true }

      it "returns true" do
        expect(widget.validate).to eq(true)
      end

      it "does not display any error" do
        expect(Yast2::Popup).to_not receive(:show)
      end
    end

    context "when a public key was given" do
      let(:key?) { true }

      it "returns true" do
        expect(widget.validate).to eq(true)
      end

      it "does not display any error" do
        expect(Yast2::Popup).to_not receive(:show)
      end
    end
  end
end
