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
require "abstract_method"
require "y2users/config"
require "y2users/parsers/group"
require "y2users/parsers/passwd"
require "y2users/parsers/shadow"

module Y2Users
  module Linux
    # Base class for reading the system configuration
    class BaseReader
      include Yast::Logger

      # Generates a new config with the information from the system
      #
      # @return [Config]
      def read
        Config.new.tap do |config|
          read_elements(config)
          read_passwords(config)
        end
      end

    private

      # Reads the users and groups
      #
      # @param config [Config]
      def read_elements(config)
        elements = read_users + read_groups

        config.attach(elements)
      end

      # Parses the content retrieved by {#load_users} and returns a collection of users
      #
      # @see Parsers::Passwd#parse
      # @return [Array<Y2Users::User>]
      def read_users
        parser = Parsers::Passwd.new
        parser.parse(load_users)
      end

      # @!method load_users
      #   @return [String] loaded users from the system
      abstract_method :load_users

      # Parses the content retrieved by {#load_groups} and returns a collection of groups
      #
      # @see Parsers::Group#parse
      # @return [Array<Y2Users::Group>]
      def read_groups
        parser = Parsers::Group.new
        parser.parse(load_groups)
      end

      # @!method load_groups
      #   @return [String] loaded groups from the system
      abstract_method :load_groups

      # Parses the content retrieved by {#load_passwords} and sets user passwords
      #
      # @see Parsers::Shadow#parse
      # @return [Hash<String, Y2Users::Password>]
      def read_passwords(config)
        parser = Parsers::Shadow.new

        passwords = parser.parse(load_passwords)
        passwords.each_pair do |name, password|
          user = config.users.by_name(name)
          if !user
            log.warn "Found password for non existing user #{name}."
            next
          end

          user.password = password
        end
      end

      # @!method load_passwords
      #   @return [String] loaded passwords from the system
      abstract_method :load_passwords
    end
  end
end
