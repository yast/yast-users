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
require "users/ssh_authorized_keyring"

module Yast
  # This module add support to handle SSH authorized keys.
  #
  # It's inteded to be a thin layer on top of SSHAuthorizedKeyring to be used by
  # yast2-users module (which is mainly written in Perl).
  class SSHAuthorizedKeysClass < Module
    include Logger

    attr_reader :keyring

    def main
      @keyring = Users::SSHAuthorizedKeyring.new
    end

    # Read keys from a given home directory
    #
    # @see Yast::Users::SSHAuthorizedKeyring#read_keys
    def read_keys(home)
      keyring.read_keys(home)
    end

    # Write keys to a given home directory
    #
    # @see Yast::Users::SSHAuthorizedKeyring#write_keys
    def write_keys(home)
      keyring.write_keys(home)
    rescue Users::SSHAuthorizedKeyring::HomeDoesNotExist
      log.warn("Home directory '#{home}' does not exist")
      Report.Warning(
        # TRANSLATORS: '%s' is a directory path
        _(format("Home directory '%s' does not exist\n" \
                 "so authorized keys won't be written.", home))
      )
    rescue Users::SSHAuthorizedKeyring::NotRegularSSHDirectory
      log.warn("SSH directory under '%s' is a symbolic link.")
      Report.Warning(
        # TRANSLATORS: '%s' is a directory path
        _(format("SSH directory under '%s' is a symbolic link.\n" \
                 "It may cause a security issue so authorized\n" \
                 "keys won't be written.", home))
      )
    rescue Users::SSHAuthorizedKeyring::CouldNotCreateSSHDirectory
      log.warn("SSH directory under '#{home}' could not be created")
      Report.Warning(
        # TRANSLATORS: '%s' is a directory path
        _(format("Could not create SSH directory under '%s',\nso authorized keys won't be written.", home))
      )
    end

    # Add a list of authorized keys for a given home directory
    #
    # @param path [String] User's home directory
    # @param authorized_keys [Array<Hash|String>]
    # @return [Boolean] +true+ if some key was imported; +false+ otherwise.
    def import_keys(home, keys)
      !keyring.add_keys(home, keys).empty?
    end

    # Return a hash representation of the authorized keys
    #
    # To be used while exporting the AutoYaST profile.
    #
    # @param [String] Home directory where the authorized keys are located
    # @return [Array<Hash>] Authorized keys for the given home
    def export_keys(home)
      keyring[home]
    end

    publish function: :import_keys, type: "boolean (string, list)"
    publish function: :read_keys, type: "boolean (string)"
    publish function: :write_keys, type: "boolean (string)"
    publish function: :export_keys, type: "list<map> (string)"
  end

  SSHAuthorizedKeys = SSHAuthorizedKeysClass.new
  SSHAuthorizedKeys.main
end
