# encoding: utf-8

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

require "digest"
require "base64"

module Y2Users
  # This class is a simplified representation of a OpenSSH public key.
  #
  # @example Read a public key
  #   key = Y2Users::SSHPublicKey.new(File.read("id_rsa.pub"))
  #   key.fingerprint # => "SHA256:uadPyDQj9VlFZVjK8UNp57jOnWwzGgKQJpeJEhZyV0I"
  class SSHPublicKey
    # Not a valid SSH public key
    class InvalidKey < StandardError; end

    # @return [String] Key fingerprint
    attr_reader :fingerprint

    # Constructor
    #
    # @param raw [String] Public key content
    #
    # @raise InvalidKey
    def initialize(raw)
      @raw = raw.strip
      @fingerprint = calculate_fingerprint
    end

    # Returns the key comment
    #
    # @return [String] Comment field
    def comment
      @comment ||= raw.split(" ")[2]
    end

    # Returns the string version of the public key
    #
    # @return [String]
    def to_s
      @raw
    end

    # Fingeprint formatted in a similar way to ssh-keygen
    #
    # It adds the used hash and removes the trailing "=" characters (they are
    # just padding).
    #
    # @see https://github.com/openssh/openssh-portable/blob/1a4a9cf80f5b92b9d1dadd0bfa8867c04d195391/sshkey.c#L955
    def formatted_fingerprint
      fp = fingerprint.sub(/\=+\Z/, "")
      "SHA256:#{fp}"
    end

  private

    attr_reader :raw

    KEY_REGEXP = /(ssh|ecdsa)-\S+ (\S+)/

    # Gets the fingerprint for the given OpenSSH public key
    #
    # @return [String] Key fingerprint
    # @raise InvalidKey
    def calculate_fingerprint
      key = @raw[KEY_REGEXP, 2]
      raise InvalidKey unless key
      Digest::SHA256.base64digest(Base64.decode64(key))
    end
  end
end
