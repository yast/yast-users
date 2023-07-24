# Copyright (c) [2023] SUSE LLC
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

require "tempfile"

module Y2Users
  module Linux
    # Mixin for writers that may need to create a temporary directory containing a ./etc
    # subdirectory with the shadow files (passwd, shadow and groups) as a hacky and indirect
    # way to point to the real location of those files.
    #
    # For the rationale, see the documentation of {RootPath} and bsc#1206627.
    #
    # This mixin will disappear once the shadow tools gain the ability to specify the exact
    # location of the passwd, shadow and groups files.
    module TemporaryRoot
      # Path of the existing temporary directory
      #
      # @return [String, nil] nil if the temporary directory doesn't exist because it was not
      #   needed or because it was already deleted
      attr_reader :temporary_root

      # Creates a temporary directory with a ./etc symlink pointing to the given path and executes
      # the given block
      #
      # @param real_path [String] directory with the content of the simulated /etc
      def with_temporary_root(real_path, &block)
        if real_path.nil? || real_path.empty?
          block.call
        else
          Dir.mktmpdir do |dir|
            @temporary_root = dir
            File.symlink(real_path, File.join(dir, "etc"))
            block.call
          end
        end
      ensure
        @temporary_root = nil
      end
    end
  end
end
