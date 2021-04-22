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

require_relative "../../test_helper"
require "users/ssh_public_key"

describe Y2Users::SSHPublicKey do
  subject(:key) { described_class.new(File.read(path)) }
  let(:path) { FIXTURES_PATH.join("id_rsa.pub") }

  describe ".new" do
    context "when the key is not valid" do
      let(:content) { "some-not-valid-key" }

      it "raises an InvalidKey error" do
        expect { described_class.new(content) }.to raise_error(Y2Users::SSHPublicKey::InvalidKey)
      end
    end
  end

  describe "#fingerprint" do
    it "returns the key fingerprint" do
      expect(subject.fingerprint).to eq("uadPyDQj9VlFZVjK8UNp57jOnWwzGgKQJpeJEhZyV0I=")
    end
  end

  describe "#formatted_fingerprint" do
    it "returns the key fingerprint using the ssh-keygen style" do
      expect(subject.formatted_fingerprint)
        .to eq("SHA256:uadPyDQj9VlFZVjK8UNp57jOnWwzGgKQJpeJEhZyV0I")
    end
  end

  describe "#comment" do
    it "returns the key comment" do
      expect(key.comment).to eq("dummy1@example.net")
    end

    context "when there is no comment" do
      let(:path) { FIXTURES_PATH.join("id_rsa_no_comment.pub") }

      it "it returns nil" do
        expect(key.comment).to be_nil
      end
    end
  end
end
