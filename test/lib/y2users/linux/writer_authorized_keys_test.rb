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

require "date"
require "y2users/config"
require "y2users/user"
require "y2users/linux/writer"
require "y2users/commit_config_collection"

describe Y2Users::Linux::Writer do
  subject(:writer) { described_class.new(config, initial_config, commit_configs) }

  describe "#write" do
    let(:initial_config) do
      config = Y2Users::Config.new
      config.attach(users)
      config
    end
    let(:config) { initial_config.copy }

    let(:user) do
      user = Y2Users::User.new("testuser")
      user.home = home
      user
    end

    let(:commit_configs) { Y2Users::CommitConfigCollection.new }
    let(:users) { [] }
    let(:keyring) { instance_double(Yast::Users::SSHAuthorizedKeyring, write_keys: true) }

    before do
      allow(Yast::Execute).to receive(:on_target!)
      allow(Yast::Users::SSHAuthorizedKeyring).to receive(:new).and_return(keyring)
    end

    RSpec.shared_examples "writing authorized keys" do
      context "when home is defined" do
        let(:home) { Y2Users::Home.new("/home/testuser") }

        it "requests to write authorized keys" do
          expect(keyring).to receive(:write_keys)

          writer.write
        end
      end

      context "when home is not defined" do
        let(:home) { nil }

        it "does not request to write authorized keys" do
          expect(keyring).to_not receive(:write_keys)

          writer.write
        end
      end
    end

    context "for an existing user" do
      let(:users) { [user] }

      context "whose authorized keys have not been modified" do
        # Let's ensure there is a home to write the authorized keys to
        let(:home) { Y2Users::Home.new("/home/testuser") }

        it "does not request to write authorized keys" do
          expect(keyring).to_not receive(:write_keys)

          writer.write
        end
      end

      context "whose authorized keys were edited" do
        before do
          current_user = config.users.by_id(user.id)
          current_user.authorized_keys = ["ssh-rsa new-key"]
        end

        include_examples "writing authorized keys"
      end
    end

    context "for a new regular user" do
      before { config.attach(user) }

      include_examples "writing authorized keys"
    end

    context "for a new system user" do
      before do
        user.system = true
        config.attach(user)
      end

      include_examples "writing authorized keys"
    end
  end
end
