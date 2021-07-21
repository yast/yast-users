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

require "shellwords"

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
      include Logger

      # @return [Pathname,String] Path to the file
      attr_reader :path

      # authorized_keys exists but it's not a regular file
      class NotRegularFile < StandardError; end

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
        content = SCR.Read(Path.new(".target.string"), path)
        self.keys = content.nil? ? [] : content.split("\n")
        @keys
      end

      # Validate and add a key to the keyring
      #
      # The key is validated before adding it to the keyring.
      #
      # @param key [String] String that represents the key
      # @return [Boolean] +true+ if the key was added; +false+ otherwise
      def add_key(key)
        new_key = key.strip

        # Ignores comments or empty lines given as key
        return if new_key.empty? || new_key.start_with?("#")

        if valid_key?(new_key)
          keys << new_key
          true
        else
          log.warn("The key '#{key}' does not look like a valid SSH key")
          false
        end
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

      # https://github.com/puppetlabs/puppet/blob/master/lib/puppet/type/ssh_authorized_key.rb#L138
      AUTHORIZED_KEYS_REGEX =
        /\A(?<env>(.+)\s+)?(?<type>(ssh|ecdsa)-\S+)\s+(?<key>[^ ]+)\s*(?<comment>.*)\z/

      # Determine is a string qualifies like a valid key
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
        if FileUtils::Exists(path)
          raise NotRegularFile unless FileUtils::IsFile(path)
        else
          SCR.Execute(Path.new(".target.bash"), "umask 0077 && /usr/bin/touch #{path.shellescape}")
        end
        content = keys.join("\n") + "\n"
        SCR.Write(Path.new(".target.string"), path, content)
      end
    end
  end
end
