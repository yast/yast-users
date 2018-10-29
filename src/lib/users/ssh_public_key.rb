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

require "yast2/execute"

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
      @fingerprint = fingerprint_from(raw)
      @raw = raw.strip
    end

    # Returns the key comment
    #
    # @return [String] Comment field
    def comment
      @comment ||= @raw.split(" ").last
    end

  private

    # Gets the fingerprint for the given OpenSSH public key
    #
    # @return [String] Key fingerprint
    # @raise InvalidKey
    def fingerprint_from(raw)
      output = Yast::Execute.locally!(
        ["echo", raw], ["ssh-keygen", "-l", "-f", "/dev/stdin"], stdout: :capture
      )
      output.split(" ")[1].to_s
    rescue Cheetah::ExecutionFailed
      raise InvalidKey
    end
  end
end
