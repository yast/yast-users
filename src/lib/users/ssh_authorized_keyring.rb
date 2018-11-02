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
    # This class manages authorized keys for a home directory in the system.
    class SSHAuthorizedKeyring
      include Logger

      # @return [Array<String>] List of authorized keys
      attr_reader :keys
      # @return [String] Home directory path
      attr_reader :home

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
        def default_message
          "Home directory does not exist"
        end
      end

      # The user's SSH configuration directory could not be created.
      class CouldNotCreateSSHDirectory < PathError
        # @return default_message [String] Default error message
        def default_message
          "SSH directory could not be created"
        end
      end

      # The user's SSH configuration directory is a link (potentially insecure).
      class NotRegularSSHDirectory < PathError
        # @return default_message [String] Default error message
        def default_message
          "SSH directory is not a regular directory"
        end
      end

      # The authorized_keys is not a regular file (potentially insecure).
      class NotRegularAuthorizedKeysFile < PathError
        # @return default_message [String] Default error message
        def default_message
          "authorized_keys is not a regular file"
        end
      end

      # Constructor
      def initialize(home)
        @keys = []
        @home = home
      end

      # Add/register a keys
      #
      # This method does not make any change to the system. For that,
      # see #write_keys.
      #
      # @return [Array<String>] Registered authorized keys
      def add_keys(new_keys)
        keys.concat(new_keys)
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
      # @return [Array<String>] List of authorized keys
      def read_keys
        path = authorized_keys_path
        @keys = FileUtils::Exists(path) ? SSHAuthorizedKeysFile.new(path).keys : []
        log.info "Read #{@keys.size} keys from #{path}"
        @keys
      end

      # Write user keys to the given file
      #
      # If SSH_DIR does not exist in the given directory, it will be
      # created inheriting owner/group and setting permissions to SSH_DIR_PERM.
      #
      # @param path [String] User's home directory
      def write_keys
        remove_authorized_keys_file
        return if keys.empty?
        if !FileUtils::Exists(home)
          log.error("Home directory '#{home}' does not exist!")
          raise HomeDoesNotExist, home
        end
        user = FileUtils::GetOwnerUserID(home)
        group = FileUtils::GetOwnerGroupID(home)
        create_ssh_dir(user, group)
        write_file(user, group)
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
      def ssh_dir_path
        @ssh_dir_path ||= File.join(home, SSH_DIR)
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
      def authorized_keys_path
        @authorized_keys_path ||= File.join(ssh_dir_path, AUTHORIZED_KEYS_FILE)
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
      def create_ssh_dir(user, group)
        if FileUtils::Exists(ssh_dir_path)
          raise NotRegularSSHDirectory, ssh_dir_path unless FileUtils::IsDirectory(ssh_dir_path)
          return ssh_dir_path
        end
        ret = SCR.Execute(Path.new(".target.mkdir"), ssh_dir_path)
        log.info("Creating SSH directory: #{ret}")
        raise CouldNotCreateSSHDirectory, ssh_dir_path unless ret
        FileUtils::Chown("#{user}:#{group}", ssh_dir_path, false) &&
          FileUtils::Chmod(SSH_DIR_PERMS, ssh_dir_path, false)
      end

      # Write authorized keys file
      #
      # @param path  [String] Path to file/directory
      # @param user  [Fixnum] Users's UID
      # @param group [Fixnum] Group's GID
      # @param perms [String] Permissions (in form "0700")
      def write_file(owner, group)
        file = SSHAuthorizedKeysFile.new(authorized_keys_path)
        file.keys = keys
        log.info "Writing #{keys.size} keys in #{authorized_keys_path}"
        file.save && FileUtils::Chown("#{owner}:#{group}", authorized_keys_path, false)
      rescue SSHAuthorizedKeysFile::NotRegularFile
        raise NotRegularAuthorizedKeysFile, authorized_keys_path
      end

      # Remove the authorized keys file
      def remove_authorized_keys_file
        return unless FileUtils::Exists(authorized_keys_path)
        SCR.Execute(Path.new(".target.remove"), authorized_keys_path)
      end
    end
  end
end
