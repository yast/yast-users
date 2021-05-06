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

module Y2Users
  # Mixin for user and password validations based on Y2Users for isntallation dialogs
  module InstUsersDialogHelper
    Yast.import "UI"
    Yast.import "Popup"
    Yast.import "Report"

  private

    # Config object holding the users and passwords to create
    #
    # @return [Y2Users::Config]
    def users_config
      return @users_config if @users_config

      @users_config = Y2Users::Config.new
      Y2Users::UsersSimple::Reader.new.read_to(@users_config)
      @users_config
    end

    # All users to be created
    #
    # @return [Array<Y2Users::User>]
    def users
      users_config.users.reject(&:root?)
    end

    # User to be created, useful during the :new_user action in which {#users}
    # is known to contain only one element
    #
    # @return [Y2Users::User]
    def user
      users.first
    end

    # Root users for which is possible to define the password during the :new_user action
    #
    # @return [Y2Users::User]
    def root_user
      @root_user ||= users_config.users.find(&:root?)
    end

    # The user on which to perform password validations
    #
    # It might be re-defined in the dialog
    #
    # @see #valid_user?
    # @see #valid_password?
    #
    # @return [Y2Users::User]
    def user_to_validate
      user
    end

    # Checks whether the information entered for the user is valid, reporting the problem to
    # the user otherwise
    #
    # @return [Boolean]
    def valid_user?
      issue = user.issues.first
      if issue
        Yast::Report.Error(issue.message)
        focus_on(issue.location)
        return false
      end

      true
    end

    # Sets the UI focus in the widget corresponding to the given issue location
    #
    # @param location [Y2Issues::Location]
    def focus_on(location)
      id = (location.path == "name") ? :username : :full_name
      Yast::UI.SetFocus(Id(id))
    end

    # Checks whether the entered password is acceptable, reporting fatal problems to the user and
    # asking for confirmation for the non-fatal ones
    #
    # @return [Boolean]
    def valid_password?
      issues = user_to_validate.password_issues
      return true if issues.empty?

      Yast::UI.SetFocus(Id(:pw1))

      fatal = issues.find(&:fatal?)
      if fatal
        Yast::Report.Error(fatal.message)
        return false
      end

      message = issues.map(&:message).join("\n\n") + "\n\n" + _("Really use this password?")
      Yast::Popup.YesNo(message)
    end
  end
end
