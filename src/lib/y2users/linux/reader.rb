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

require "yast2/execute"
require "y2users/config"
require "y2users/parsers/group"
require "y2users/parsers/passwd"
require "y2users/parsers/shadow"

module Y2Users
  module Linux
    # Reads users configuration from the system using getent utility.
    class Reader
      include Yast::Logger

      # Generates a new config with the users and groups from the system
      #
      # @return [Config]
      def read
        elements = read_users + read_groups

        config = Config.new.attach(elements)

        # read passwords after user, as user has to exist in advance
        read_passwords(config)

        config
      end

    private

      def read_users
        getent = Yast::Execute.on_target!("/usr/bin/getent", "passwd", stdout: :capture)
        parser = Parsers::Passwd.new

        parser.parse(getent)
      end

      def read_groups
        getent = Yast::Execute.on_target!("/usr/bin/getent", "group", stdout: :capture)
        parser = Parsers::Group.new

        parser.parse(getent)
      end

      def read_passwords(config)
        getent = Yast::Execute.on_target!("/usr/bin/getent", "shadow", stdout: :capture)
        parser = Parsers::Shadow.new

        passwords = parser.parse(getent)
        passwords.each_pair do |name, password|
          user = config.users.by_name(name)
          if !user
            log.warn "Found password for non existing user #{password.name}."
            next
          end

          user.password = password
        end
      end
    end
  end
end
