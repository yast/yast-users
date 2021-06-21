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

require "y2users"
require "users/dialogs/inst_user_first"

module Y2Users
  # YaST "clients" are the CLI entry points
  module Clients
    # A client for displaying and managing the user configuration
    class InstUserFirst
      # Runs the client
      #
      # @return [Symbol] option selected in the dialog (e.g., :next, :back, etc)
      def run
        result = Yast::InstUserFirstDialog.new(config, user: user).run

        ConfigManager.instance.target = config if result == :next

        result
      end

    private

      # User in which to work on
      #
      # During the installation, the target config only contains the root user and the users to
      # create.
      #
      # @return [User, nil]
      def user
        @user ||= config.users.reject(&:root?).first
      end

      # A copy of the current target config, or a new config if there is no target yet
      #
      # @return [Y2Users::Config]
      def config
        @config ||= ConfigManager.instance.target&.copy || Config.new
      end
    end
  end
end
