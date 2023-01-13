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
    # Some shadow commands provide both a --prefix argument and a --root one to specify such a root
    # directory. Other commands provide only the --root one. Since --prefix is more convenient for
    # the YaST purposes, that will be used by default unless another one is configured for the class
    # using the provided macro root_path_option.
    #
    # For more information, see bsc#1206627
    #
    # The user of the mixin is expected to set its instance variable @root_path to a non-null value
    # in order to indicate that the commands should indeed act on that non-default location.
    #
    # Hopefully, this mixin will disappear (maybe substituted by a similar one) once the shadow
    # tools gain the ability to specify the exact location of the passwd, shadow and groups files.
    module RootPath
      def self.included(base)
        base.extend(ClassMethods)
        base.root_path_option :prefix
      end

      # Directory containing a ./etc subdirectory with the files to be modified by the command(s)
      #
      # @return [String, nil] nil to use the default location
      attr_reader :root_path

      # Options to be included in the list of arguments passed to the command(s)
      #
      # @return [Array<String>] an empty array if #root_path is set to nil
      def root_path_options
        return [] if root_path.nil? || root_path.empty?

        ["--#{self.class.root_path_argument}", root_path]
      end

      # Class methods to be added
      module ClassMethods
        # Macro to redefine the name of the argument used to set the root path in the associated
        # command(s). Needed because some of the shadow tools do not provide a --prefix argument.
        #
        # @param name [String] name of the argument, typically :prefix or :root
        def root_path_option(name)
          @root_path_argument = name
        end

        # @see #root_path_option
        attr_reader :root_path_argument
      end
    end
  end
end
