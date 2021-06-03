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

module Y2Users
  module Linux
    # Configures the login settings in the target system according to a given {LoginConfig} object
    class LoginConfigWriter
      Yast.import "Autologin"

      # Constructor
      #
      # @param login [LoginConfig] see #login_config
      def initialize(login)
        @login_config = login
      end

      # Performs the changes in the system
      def write
        return unless login_config

        # resetting Autologin settings
        Yast::Autologin.Disable

        Yast::Autologin.user = login_config.autologin_user&.name.to_s
        Yast::Autologin.pw_less = login_config.passwordless?
        Yast::Autologin.Use(true)

        # The parameter received by Autologin#Write is obsolete and it has no effect.
        Yast::Autologin.Write(nil)
      end

    private

      # Object containing the login settings to be written
      #
      # @return [LoginConfig, nil] nil if there is nothing to write
      attr_reader :login_config
    end
  end
end
