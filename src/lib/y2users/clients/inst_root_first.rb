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

require "yast"
require "y2users"
require "y2users/users_simple"
require "users/dialogs/inst_root_first"

Yast.import "UsersSimple"

module Y2Users
  # YaST "clients" are the CLI entry points
  module Clients
    # A client for displaying and managing the root user configuration
    class InstRootFirst
      # Runs the client
      def run
        result = Yast::InstRootFirstDialog.new(root_user).run

        Y2Users::UsersSimple::Writer.new(users_config).write if result == :next

        result
      end

    private

      # Config object holding the users and passwords
      #
      # @return [Y2Users::Config]
      def users_config
        @users_config ||= Y2Users::UsersSimple::Reader.new.read
      end

      # The root user
      #
      # @return [Y2Users::User]
      def root_user
        users_config.users.root
      end
    end
  end
end
