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
require "users/ssh_authorized_keyring"

module Y2Users
  module Linux
    # Base class for reading users configuration from the system
    class BaseReader
      include Yast::Logger

      # Generates a new config with the users and groups from the read content
      #
      # @return [Config]
      def read
        elements = read_users + read_groups

        config = Config.new.attach(elements)

        # read passwords after user, as user has to exist in advance
        read_passwords(config)

        # read authorized keys
        read_authorized_keys(config)

        config
      end

    private

      # Parses the content retrieved by {#load_users} and returns a collection of users
      #
      # @see Parsers::Passwd#parse
      # @return [Array<Y2Users::User>]
      def read_users
        parser = Parsers::Passwd.new
        parser.parse(load_users)
      end

      # Loads users from the system
      #
      # To be implemented by the subclasses
      #
      # @return [String]
      def load_users
        raise NotImplementedError
      end

      # Parses the content retrieved by {#load_groups} and returns a collection of groups
      #
      # @see Parsers::Group#parse
      # @return [Array<Y2Users::Group>]
      def read_groups
        parser = Parsers::Group.new
        parser.parse(load_groups)
      end

      # Loads groups from the system
      #
      # To be implemented by the subclasses
      #
      # @return [String]
      def load_groups
        raise NotImplementedError
      end

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
            log.warn "Found password for non existing user #{password.name}."
            next
          end

          user.password = password
        end
      end

      # Loads user passwords from the system
      #
      # To be implemented by the subclasses
      #
      # @return [String]
      def load_passwords
        raise NotImplementedError
      end

      # Reads users authorized keys
      #
      # @see Yast::Users::SSHAuthorizedKeyring#read_keys
      # @return [Array<Y2Users::User>]
      def read_authorized_keys(config)
        config.users.each do |user|
          next unless user.home

          user.authorized_keys = Yast::Users::SSHAuthorizedKeyring.new(user.home).read_keys
        end
      end
    end
  end
end
