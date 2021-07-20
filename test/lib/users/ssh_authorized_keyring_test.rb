#!/usr/bin/env rspec
# Copyright (c) 2016 SUSE LLC.
#  All Rights Reserved.
#
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of version 2 or 3 of the GNU General
#  Public License as published by the Free Software Foundation.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, contact SUSE LLC.
#
#  To contact SUSE about this file by physical or electronic mail,
#  you may find current contact information at www.suse.com

require_relative "../../test_helper"
require "users/ssh_authorized_keyring"
require "tmpdir"

describe Yast::Users::SSHAuthorizedKeyring do
  subject(:keyring) { Yast::Users::SSHAuthorizedKeyring.new(home) }
  let(:home) { FIXTURES_PATH.join("home", "user1").to_s }

  def authorized_keys_from_home(path)
    file_path = File.join(path, ".ssh", "authorized_keys")
    File.read(file_path).lines.map(&:strip).grep(/ssh-/)
  end

  describe "#add_keys" do
    let(:known_key) { keyring.keys.first }
    let(:new_key) { "ssh-rsa 123ABC" }

    before { keyring.read_keys }

    it "adds only keys not already present in the keyring" do
      keyring.add_keys([known_key, new_key])

      expect(keyring.keys).to include(new_key)
      expect(keyring.keys).to include(known_key)
      expect(keyring.keys).to_not include(known_key).twice
    end

    it "preserves the keys order" do
      keyring.add_keys([new_key, known_key])

      expect(keyring.keys.first).to eq(known_key)
      expect(keyring.keys.last).to eq(new_key)
    end
  end

  describe "#changed?" do
    before { keyring.read_keys }

    context "when new keys has been added" do
      before { keyring.add_keys(["ssh-rsa 123ABC"]) }

      it "returns true" do
        expect(keyring.changed?).to eq(true)
      end
    end

    context "when no new keys has been added" do
      it "returns false" do
        expect(keyring.changed?).to eq(false)
      end
    end
  end

  describe "#empty?" do
    context "when keyring is empty" do
      it "returns true" do
        expect(keyring.empty?).to eq(true)
      end
    end

    context "when keyring is not empty" do
      before { keyring.add_keys(["ssh-rsa 123ABC"]) }

      it "returns false" do
        expect(keyring.empty?).to eq(false)
      end
    end
  end

  describe "#read_keys" do
    context "if some keys are present in the given home directory" do
      let(:expected_keys) { authorized_keys_from_home(home) }

      it "returns read keys" do
        expect(keyring.read_keys).to eq(expected_keys)
      end

      it "registers defined keys" do
        keyring.read_keys
        expect(keyring).to_not be_empty
      end
    end

    context "if no keys are present in the home directory" do
      let(:home) { FIXTURES_PATH.join("home", "user2").to_s }

      it "returns an empty array" do
        expect(keyring.read_keys).to eq([])
      end

      it "does not register any key" do
        keyring.read_keys
        expect(keyring).to be_empty
      end
    end

    context "if authorized keys file does not exist" do
      let(:home) { FIXTURES_PATH.join("home", "other").to_s }

      it "returns an empty array" do
        expect(keyring.read_keys).to eq([])
      end

      it "does not register any key" do
        keyring.read_keys
        expect(keyring).to be_empty
      end
    end
  end

  describe "#write_keys" do
    let(:tmpdir) { Dir.mktmpdir }
    let(:home) { File.join(tmpdir, "/home/user") }
    let(:file) { Yast::Users::SSHAuthorizedKeysFile.new(authorized_keys_path) }
    let(:ssh_dir) { File.join(home, ".ssh") }
    let(:key) { "ssh-rsa 123ABC" }
    let(:authorized_keys_path) { File.join(home, ".ssh", "authorized_keys") }

    before do
      FileUtils.mkdir_p(ssh_dir)

      allow(Yast::Users::SSHAuthorizedKeysFile).to receive(:new).and_return(file)
    end

    after { FileUtils.rm_rf(tmpdir) if File.exist?(tmpdir) }

    context "when there are not registered keys for the given home" do
      it "does not try to write the keys" do
        expect(file).to_not receive(:save)

        keyring.write_keys
      end
    end

    context "when there are registered keys for the given home" do
      let(:uid) { 1001 }
      let(:gid) { 101 }
      let(:home_dir_exists) { true }
      let(:ssh_dir_exists) { false }

      before do
        allow(Yast::SCR).to receive(:Read).and_call_original
        allow(Yast::SCR).to receive(:Execute).and_call_original
        allow(Yast::SCR).to receive(:Execute)
          .with(Yast::Path.new(".target.remove"), authorized_keys_path)

        allow(Yast::FileUtils).to receive(:Exists).and_call_original
        allow(Yast::FileUtils).to receive(:Exists).with(ssh_dir).and_return(ssh_dir_exists)
        allow(Yast::FileUtils).to receive(:Exists).with(home).and_return(home_dir_exists)
        allow(Yast::FileUtils).to receive(:IsDirectory).with(ssh_dir).and_return(true)
        allow(Yast::FileUtils).to receive(:Chmod).and_call_original

        # Load some authorized_keys
        FileUtils.cp_r(
          FIXTURES_PATH.join("home", "user1", ".ssh", "authorized_keys"),
          authorized_keys_path
        )
        keyring.read_keys
        keyring.add_keys([key])
      end

      context "but no new keys are added" do
        let(:key) { keyring.keys.first }

        it "does not write keys again" do
          expect(file).to_not receive(:save)

          keyring.write_keys
        end
      end

      context "but new keys are added" do
        it "writes the keys" do
          expect(file).to receive(:save)

          keyring.write_keys

          expect(File).to exist(authorized_keys_path)
        end

        it "SSH directory and authorized_keys inherits owner/group from home" do
          allow(Yast::FileUtils).to receive(:GetOwnerUserID).with(home).and_return(uid)
          allow(Yast::FileUtils).to receive(:GetOwnerGroupID).with(home).and_return(gid)
          expect(Yast::FileUtils).to receive(:Chown).with("#{uid}:#{gid}", ssh_dir, false)
          expect(Yast::FileUtils).to receive(:Chown)
            .with("#{uid}:#{gid}", authorized_keys_path, false)

          keyring.write_keys
        end

        context "when home directory does not exist" do
          let(:home_dir_exists) { false }

          it "raises a HomeDoesNotExist exception and does not write authorized_keys" do
            expect(Yast::Users::SSHAuthorizedKeysFile).to_not receive(:new)
            expect { keyring.write_keys }
              .to raise_error(Yast::Users::SSHAuthorizedKeyring::HomeDoesNotExist)
          end
        end

        context "when SSH directory could not be created" do
          it "raises a CouldNotCreateSSHDirectory exception and does not write authorized_keys" do
            expect(Yast::Users::SSHAuthorizedKeysFile).to_not receive(:new)
            expect(Yast::SCR).to receive(:Execute)
              .with(Yast::Path.new(".target.mkdir"), anything)
              .and_return(false)
            expect { keyring.write_keys }
              .to raise_error(Yast::Users::SSHAuthorizedKeyring::CouldNotCreateSSHDirectory)
          end
        end

        context "when SSH directory is not a regular directory" do
          let(:ssh_dir_exists) { true }

          it "raises a NotRegularSSHDirectory and does not write authorized_keys" do
            allow(Yast::FileUtils).to receive(:IsDirectory).with(ssh_dir)
              .and_return(false)
            expect(Yast::Users::SSHAuthorizedKeysFile).to_not receive(:new)
            expect { keyring.write_keys }
              .to raise_error(Yast::Users::SSHAuthorizedKeyring::NotRegularSSHDirectory)
          end
        end

        context "when SSH directory already exists" do
          let(:ssh_dir_exists) { true }

          it "does not create the directory" do
            allow(Yast::FileUtils).to receive(:IsDirectory).with(ssh_dir)
              .and_return(true)
            expect(Yast::SCR).to_not receive(:Execute)
              .with(Yast::Path.new(".target.mkdir"), anything)
            keyring.write_keys
          end

          it "does not set the SSH directory permissions" do
            expect(Yast::FileUtils).to_not receive(:Chmod).with(anything, ssh_dir, false)

            keyring.write_keys
          end
        end

        context "when SSH directory does not exists yet" do
          it "creates the directory" do
            expect(Yast::SCR).to receive(:Execute)
              .with(Yast::Path.new(".target.mkdir"), ssh_dir)

            keyring.write_keys
          end

          it "sets the SSH directory permissions to 0700" do
            FileUtils.rm_r(ssh_dir) # Force to remove the mock, if exists

            expect(Yast::FileUtils).to receive(:Chmod).with("0700", ssh_dir, false)

            keyring.write_keys
            mode = File.stat(ssh_dir).mode.to_s(8)
            expect(mode).to eq("40700")
          end
        end

        context "when authorized_keys is not a regular file" do
          let(:ssh_dir_exists) { true }

          it "raises a NotRegularAuthorizedKeysFile" do
            allow(file).to receive(:save)
              .and_raise(Yast::Users::SSHAuthorizedKeysFile::NotRegularFile)

            expect { keyring.write_keys }
              .to raise_error(Yast::Users::SSHAuthorizedKeyring::NotRegularAuthorizedKeysFile)
          end
        end
      end
    end
  end
end
