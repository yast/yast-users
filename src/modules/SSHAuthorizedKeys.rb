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

require "yast"
require "users/ssh_authorized_key"
require "users/ssh_authorized_keys_file"

module Yast
  class SSHAuthorizedKeysClass < Module
    include Yast::Logger

    def main
      @keys = nil
    end

    # Read keys for a given user
    #
    # @param path [String] User's home path
    # @return [Array<SSHAuthorizedKey>,nil] Read keys; +nil+ if the
    #                                       authorized_keys file was not found.
    def read_keys(home)
      path = authorized_keys_path(home)
      return false unless FileUtils::Exists(path)
      authorized_keys = Yast::Users::SSHAuthorizedKeysFile.new(path).keys
      keys[home] = authorized_keys unless authorized_keys.empty?
      log.info "Read #{authorized_keys.size} keys from #{path}"
      !authorized_keys.empty?
    end

    # Add an authorized key for a given user
    #
    # @param path [String] User's home path
    # @param authorized_keys [Array<Hash,String>]
    # @return [Boolean] +true+ if some key was imported; +false+ otherwise.
    def import_keys(home, authorized_keys)
      imported_keys = authorized_keys.map { |k| Yast::Users::SSHAuthorizedKey.build_from(k) }.compact
      keys[home] = imported_keys unless imported_keys.empty?
      !imported_keys.empty?
    end

    # Write user keys to the given file
    def write_keys(home)
      return false if keys[home].nil?
      path = authorized_keys_path(home)
      file = Yast::Users::SSHAuthorizedKeysFile.new(path)
      file.keys = keys[home]
      log.info "Writing #{keys[home].size} keys in #{path}"
      file.save
      true
    end

    # Return a hash representation of the authorized keys
    #
    # To be used while exporting the AutoYaST profile.
    #
    # @param [String] Home directory where the authorized keys are located
    # @return [Array<Hash>] Authorized keys for the given home
    def export_keys(home)
      return [] unless keys[home]
      keys[home].map do |key|
        {
          "options" => key.options,
          "keytype" => key.keytype,
          "content" => key.content,
          "comment" => key.comment
        }
      end
    end

    # Return the authorized keys for each home
    #
    # @return [Hash<String,Array<SSHAuthorizedKey>>] Authorized keys for each home
    def keys
      @keys ||= {}
    end

    publish function: :import_keys, type: "boolean (string, list)"
    publish function: :read_keys, type: "boolean (string)"
    publish function: :write_keys, type: "boolean (string)"
    publish function: :export_keys, type: "map (string)"

  private

    # @return [String] Relative path to the SSH directory inside users' home
    SSH_DIR = ".ssh".freeze
    # @return [String] Authorized keys file name
    AUTHORIZED_KEYS_FILE = "authorized_keys"

    # Determine the path to the authorized keys file
    #
    # @param home [String] Home directory
    # @return [Pathname] Path to authorized keys file in a given home directory
    #
    # @see SSH_DIR
    # @see AUTHORIZED_KEYS_FILE
    def authorized_keys_path(home)
      File.join(home, SSH_DIR, AUTHORIZED_KEYS_FILE)
    end
  end

  SSHAuthorizedKeys = SSHAuthorizedKeysClass.new
end
