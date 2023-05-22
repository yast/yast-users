# Copyright (c) [2021-2023] SUSE LLC
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
require "y2users/linux/action"
require "y2users/linux/root_path"

module Y2Users
  module Linux
    # Action for deleting an existing user
    class DeleteUserAction < Action
      include Yast::I18n
      include Yast::Logger
      include RootPath

      # Constructor
      #
      # @see Action
      # @see #remove_home?
      def initialize(user, remove_home: true, root_path: nil)
        textdomain "users"

        super(user)
        @remove_home = remove_home
        @root_path = root_path
      end

    private

      alias_method :user, :action_element

      # Whether to also remove the user home directory
      #
      # @return [Boolean]
      def remove_home?
        !!@remove_home
      end

      # Command for deleting a user
      USERDEL = "/usr/sbin/userdel".freeze
      private_constant :USERDEL

      # @see Action#run_action
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
        options = root_path_options
        options << "--remove" if remove_home?

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
