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
require "users/users_database"

describe Users::UsersDatabase do
  let(:databases) { described_class.all }
  let(:fixture_root) { FIXTURES_PATH.join("root") }
  let(:fixture_root2) { FIXTURES_PATH.join("root2") }
  let(:fixture_root3) { FIXTURES_PATH.join("root3") }

  before do
    databases.clear

    # Mock access time: files in root2 are more recent than files in root and root3
    allow(File).to receive(:atime).with(/root/).and_return(Time.new(2016))
    allow(File).to receive(:atime).with(/root2/).and_return(Time.new(2017))
    allow(File).to receive(:atime).with(/root3/).and_return(Time.new(2018))
  end

  describe ".all" do
    let(:databases) { described_class.all }

    before do
      Users::UsersDatabase.import(fixture_root)
      Users::UsersDatabase.import(fixture_root2)
      Users::UsersDatabase.import(fixture_root3)
    end

    it "returns found users databases which contain importable users" do
      expect(databases.size).to eq(2)
    end

    it "returns the users databasers sorted desc atime" do
      expect(databases[0].atime).to eq(Time.new(2018))
      expect(databases[1].atime).to eq(Time.new(2017))
    end

    it "returns the most recent accesed first" do
      expect(databases.first.users.map(&:name)).to include "b_user"
    end
  end

  describe ".import" do
    it "always stores databases sorted by access time" do
      expect(databases).to be_empty

      Users::UsersDatabase.import(fixture_root2)
      Users::UsersDatabase.import(fixture_root)
      expect(databases.size).to eq(1)
      expect(databases.first.users.map(&:name)).to include "a_user"

      databases.clear
      expect(databases).to be_empty

      Users::UsersDatabase.import(fixture_root3)
      Users::UsersDatabase.import(fixture_root2)
      Users::UsersDatabase.import(fixture_root)
      expect(databases.size).to eq(2)
      expect(databases.first.users.map(&:name)).to include "b_user"
    end

    it "ignores wrong root directories" do
      databases.clear
      expect(databases).to be_empty

      Users::UsersDatabase.import(fixture_root.join("etc"))
      Users::UsersDatabase.import("/nonexistent")
      expect(databases).to be_empty
    end
  end

  describe "#read_files" do
    let(:passwd_atime) { Time.new(2018) }
    let(:shadow_atime) { Time.new(2017) }
    let(:wrong_dir) { fixture_root2.join("wrong") }

    before do
      # Mock access time: passwd is more recent than shadow
      allow(File).to receive(:atime).with(/passwd$/).and_return(passwd_atime)
      allow(File).to receive(:atime).with(/shadow$/).and_return(shadow_atime)
    end

    it "reads the users" do
      subject.read_files(fixture_root2)

      expect(subject.users.map(&:name)).to include "a_user"
    end

    it "reads the passwords" do
      subject.read_files(fixture_root2)

      user = subject.users.find { |u| u.name = "a_user" }
      expect(user.password.value.content).to start_with "$6$pLaWhcXR$iiiiiilTEV9B"
    end

    it "stores the most recent access time" do
      subject.read_files(fixture_root2)

      expect(subject.atime).to eq passwd_atime
    end

    it "does nothing if the files are not there" do
      subject.read_files(wrong_dir)

      expect(subject.users).to be_empty
      expect(subject.atime).to be_nil
    end
  end
end
