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
  # This module add support to handle SSH authorized keys.
  #
  # It's inteded to be a thin layer above SSHAuthorizedKey and
  # SSHAuthorizedKeysFile to be used by yast2-users module
  # (which is mainly written in Perl).
  class SSHAuthorizedKeysClass < Module
    include Yast::Logger

    # Module's initialization
    def main
      @keys = nil
    end

    # Read keys from a given home directory
    #
    # @param path [String] User's home directory
    # @return [Boolean] +true+ if some key was found (and registered)
    def read_keys(home)
      path = authorized_keys_path(home)
      return false unless FileUtils::Exists(path)
      authorized_keys = Yast::Users::SSHAuthorizedKeysFile.new(path).keys
      keys[home] = authorized_keys unless authorized_keys.empty?
      log.info "Read #{authorized_keys.size} keys from #{path}"
      !authorized_keys.empty?
    end

    # Add an authorized key for a given home directory
    #
    # @param path [String] User's home directory
    # @param authorized_keys [Array<Hash,String>]
    # @return [Boolean] +true+ if some key was imported; +false+ otherwise.
    def import_keys(home, authorized_keys)
      imported_keys = authorized_keys.map { |k| Yast::Users::SSHAuthorizedKey.build_from(k) }
      imported_keys.compact!
      keys[home] = imported_keys unless imported_keys.empty?
      !imported_keys.empty?
    end

    # Write user keys to the given file
    #
    # If SSH_DIR does not exist in the given directory, it will be
    # created inheriting owner/group and setting permissions to SSH_DIR_PERM.
    #
    # @param path [String] User's home directory
    # @return [Boolean] +true+ if keys were written; +false+ otherwise
    def write_keys(home)
      return false if keys[home].nil?
      if !create_ssh_dir(home)
        log.error("SSH directory could not be created: giving up")
        return false
      end

      path = authorized_keys_path(home)
      file = Yast::Users::SSHAuthorizedKeysFile.new(path)
      file.keys = keys[home]
      log.info "Writing #{keys[home].size} keys in #{path}"
      file.save
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

    # Return the authorized keys for each home directory
    #
    # @return [Hash<String,Array<SSHAuthorizedKey>>] Authorized keys
    #   indexed by home directory paths
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
    AUTHORIZED_KEYS_FILE = "authorized_keys".freeze
    # @return [String] Permissions to be set on SSH_DIR directory
    SSH_DIR_PERMS = "0700".freeze

    # Determine the path to the user's SSH directory
    #
    # @param home [String] Home directory
    # @return [String] Path to the user's SSH directory
    #
    # @see SSH_DIR
    def ssh_dir_path(home)
      File.join(home, SSH_DIR)
    end

    # Determine the path to the authorized keys file
    #
    # @param home [String] Home directory
    # @return [String] Path to authorized keys file in a given home directory
    #
    # @see SSH_DIR
    # @see AUTHORIZED_KEYS_FILE
    #
    # @see #ssh_dir_path
    def authorized_keys_path(home)
      File.join(ssh_dir_path(home), AUTHORIZED_KEYS_FILE)
    end

    # Creates the SSH directory
    #
    # Currently, only 1 level is needed (as SSH directory lives under
    # $HOME/.ssh). But this code should support changing
    # SSH_DIR to something like `.config/ssh`.
    def create_ssh_dir(home)
      ssh_dir = ssh_dir_path(home)
      return true if FileUtils::Exists(ssh_dir)
      first_dir = non_existent_dir(ssh_dir)
      ret = Yast::SCR.Execute(Yast::Path.new(".target.mkdir"), ssh_dir)
      log.info("Creating SSH directory: #{ret}")
      return false unless ret
      adjust_perms(first_dir) && adjust_owner(first_dir)
    end

    def adjust_perms(top_dir)
      out = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"),
        "chmod -R #{SSH_DIR_PERMS} #{top_dir}")
      log.info("Setting permissions on SSH directory: #{out.inspect}")
      out["exit"].zero?
    end

    def adjust_owner(top_dir)
      stat = Yast::SCR.Read(Yast::Path.new(".target.stat"), top_dir)
      return false unless stat
      out = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"),
        "chown -R #{stat["uid"]}:#{stat["gid"]} #{top_dir}")
      out["exit"].zero?
    end

    # Returns the path of the first non-existent directory in a path
    #
    # @example Only /home/user exists
    #   non_existent_dir("/home/user/.config/ssh") #=> "/home/user/.config"
    # @example Full path exists
    #   non_existent_dir("/home/user") #=> "/home/user"
    #
    # @param dir [String]
    def non_existent_dir(dir)
      next_path, current = File.split(dir)
      if FileUtils::Exists(next_path)
        dir
      else
        non_existent_dir(next_path)
      end
    end
  end

  SSHAuthorizedKeys = SSHAuthorizedKeysClass.new
end
