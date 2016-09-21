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
require "users/ssh_authorized_keys_file"

module Yast
  module Users
    # Read, write and store SSH authorized keys.
    #
    # This class manages authorized keys for each home directory in the
    # system.
    class SSHAuthorizedKeyring
      include Logger

      # @return [Hash<String,Array<SSHAuthorizedKey>>] Authorized keys indexed by home directory
      attr_reader :keys
      private :keys

      # Base class to use in file/directory problems
      class PathError < StandardError
        # @return [String] Path
        attr_reader :path

        # Constructor
        #
        # @param path [String] Path
        def initialize(path)
          @path = path
          super(default_message)
        end

        # @return [String] Error message
        def message
          "#{super}: #{path}"
        end

        # Returns the default message to be used
        #
        # Derived clases should implement it.
        #
        # @return [String] Default message
        def default_message
          "Path error"
        end
      end

      # The home directory does not exist.
      class HomeDoesNotExist < PathError
        # @return default_message [String] Default error message
        def default_message; "Home directory does not exist" end
      end

      # The user's SSH configuration directory could not be created.
      class CouldNotCreateSSHDirectory < PathError
        # @return default_message [String] Default error message
        def default_message; "SSH directory could not be created" end
      end

      # The user's SSH configuration directory is a link (potentially insecure).
      class NotRegularSSHDirectory < PathError
        # @return default_message [String] Default error message
        def default_message; "SSH directory is not a regular directory" end
      end

      class NotRegularAuthorizedKeysFile < PathError
        # @return default_message [String] Default error message
        def default_message; "authorized_keys is not a regular file" end
      end

      # Constructor
      def initialize
        @keys = {}
      end

      # Add/register a keys
      #
      # This method does not make any change to the system. For that,
      # see #write_keys.
      #
      # @param home [String] Home directory where the key will be stored
      # @return [Array<SSHAuthorizedKey>] Registered authorized keys
      def add_keys(home, new_keys)
        keys[home] = new_keys
      end

      # Returns the keys for a given home directory
      #
      # @return [Array<SSHAuthorizedKey>] List of authorized keys
      def [](home)
        keys[home] || []
      end

      # Determines if the keyring is empty
      #
      # @return [Boolean] +true+ if it's empty; +false+ otherwise
      def empty?
        keys.empty?
      end

      # Read keys from a given home directory and add them to the keyring
      #
      # @param path [String] User's home directory
      # @return [Boolean] +true+ if some key was found
      def read_keys(home)
        path = authorized_keys_path(home)
        return false unless FileUtils::Exists(path)
        authorized_keys = SSHAuthorizedKeysFile.new(path).keys
        keys[home] = authorized_keys unless authorized_keys.empty?
        log.info "Read #{authorized_keys.size} keys from #{path}"
        !authorized_keys.empty?
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
        if !FileUtils::Exists(home)
          log.error("Home directory '#{home}' does not exist!")
          raise HomeDoesNotExist.new(home)
        end
        user = FileUtils::GetOwnerUserID(home)
        group = FileUtils::GetOwnerGroupID(home)
        create_ssh_dir(home, user, group)
        write_file(home, user, group)
      end

      private

      # @return [String] Relative path to the SSH directory inside users' home
      SSH_DIR = ".ssh".freeze
      # @return [String] Authorized keys file name
      AUTHORIZED_KEYS_FILE = "authorized_keys".freeze
      # @return [String] Permissions to be set on SSH_DIR directory
      SSH_DIR_PERMS = "0700".freeze
      # @return [String] Permissions to be set on `authorized_keys` file
      AUTHORIZED_KEYS_PERMS = "0600".freeze

      # Determine the path to the user's SSH directory
      #
      # @param home [String] Home directory
      # @return [String] Path to the user's SSH directory
      #
      # @see SSH_DIR
      def ssh_dir_path(home)
        File.join(home, SSH_DIR)
      end

      # Determine the path to the user's authorized keys file
      #
      # @param home [String] Home directory
      # @return [String] Path to authorized keys file
      #
      # @see SSH_DIR
      # @see AUTHORIZED_KEYS_FILE
      #
      # @see #ssh_dir_path
      def authorized_keys_path(home)
        File.join(ssh_dir_path(home), AUTHORIZED_KEYS_FILE)
      end

      # Find or creates the SSH directory
      #
      # This method sets up the SSH directory (usually .ssh). Although only 1
      # level is needed (as SSH directory lives under $HOME/.ssh), this code
      # should support changing SSH_DIR to something like `.config/ssh`.
      #
      # @param home  [String] Home directory where SSH directory must be created
      # @param user  [Fixnum] Users's UID
      # @param group [Fixnum] Group's GID
      # @return [String] Returns the path to the first created directory
      #
      # @raise NotRegularSSHDirectory
      # @raise CouldNotCreateSSHDirectory
      def create_ssh_dir(home, user, group)
        ssh_dir = ssh_dir_path(home)
        if FileUtils::Exists(ssh_dir)
          raise NotRegularSSHDirectory.new(ssh_dir) unless FileUtils::IsDirectory(ssh_dir)
          return ssh_dir
        end
        ret = SCR.Execute(Path.new(".target.mkdir"), ssh_dir)
        log.info("Creating SSH directory: #{ret}")
        raise CouldNotCreateSSHDirectory.new(ssh_dir) unless ret
        FileUtils::Chown("#{user}:#{group}", ssh_dir, false) && FileUtils::Chmod(SSH_DIR_PERMS, ssh_dir, false)
      end

      # Write authorized keys file
      #
      # @param path  [String] Path to file/directory
      # @param user  [Fixnum] Users's UID
      # @param group [Fixnum] Group's GID
      # @param perms [String] Permissions (in form "0700")
      def write_file(home, owner, group)
        path = authorized_keys_path(home)
        file = SSHAuthorizedKeysFile.new(path)
        file.keys = keys[home]
        log.info "Writing #{keys[home].size} keys in #{path}"
        file.save && FileUtils::Chown("#{owner}:#{group}", path, false)
      rescue SSHAuthorizedKeysFile::NotRegularFile
        raise NotRegularAuthorizedKeysFile.new(path)
      end
    end
  end
end
