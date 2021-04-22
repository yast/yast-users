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

module Y2User
  # Holds references to elements of user configuration like users, groups or passwords.
  # Class itself holds references to different configuration instances.
  # TODO: write example
  class Configuration
    class << self
      def get(name)
        @register ||= {}
        @register[name]
      end

      def register(configuration)
        @register ||= {}
        @register[configuration.name] = configuration
      end

      def remove(configuration)
        name = configuration.is_a?(self) ? configuration.name : configuration

        @register.delete(name)
      end

      def system(reader: nil, force_read: false)
        res = get(:system)
        return res if res && !force_read

        if !reader
          require "y2user/readers/getent"
          reader = Readers::Getent.new
        end

        # TODO: make system config immutable, so it cannot be modified directly
        res = new(:system)
        reader.read_to(res)

        res
      end
    end

    attr_reader :name
    attr_accessor :users
    attr_accessor :groups
    attr_accessor :passwords

    def initialize(name, users: [], groups: [], passwords: [])
      @name = name
      @users = users
      @groups = groups
      @passwords = passwords
      self.class.register(self)
    end

    def clone_as(name)
      configuration = self.class.new(name)
      configuration.users = users.map { |u| u.clone_to(configuration) }
      configuration.groups = groups.map { |g| g.clone_to(configuration) }
      configuration.passwords = passwords.map { |p| p.clone_to(configuration) }

      configuration
    end
  end
end
