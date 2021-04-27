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
  # Holds references to elements of user configuration like users or groups.
  # Class itself holds references to different configuration instances.
  # TODO: write example
  class Config
    class << self
      def get(name)
        @register ||= {}
        @register[name]
      end

      def register(config)
        @register ||= {}
        @register[config.name] = config
      end

      def remove(config)
        name = config.is_a?(self) ? config.name : config

        @register.delete(name)
      end

      def system(reader: nil, force_read: false)
        res = get(:system)
        return res if res && !force_read

        if !reader
          require "y2users/linux/reader"
          reader = Linux::Reader.new
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

    def initialize(name, users: [], groups: [])
      @name = name
      @users = users
      @groups = groups
      self.class.register(self)
    end

    def clone_as(name)
      config = self.class.new(name)
      config.users = users.map { |u| u.clone_to(config) }
      config.groups = groups.map { |g| g.clone_to(config) }

      config
    end
  end
end
