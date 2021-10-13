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
require "yast/i18n"
require "yast2/execute"
require "y2issues/issue"
require "y2users/linux/user_action"

module Y2Users
  module Linux
    # Action for deleting an existing user
    class DeleteUserAction < UserAction
      include Yast::I18n
      include Yast::Logger

      # Constructor
      #
      # @see UserAction
      def initialize(user, commit_config = nil)
        textdomain "users"

        super
      end

    private

      # Command for deleting a user
      USERDEL = "/usr/sbin/userdel".freeze
      private_constant :USERDEL

      # @see UserAction#run_action
      #
      # Issues are generated when the user cannot be deleted.
      def run_action
        Yast::Execute.on_target!(USERDEL, *userdel_options, user.name)
        true
      rescue Cheetah::ExecutionFailed => e
        handle_error(e)
        false
      end

      # Generates options for `userdel`
      #
      # @return [Array<String>]
      def userdel_options
        options = []
        options << "--remove" if commit_config&.remove_home?

        options
      end

      # Handles the error
      #
      # An issue is generated.
      #
      # @param error [Cheetah::ExecutionFailed]
      def handle_error(error)
        issue = case error.status.exitstatus
        when 8
          logged_user_issue(error)
        when 12
          remove_file_issue(error)
        else
          delete_user_issue(error)
        end

        issues << issue

        log.error("Error deleting user '#{user.name}': #{error.stderr}")
      end

      # @return [Y2Issues::Issue]
      def logged_user_issue(_error)
        message = format(
          # TRANSLATORS: %{user} is replaced by a username
          _("The user %{user} cannot be deleted because is currently logged in"),
          user: user.name
        )

        Y2Issues::Issue.new(message)
      end

      # @param error [Cheetah::ExecutionFailed]
      # @return [Y2Issues::Issue]
      def remove_file_issue(error)
        message = format(
          # TRANSLATORS: %{user} is replaced by a username and %{error} is replaced by an error
          #   message.
          _("The home or mail spool of the user %{user} cannot be deleted: %{error}"),
          user:  user.name,
          error: error.stderr
        )

        Y2Issues::Issue.new(message)
      end

      # @param error [Cheetah::ExecutionFailed]
      # @return [Y2Issues::Issue]
      def delete_user_issue(error)
        message = format(
          # TRANSLATORS: %{user} is replaced by a username and %{error} is replaced by an error
          #   message.
          _("The user %{user} cannot be deleted: %{error}"),
          user:  user.name,
          error: error.stderr
        )

        Y2Issues::Issue.new(message)
      end
    end
  end
end
