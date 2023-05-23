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

module Y2Users
  module Linux
    # Mixin for actions that may need to execute shadow commands (useradd, chpasswd, etc.) on files
    # (passwd, shadow and groups) located at an alternative path.
    #
    # Currently the shadow tools do not allow to set the exact location of the files. Instead, they
    # allow to define the path to what would be the root directory of a system. That implies the
    # tools always assume an extra ./etc directory within the provided path.
    #
    # The shadow commands provide both a --prefix argument and a --root one to specify such a root
    # directory. YaST uses --prefix because the argument --root assumes the root directory contains
    # a full system in which the commands may even try to authenticate.
    #
    # For more information, see bsc#1206627
    #
    # The user of the mixin is expected to set its instance variable @root_path to a non-null value
    # in order to indicate that the commands should indeed act on that non-default location.
    #
    # Hopefully, this mixin will disappear (maybe substituted by a similar one) once the shadow
    # tools gain the ability to specify the exact location of the passwd, shadow and groups files.
    module RootPath
      # Directory containing a ./etc subdirectory with the files to be modified by the command(s)
      #
      # @return [String, nil] nil to use the default location
      attr_reader :root_path

      # Options to be included in the list of arguments passed to the command(s)
      #
      # @return [Array<String>] an empty array if #root_path is set to nil
      def root_path_options
        return [] if root_path.nil? || root_path.empty?

        ["--prefix", root_path]
      end
    end
  end
end
