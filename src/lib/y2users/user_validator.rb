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

require "y2issues"
require "y2users/validation_config"

module Y2Users
  # Internal class to validate the attributes of a {User} object.
  # This is not part of the stable API.
  class UserValidator
    Yast.import "UsersSimple"

    # Issue location describing the User#name attribute
    NAME_LOC = "field:name".freeze
    # Issue location describing the User#full_name attribute
    FULL_NAME_LOC = "field:full_name".freeze
    private_constant :NAME_LOC, :FULL_NAME_LOC

    # Constructor
    #
    # @param user [Y2Users::User] see {#user}
    def initialize(user)
      @user = user
    end

    # Returns a list of issues found while checking the user validity
    #
    # @param skip [Array<Symbol>] list of user attributes that should not be checked
    # @return [Y2Issues::List]
    def issues(skip: [])
      list = Y2Issues::List.new

      if !skip.include?(:name)
        err = Yast::UsersSimple.CheckUsernameLength(user.name)
        add_fatal_issue(list, err, NAME_LOC)

        err = Yast::UsersSimple.CheckUsernameContents(user.name, "")
        add_fatal_issue(list, err, NAME_LOC)

        # Yast::UsersSimple.CheckUsernameConflicts is currently used only when manually creating
        # the initial user during installation, it simply checks against a hard-coded list of
        # system user names that are expected to exist in a system right after installation.
        err = Yast::UsersSimple.CheckUsernameConflicts(user.name)
        add_fatal_issue(list, err, NAME_LOC)
      end

      if !skip.include?(:full_name)
        err = Yast::UsersSimple.CheckFullname(user.full_name)
        add_fatal_issue(list, err, FULL_NAME_LOC)
      end

      if !skip.include?(:password) && user.password
        user.password_issues.map do |issue|
          list << issue
        end
      end

      list
    end

  private

    # @return [Y2Users::User] user to validate
    attr_reader :user

    # @return [ValidationConfig]
    def config
      @config ||= ValidationConfig.new
    end

    # Adds a fatal issue to the given list to represent the given error, if any
    def add_fatal_issue(list, error, location)
      return if error.empty?

      list << Y2Issues::Issue.new(error, location: location, severity: :fatal)
    end
  end
end
