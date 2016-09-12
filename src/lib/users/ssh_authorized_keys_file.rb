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

require "users/ssh_authorized_key"
Yast.import "FileUtils"

module Yast
  module Users
    # Represents a `authorized_keys` SSH file.
    #
    # @example Adding a key to a file
    #   path = "/home/user/.ssh/authorized_keys"
    #   file = SSHAuthorizedKeysFile.new(path) #=> #<SSHAuthorizedKeysFile:...>
    #   file.keys += SSHAuthorizedKey.build("ssh-rsa 123ABC") #=> [#<SSHAuthorizedKey:...>, ...]
    #   file.save #=> true
    #
    # @example Creating a new authorized_keys file
    #   path = "/home/user/.ssh/authorized_keys2"
    #   file = SSHAuthorizedKeysFile.new(path) #=> #<SSHAuthorizedKeysFile:...>
    #   file.keys = [SSHAuthorizedKey.build("ssh-rsa 123ABC")] #=> [#<SSHAuthorizedKey:...>]
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

      # Returns the authorized keys present in the file
      #
      # @return [Array<SSHAuthorizedKey>] Array of keys
      def keys
        return @keys if @keys
        return @keys = [] unless FileUtils::Exists(path)
        content = Yast::SCR.Read(Yast::Path.new(".target.string"), path)
        @keys ||= content.split("\n").each_with_object([]) do |line, keys|
          key = SSHAuthorizedKey.build_from_string(line.strip)
          keys << key if key
        end
      end

      # Set the file keys
      #
      # It won't write the new keys to the file. For that, check the #save
      # method.
      #
      # @param new_keys [Array<SSHAuthorizedKey>] SSH authorized keys
      # @return [Array<SSHAuthorizedKey>] SSH authorized keys
      #
      # @see #save
      # @see #keys
      def keys=(new_keys)
        @keys = new_keys
      end

      # Write keys to the file
      #
      # @return [Boolean] +true+ if file was written; +false+ otherwise.
      def save
        content = keys.map(&:to_line).join("\n") + "\n"
        Yast::SCR.Write(Yast::Path.new(".target.string"), path, content)
      end
    end
  end
end
