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

module Y2Users
  # Class to manage the login configuration
  #
  # Note that a {Config} use an object of this class to manage the login settings, see
  # {Config#login}
  class LoginConfig
    # User for autologin
    #
    # @return [User, nil] nil if no autologin
    attr_accessor :autologin_user

    # Whether users can loggin without entering the password
    #
    # @return [Boolean]
    attr_writer :passwordless

    def initialize
      @autologin_user = nil
      @passwordless = false
    end

    # Whether autologin is configured
    #
    # @return [Boolean]
    def autologin?
      !autologin_user.nil?
    end

    # Whether users can login without entering the password
    #
    # @return [Boolean]
    def passwordless?
      @passwordless
    end

    # Copies the login configuration into the given config
    #
    # @param config [Config] The config is modified
    def copy_to(config)
      config.login = clone
      config.login.autologin_user = config.users.by_name(autologin_user.name) if autologin?
    end
  end
end
