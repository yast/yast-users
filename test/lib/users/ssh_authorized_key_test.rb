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
require "users/ssh_authorized_key"

describe Yast::Users::SSHAuthorizedKey do
  describe "#to_line" do
    context "when all elements are present" do
      subject(:key) do
        described_class.new(options: 'tunnel="0"', keytype: "ssh-rsa",
          content: "ABC123", comment: "dummy1@example.net")
      end

      it "returns the 'authorized_keys' form containing all elements" do
        expect(key.to_line).to eq('tunnel="0" ssh-rsa ABC123 dummy1@example.net')
      end
    end

    context "when comment and options are missing" do
      subject(:key) { described_class.new(keytype: "ssh-rsa", content: "ABC123") }

      it "returns the 'authorized_keys' form without comment and options" do
        expect(key.to_line).to eq('ssh-rsa ABC123')
      end
    end
  end

  describe "#build" do
    let(:options) { 'Tunnel="0",command="/opt/logon.sh $USER"' }
    let(:comment) { "user1@example.net" }
    let(:keytype) { "ssh-rsa"}
    let(:content) { "ABC123" }
    let(:line) { [options, keytype, content, comment].join(" ") }
    let(:key) do
      described_class.new(keytype: keytype, content: content, options: options, comment: comment)
    end

    context "using a hash indexed by keys" do
      it "returns a new SSHAuthorizedKey" do
        hash = { "keytype" => keytype, "content" => content,
          "options" => options, "comment" => comment }
        expect(described_class.build_from(hash)).to eq(key)
      end
    end

    context "using a string" do
      it "returns a new SSHAuthorizedKey after parsing the line" do
        expect(described_class.build_from(line)).to eq(key)
      end

      context "when line does not contain options" do
        let(:options) { nil }

        it "does not include options" do
          expect(described_class.build_from(line).options).to be_nil
        end
      end

      context "when line does not contain a comment" do
        let(:comment) { nil }

        it "does not include comment" do
          expect(described_class.build_from(line).comment).to be_nil
        end
      end

      context "when line contains extra spaces" do
        let(:line) { " #{options}  #{keytype}  #{content}  #{comment} " }

        it "returns a new SSHAuthorizedKey ignoring the extra spaces" do
          expect(described_class.build_from(line)).to eq(key)
        end
      end

      context "when optional elements are missing and line contains extra spaces" do
        let(:options) { nil }
        let(:comment) { nil }
        let(:line) { "  #{keytype}  #{content} " }

        it "returns a new SSHAuthorizedKey ignoring the extra spaces and missing elements" do
          expect(described_class.build_from(line)).to eq(key)
        end
      end

      context "when line format does not match with a key" do
        it "returns nil" do
          expect(described_class.build_from("only four random elements")).to be_nil
        end
      end
    end
  end
end
