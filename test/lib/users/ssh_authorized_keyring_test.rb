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
require "users/ssh_authorized_key"
require "tmpdir"

describe Yast::Users::SSHAuthorizedKeyring do
  subject(:keyring) { Yast::Users::SSHAuthorizedKeyring.new }

  describe "#read_keys" do
    context "if some keys are present in the given home directory" do
      let(:home) { FIXTURES_PATH.join("home", "user1").to_s }

      it "returns true" do
        expect(subject.read_keys(home)).to eq(true)
      end

      it "registers defined keys" do
        subject.read_keys(home)
        expect(subject.keys).to_not be_empty
      end
    end

    context "if no keys are present in the home directory" do
      let(:home) { FIXTURES_PATH.join("home", "user2").to_s }

      it "returns false" do
        expect(subject.read_keys(home)).to eq(false)
      end

      it "does not register any key" do
        subject.read_keys(home)
        expect(subject.keys).to eq({})
      end
    end

    context "if authorized keys file does not exist" do
      let(:home) { FIXTURES_PATH.join("home", "other").to_s }

      it "returns false" do
        expect(subject.read_keys(home)).to eq(false)
      end

      it "does not register any key" do
        subject.read_keys(home)
        expect(subject.keys).to eq({})
      end
    end
  end

  describe "#write_keys" do
    let(:tmpdir) { Dir.mktmpdir }
    let(:home) { File.join(tmpdir, "/home/user") }
    let(:file) { double("file", save: true) }
    let(:ssh_dir) { File.join(home, ".ssh") }
    let(:key) { Yast::Users::SSHAuthorizedKey.build_from("ssh-rsa 123ABC") }
    let(:authorized_keys_path) { File.join(home, ".ssh", "authorized_keys") }

    before { FileUtils.mkdir_p(home) }
    after { FileUtils.rm_rf(tmpdir) if File.exist?(tmpdir) }

    context "if no keys are registered for the given home" do
      it "returns false" do
        expect(subject.write_keys(home)).to eq(false)
      end

      it "does not try to write the keys" do
        expect(file).to_not receive(:save)
        subject.write_keys(home)
      end
    end

    context "if some keys are registered for the given home" do
      let(:uid) { 1001 }
      let(:gid) { 101 }

      before do
        allow(Yast::SCR).to receive(:Execute).and_call_original
        allow(Yast::SCR).to receive(:Read).and_call_original
        subject.add_keys(home, [key])
      end

      it "writes the keys and returns true" do
        expect(subject.write_keys(home)).to eq(true)
        expect(File).to exist(authorized_keys_path)
      end

      it "ssh directory and authorized_keys inherits owner/group from home" do
        allow(Yast::FileUtils).to receive(:Exists).with(ssh_dir).and_return(false)
        allow(Yast::FileUtils).to receive(:Exists).with(home).and_return(true)
        expect(Yast::SCR).to receive(:Read)
          .with(Yast::Path.new(".target.stat"), home)
          .and_return("uid" => uid, "gid" => gid)
        expect(Yast::SCR).to receive(:Execute)
          .with(Yast::Path.new(".target.bash_output"), /chown -R #{uid}:#{gid} #{home}/)
          .and_return("exit" => 0)
        expect(Yast::SCR).to receive(:Execute)
          .with(Yast::Path.new(".target.bash_output"), /chown -R #{uid}:#{gid} #{authorized_keys_path}/)
          .and_return("exit" => 0)

        subject.write_keys(home)
      end

      it "sets ssh directory permissions to 0700" do
        subject.write_keys(home)
        mode = File.stat(ssh_dir).mode.to_s(8)
        expect(mode).to eq("40700")
      end

      it "sets authorized_keys permissions to 0600" do
        subject.write_keys(home)
        mode = File.stat(authorized_keys_path).mode.to_s(8)
        expect(mode).to eq("100600")
      end

      context "when ssh directory already exists" do
        before { FileUtils.mkdir_p(ssh_dir) }

        it "does not create the directory" do
          expect(Yast::SCR).to_not receive(:Execute)
            .with(Yast::Path.new(".target.mkdir"), anything)
          subject.write_keys(home)
        end
      end
    end
  end
end
