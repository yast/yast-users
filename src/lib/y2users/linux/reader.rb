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

require "yast2/execute"
require "y2users/linux/base_reader"

module Y2Users
  module Linux
    # Reads users configuration from the system using `getent` command.
    class Reader < BaseReader
    private # rubocop:disable Layout/IndentationWidth

      # Loads entries from `passwd` database
      #
      # @see #getent
      # @return [String]
      def load_users
        getent("passwd")
      end

      # Loads entries from `group` database
      #
      # @see #getent
      # @return [String]
      def load_groups
        getent("group")
      end

      # Loads entries from `shadow` database
      #
      # @see #getent
      # @return [String]
      def load_passwords
        getent("shadow")
      end

      # Executes the `getent` command for getting entries for given Name Service Switch database
      #
      # @see https://www.man7.org/linux/man-pages/man1/getent.1.html
      #
      # @param database [String] a database supported by the Name Service Switch libraries
      # @return [String] the getent command output
      def getent(database)
        Yast::Execute.on_target!("/usr/bin/getent", database, stdout: :capture)
      end
    end
  end
end
