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

require "y2users/config"
require "y2users/parsers/group"
require "y2users/parsers/passwd"
require "y2users/parsers/shadow"

module Y2Users
  module Linux
    # Reads local users configuration from the system using /etc files.
    class LocalReader
      include Yast::Logger

      def initialize(source_dir = "/")
        @source_dir = source_dir
      end

      # Generates a new config with the users and groups from the /etc files
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

      attr_reader :source_dir

      def read_users
        content = File.read(File.join(source_dir, "/etc/passwd"))
        parser = Parsers::Passwd.new

        parser.parse(content)
      end

      def read_groups
        content = File.read(File.join(source_dir, "/etc/group"))
        parser = Parsers::Group.new

        parser.parse(content)
      end

      def read_passwords(config)
        content = File.read(File.join(source_dir, "/etc/shadow"))
        parser = Parsers::Shadow.new

        passwords = parser.parse(content)
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
