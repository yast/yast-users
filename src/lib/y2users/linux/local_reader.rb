# Copyright (c) [2021] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "y2users/linux/base_reader"

module Y2Users
  module Linux
    # Reads local users configuration from the system using /etc files.
    class LocalReader < BaseReader
      # Constructor
      #
      # @param source_dir [String, Pathname] path of source directory for reading files
      def initialize(source_dir = "/")
        super()
        @source_dir = source_dir
      end

    private

      # Source directory for reading files content
      #
      # @see #load_file
      # @return [String, Pathname]
      attr_reader :source_dir

      # Loads the content of /etc/passwd file
      #
      # @return [String]
      def load_users
        load_file("/etc/passwd")
      end

      # Loads the content of /etc/group file
      #
      # @return [String]
      def load_groups
        load_file("/etc/group")
      end

      # Loads the content of /etc/shadow file
      #
      # @return [String]
      def load_passwords
        load_file("/etc/shadow")
      end

      # Loads the content of given file path within the {#source_dir}
      #
      # @param path [String, Pathname] the path to the file to be read
      # @return [String] the content of the read file
      def load_file(path)
        full_path = File.join(source_dir, path)

        if File.exist?(full_path)
          File.read(full_path)
        else
          log.error("File #{full_path} does not exist")
          ""
        end
      end
    end
  end
end
