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

module Y2Users
  # Represents user groups on system.
  class Group
    # @return [Y2Users::Config] reference to configuration in which it lives
    attr_reader :config

    # @return [String] group name
    attr_reader :name

    # @return [String, nil] group id  or nil if it is not yet assigned.
    attr_reader :gid

    # @return [Array<String>] list of user names
    # @note to get list of users in given group use method #users
    attr_reader :users_name

    # @return[:local, :ldap, :unknown] where is user defined
    attr_reader :source

    # @see respective attributes for possible values
    def initialize(config, name, gid: nil, users_name: [], source: :unknown)
      @config = config
      @name = name
      @gid = gid
      @users_name = users_name
      @source = source
    end

    # @return [Array<Y2Users::User>] all users in this group, including ones that
    # has it as primary group
    def users
      config.users.select { |u| u.gid == gid || users_name.include?(u.name) }
    end

    ATTRS = [:name, :gid, :users_name].freeze

    # Clones group to different configuration object.
    # @return [Y2Users::Group] newly cloned group object
    def clone_to(config)
      attrs = ATTRS.each_with_object({}) { |a, r| r[a] = public_send(a) }
      attrs.delete(:name) # name is separate argument
      self.class.new(config, name, attrs)
    end

    # Compares group object if all attributes are same excluding configuration reference.
    # @return [Boolean] true if it is equal
    def ==(other)
      # do not compare configuration to allow comparison between different configs
      ATTRS.all? { |a| public_send(a) == other.public_send(a) }
    end
  end
end
