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

Yast.import "FileUtils"

module Yast
  module Users
    # Represents a `authorized_keys` SSH file.
    #
    # @example Adding a key to a file
    #   path = "/home/user/.ssh/authorized_keys"
    #   file = SSHAuthorizedKeysFile.new(path) #=> #<SSHAuthorizedKeysFile:...>
    #   file.add_key("ssh-rsa 123ABC") #=> true
    #   file.save #=> true
    #
    # @example Creating a new authorized_keys file
    #   path = "/home/user/.ssh/authorized_keys2"
    #   file = SSHAuthorizedKeysFile.new(path) #=> #<SSHAuthorizedKeysFile:...>
    #   file.keys = ["ssh-rsa 123ABC"] #=> true
    #   file.save #=> true
    #
    # @see man sshd(8)
    class SSHAuthorizedKeysFile
      include Yast::Logger

      # @return [Pathname,String] Path to the file
      attr_reader :path

      # Constructor
      #
      # @param path [Pathname,String] Path to the file
      def initialize(path)
        @path = path.to_s
      end

      # Return the authorized keys present in the file
      #
      # @return [Array<String>] Array of keys
      def keys
        return @keys if @keys
        content = Yast::SCR.Read(Yast::Path.new(".target.string"), path)
        self.keys = content.nil? ? [] : content.split("\n")
        @keys
      end

      # https://github.com/jordansissel/ruby-sshkeyauth/blob/master/lib/ssh/key/verifier.rb#L21
      AUTHORIZED_KEYS_REGEX =
        /\A((?:[A-Za-z0-9-]+(?:="[^"]+")?,?)+)? *((?:ssh|ecdsa)-[^ ]+) *([^ ]+) *(.+)?\z/

      # Validate and add a key to the keyring
      #
      # The key is validated before adding it to the keyring.
      #
      # @param key [String] String that represents the key
      # @return [Array<String>] Authorized keys in the keyring
      def add_key(key)
        new_key = key.strip
        return false unless valid_key?(new_key)
        self.keys << new_key
      end

      # Set the authorized keys in the file
      #
      # It won't write the new keys to the file. For that, check the #save
      # method.
      #
      # @param new_keys [Array<String>] SSH authorized keys
      # @return [Array<String>] SSH authorized keys
      #
      # @see #save
      # @see #keys
      def keys=(new_keys)
        @keys = []
        new_keys.each { |k| add_key(k) }
        keys
      end

      # Determines is a string qualifies like a valid keys
      #
      # @param key [String] SSH authorized keys
      # @return [Boolean] +true+ if it's valid; +false+ otherwise
      def valid_key?(key)
        AUTHORIZED_KEYS_REGEX.match(key)
      end

      # Write keys to the file
      #
      # @return [Boolean] +true+ if file was written; +false+ otherwise.
      def save
        content = keys.join("\n") + "\n"
        Yast::SCR.Write(Yast::Path.new(".target.string"), path, content)
      end
    end
  end
end
