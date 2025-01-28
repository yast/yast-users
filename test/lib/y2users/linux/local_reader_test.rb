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

require "y2users/config"
require "y2users/linux/local_reader"

describe Y2Users::Linux::LocalReader do
  subject { described_class.new(root_dir) }
  let(:root_dir) { File.join(FIXTURES_PATH, "/root/") }

  around do |example|
    # Let's use test/fixtures/home as src root for reading authorized keys from there
    change_scr_root(FIXTURES_PATH.join("home")) { example.run }
  end

  before do
    allow(Yast::Execute).to receive(:on_target!).with(/useradd/, "-D", anything)
      .and_return(useradd_default_values)
  end

  describe "#read" do
    context "when all expected files are present" do
      it "generates a config with read data" do
        config = subject.read

        expect(config).to be_a(Y2Users::Config)

        expect(config.users.size).to eq 17
        expect(config.groups.size).to eq 36

        root_user = config.users.root
        expect(root_user.uid).to eq "0"
        expect(root_user.home.path).to eq "/root"
        expect(root_user.shell).to eq "/bin/bash"
        expect(root_user.primary_group.name).to eq "root"
        expect(root_user.password.value.encrypted?).to eq true
        expect(root_user.password.value.content).to match(/^\$6\$pL/)

        expect(config.login?).to eq(false)
      end
    end

    context "when any file is missing" do
      let(:root_dir) { File.join(FIXTURES_PATH, "/root-missing-files/") }

      it "does not crash" do
        expect { subject.read }.to_not raise_error
      end

      it "logs an error" do
        expect(subject.log).to receive(:error)
          .with(/File.*does not exist/)
          .at_least(:once)

        subject.read
      end

      it "generates a config" do
        config = subject.read

        expect(config).to be_a(Y2Users::Config)

        expect(config.users.size).to eq 0
        expect(config.groups.size).to eq 0

        expect(config.login?).to eq(false)
      end
    end
  end
end
