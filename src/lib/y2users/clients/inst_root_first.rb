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
require "users/dialogs/inst_root_first"

module Y2Users
  # YaST "clients" are the CLI entry points
  module Clients
    # A client for displaying and managing the root user configuration
    class InstRootFirst
      Yast.import "GetInstArgs"

      # Runs the client
      def run
        return :auto unless run?

        result = Yast::InstRootFirstDialog.new(root_user).run

        update_target_config if result == :next

        result
      end

    private

      # Whether to run the client
      #
      # Note that this client should be automatically skipped when root was configured to use the
      # same password as a user.
      #
      # @return [Boolean]
      def run?
        force? || !root_password_from_user?
      end

      def force?
        Yast::GetInstArgs.argmap.fetch("force", false)
      end

      # Whether root is configured to use the same password as a user
      #
      # @return [Boolean]
      def root_password_from_user?
        root_password = root_user.password&.value

        return false unless root_password

        users.any? { |u| u.password&.value == root_password }
      end

      # Updates the target config to reflect the changes in the root user
      def update_target_config
        config.attach(root_user) unless root_user.attached?

        ConfigManager.instance.target = config
      end

      # All users from the target config without the root user
      #
      # @return [Y2Users::UsersCollection]
      def users
        config.users.reject(&:root?)
      end

      # Root user from the target config, or a new root user if there is no root yet
      #
      # @return [Y2Users::User]
      def root_user
        @root_user ||= config.users.root || User.create_root
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
