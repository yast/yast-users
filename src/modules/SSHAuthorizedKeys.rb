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
require "users/ssh_authorized_keyring"

module Yast
  # This module add support to handle SSH authorized keys.
  #
  # It's inteded to be a thin layer above SSHAuthorizedKey and
  # SSHAuthorizedKeysFile to be used by yast2-users module
  # (which is mainly written in Perl).
  class SSHAuthorizedKeysClass < Module
    include Yast::Logger

    # Module's initialization
    def main
      @keyring = nil
    end

    def keyring
      @keyring ||= Users::SSHAuthorizedKeyring.new
    end

    def read_keys(home)
      keyring.read_keys(home)
    end

    def write_keys(home)
      keyring.write_keys(home)
    end

    # Add an authorized key for a given home directory
    #
    # @param path [String] User's home directory
    # @param authorized_keys [Array<Hash,String>]
    # @return [Boolean] +true+ if some key was imported; +false+ otherwise.
    def import_keys(home, authorized_keys)
      imported_keys = authorized_keys.map { |k| Users::SSHAuthorizedKey.build_from(k) }
      imported_keys.compact!
      !keyring.add_keys(home, imported_keys).empty?
    end

    # Return a hash representation of the authorized keys
    #
    # To be used while exporting the AutoYaST profile.
    #
    # @param [String] Home directory where the authorized keys are located
    # @return [Array<Hash>] Authorized keys for the given home
    def export_keys(home)
      keyring[home].map do |key|
        {
          "options" => key.options,
          "keytype" => key.keytype,
          "content" => key.content,
          "comment" => key.comment
        }
      end
    end

    publish function: :import_keys, type: "boolean (string, list)"
    publish function: :read_keys, type: "boolean (string)"
    publish function: :write_keys, type: "boolean (string)"
    publish function: :export_keys, type: "map (string)"
  end

  SSHAuthorizedKeys = SSHAuthorizedKeysClass.new
end
