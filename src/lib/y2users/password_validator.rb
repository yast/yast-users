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
require "users/local_password"
require "y2users/validation_config"

module Y2Users
  # Internal class to validate the attributes of a {Password} object.
  # This is not part of the stable API.
  class PasswordValidator
    Yast.import "UsersSimple"

    LOCATION = "field:password.content".freeze
    private_constant :LOCATION

    # Constructor
    #
    # @param user [Y2Users::User] see {#user}
    def initialize(user)
      @user = user
    end

    # @return [Y2Issues::List]
    def issues
      list = Y2Issues::List.new

      return list unless password&.value&.plain?

      err = Yast::UsersSimple.CheckPassword(content, "local")
      if !err.empty?
        list << Y2Issues::Issue.new(err, location: LOCATION, severity: :fatal)
        # We already have a fatal error, no need to continue. Subsequent steps may need
        # to load the cracklib extension.
        return list
      end

      # This may load the cracklib extension during installation, which temporarily shows
      # an informative pop-up
      local_passwd = ::Users::LocalPassword.new(username: user.name, plain: content)
      if !local_passwd.valid?
        local_passwd.errors.each do |error|
          list << Y2Issues::Issue.new(error, location: LOCATION)
        end
      end

      list
    end

  private

    # @return [Y2Users::User] user containing the password to validate
    attr_reader :user

    # @return [Y2Users::Password] password to validate
    def password
      user.password
    end

    # @return [String, nil] password content
    def content
      password&.value&.content
    end

    # @return [ValidationConfig]
    def config
      @config ||= ValidationConfig.new
    end
  end
end
