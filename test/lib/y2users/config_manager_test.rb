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

require "y2users/config_manager"
require "y2users/config"

describe Y2Users::ConfigManager do
  subject { described_class.instance }

  before do
    # reset singleton before each test
    Singleton.__init__(described_class)
  end

  describe "#register" do
    it "stores given config" do
      config1 = Y2Users::Config.new
      subject.register(config1, as: :test)
      expect(subject.config(:test)).to be config1
    end

    it "overwrites previously stored config with same id" do
      config1 = Y2Users::Config.new
      subject.register(config1, as: :test)
      config2 = Y2Users::Config.new
      subject.register(config2, as: :test)
      expect(subject.config(:test)).to be config2
    end
  end

  describe "#unregister" do
    it "removes given config" do
      config1 = Y2Users::Config.new
      subject.register(config1, as: :test)
      subject.unregister(:test)

      expect(subject.config(:test)).to be nil
    end
  end

  describe "#known_ids" do
    it "enlists all registered ids" do
      config1 = Y2Users::Config.new
      subject.register(config1, as: :test)
      config2 = Y2Users::Config.new
      subject.register(config2, as: :lest)
      expect(subject.known_ids).to contain_exactly(:test, :lest)
    end
  end

  describe "#config" do
    it "returns config with given id" do
      config1 = Y2Users::Config.new
      subject.register(config1, as: :test)
      expect(subject.config(:test)).to be config1
    end

    it "returns nil if there are no config with given id" do
      expect(subject.config(:test)).to be nil
    end
  end
end
