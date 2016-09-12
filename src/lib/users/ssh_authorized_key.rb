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

module Yast
  module Users
    # This class represents a public SSH key SSH as defined in the
    # `authorized_keys` file.
    #
    # Each key can be comprised of four elements:
    #
    # * Keytype (mandatory): key type like `ssh-rsa`, `ecdsa-sha2-nistp256`, etc.
    # * Content (mandatory): the key value itself.
    # * Options (optional):  a command to be executed, environment variables,
    #                        SSH configuration, etc.
    # * Comment (optional):  will be ignored. Useful to identify each key.
    #
    # @see man sshd(8)
    class SSHAuthorizedKey
      # Regular expression to parse `authorized_keys` lines. Taken
      # (and modified) from:
      # https://github.com/jordansissel/ruby-sshkeyauth/blob/master/lib/ssh/key/verifier.rb#L21
      AUTHORIZED_KEYS_REGEX =
        /\A((?:[A-Za-z0-9-]+(?:="[^"]+")?,?)+)? *((?:ssh|ecdsa)-[^ ]+) *([^ ]+) *(.+)?\z/

      # Builds a key from a string
      #
      # The string should be formatted like `authorized_keys` lines.
      # This methods parses the string and returns a new SSHAuthorizedKey
      # object.
      #
      # @example Parsing a line with all elements
      #   line = 'Tunnel="0" ssh-rsa 123ABC user@example.net'
      #   key = build_from_string(line) #=> #<SSHAuthorizedKey:...>
      #   key.keytype #=> "ssh-rsa"
      #   key.content #=> "123ABC"
      #   key.options #=> "Tunnel=\"0\""
      #   key.comment #=> "user@example.net"
      #
      # @example Parsing a line missing optional elements
      #   line = 'Tunnel="0" ssh-rsa 123ABC user@example.net'
      #   key = build_from_string(line) #=> SSHAuthorizedKey<...>
      #   key.keytype #=> "ssh-rsa"
      #   key.content #=> "123ABC"
      #   key.options #=> "Tunnel=\"0\""
      #   key.comment #=> "user@example.net"
      #
      # @param line [String] String to parse.
      # @return [SSHAuthorizedKey] Authorized key.
      #
      # @private
      # @see AUTHORIZED_KEYS_REGEX
      def self.build_from_string(line)
        match = AUTHORIZED_KEYS_REGEX.match(line.strip)
        return nil unless match
        SSHAuthorizedKey.new(options: match[1],
          keytype: match[2], content: match[3], comment: match[4])
      end

      # Builds a key from a hash
      #
      # This method is intended to be used in AutoYaST.
      # The hash is indexed using strings.
      #
      # @example Building a key from a hash
      #   hsh = { "options" => "Tunnel=\"0\"", "keytype" => "ssh-rsa",
      #           "content" => "123ABC", "comment" => "user@example.net"
      #   key = build_from_hash(hsh) #=> SSHAuthorizedKey<...>
      #   key.keytype #=> "ssh-rsa"
      #   key.content #=> "123ABC"
      #   key.options #=> "Tunnel=\"0\""
      #   key.comment #=> "user@example.net"
      #
      # @param hsh [Hash] Hash containing the data to be used.
      # @option hsh [String] "keytype" Key type
      # @option hsh [String] "content" Key value
      # @option hsh [String] "options" Optional SSH options
      # @option hsh [String] "comment" Optional comment
      # @return [SSHAuthorizedKey] Authorized key
      #
      # @private
      def self.build_from_hash(hsh)
        # symbolize arguments
        args = Hash[hsh.map { |k, v| [k.to_sym, v] } ]
        new(args)
      end

      # Builds a key from a hash or a string
      #
      # @param value [Hash,String] Key specification
      # @return [SSHAuthorizedKey] Authorized key.
      #
      # @see build_from_hash
      # @see build_from_string
      def self.build_from(spec)
        if spec.is_a?(::String)
          build_from_string(spec)
        elsif spec.is_a?(Hash)
          build_from_hash(spec)
        end
      end

      # @return [String] Key type
      attr_reader :keytype
      # @return [String] Key value
      attr_reader :content
      # @return [String] SSH options
      attr_reader :options
      # @return [String] Comment
      attr_reader :comment

      # Constructor
      #
      # @option keytype [String] Key type
      # @option content [String] Key value
      # @option options [String] Optional SSH options
      # @option comment [String] Optional comment
      def initialize(keytype:, content:, comment: nil, options: nil)
        @keytype = keytype
        @content = content
        @options = options
        @comment = comment
      end

      # Returns a string representation
      #
      # The representation matches the `authorized_keys` file format.
      #
      # @return [String] Line according to `authorized_keys` file format
      #
      # @see man sshd(8)
      def to_line
        [@options, @keytype, @content, @comment].join(" ").strip
      end

      # Compares the key with another one
      #
      # @return [Boolean] +true+ if keys are equivalent; +false+ otherwise
      def ==(other)
        keytype == other.keytype &&
          content == other.content &&
          comment == other.comment &&
          options == other.options
      end
    end
  end
end
