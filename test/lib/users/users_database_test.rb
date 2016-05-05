#! /usr/bin/rspec
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
  describe ".import" do
    it "always stores databases sorted by access time" do
      # Mock access time: files in root2 are more recent than files in root
      allow(File).to receive(:atime) do |path|
        path =~ /root2/ ? Time.now : Time.now - 1200
      end

      Users::UsersDatabase.all.clear
      expect(Users::UsersDatabase.all).to be_empty
      Users::UsersDatabase.import(FIXTURES_PATH.join("root"))
      Users::UsersDatabase.import(FIXTURES_PATH.join("root2"))
      databases = Users::UsersDatabase.all
      expect(databases.size).to eq 2
      expect(databases.first.passwd).to start_with "a_user"

      Users::UsersDatabase.all.clear
      expect(Users::UsersDatabase.all).to be_empty
      Users::UsersDatabase.import(FIXTURES_PATH.join("root2"))
      Users::UsersDatabase.import(FIXTURES_PATH.join("root"))
      databases = Users::UsersDatabase.all
      expect(databases.size).to eq 2
      expect(databases.first.passwd).to start_with "a_user"
    end

    it "ignores wrong root directories" do
      Users::UsersDatabase.all.clear
      expect(Users::UsersDatabase.all).to be_empty
      Users::UsersDatabase.import(FIXTURES_PATH.join("root/etc"))
      Users::UsersDatabase.import("/nonexistent")
      expect(Users::UsersDatabase.all).to be_empty
    end
  end

  describe "#read_files" do
    before do
      # Mock access time: passwd is more recent than shadow
      allow(File).to receive(:atime) do |path|
        path =~ /passwd$/ ? passwd_atime : passwd_atime - 1200
      end
    end

    let(:passwd_atime) { Time.now }

    it "reads the content of the passwd file" do
      subject.read_files(FIXTURES_PATH.join("root2/etc"))
      expect(subject.passwd).to start_with "a_user"
    end

    it "reads the content of the shadow file" do
      subject.read_files(FIXTURES_PATH.join("root2/etc"))
      expect(subject.shadow).to start_with "a_user"
    end

    it "stores the most recent access time" do
      subject.read_files(FIXTURES_PATH.join("root2/etc"))
      expect(subject.atime).to eq passwd_atime
    end

    it "does nothing if the files are not there" do
      subject.read_files(FIXTURES_PATH.join("root2"))
      expect(subject.passwd).to be_nil
      expect(subject.shadow).to be_nil
      expect(subject.atime).to be_nil
    end
  end
end
