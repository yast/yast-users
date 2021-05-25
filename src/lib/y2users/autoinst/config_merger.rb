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
require "y2users"

module Y2Users
  module Autoinst
    # Helper class to merge users and groups from one config into another config
    #
    # When updating a current user/gruop:
    #
    # * It keeps the original uid/gid.
    # * If a property is not defined in the imported user, it falls back to the
    #   original value or, if missing too, the default value for that property.
    class ConfigMerger < Y2Users::ConfigMerger
      # Merges an element into a config
      #
      # @param config [Config] This config is modified
      # @param element [User, Group]
      def merge_element(config, element)
        current_element = find_element(config, element)

        new_element = element.copy

        if current_element
          new_element.assign_internal_id(current_element.id)
          merge_attributes(current_element, new_element)
          config.detach(current_element)
        end

        config.attach(new_element)
      end

      # Merges one element into another
      #
      # @param from [User, Group] Source element
      # @param to [User, Group] Target element. This element is modified.
      def merge_attributes(from, to)
        case from
        when User
          merge_users(from, to)
        when Group
          merge_groups(from, to)
        end
      end

      # Merges two users
      #
      # Only non-nil from the `to` user are considered.
      #
      # @param from [User] Source user
      # @param to [User] Target user. This user is modified.
      def merge_users(from, to)
        to.uid = from.uid
        to.gid = from.gid

        [:name, :shell, :home, :gecos, :source, :password].each do |attr|
          next unless to.public_send(attr).nil?

          to.public_send("#{attr}=", from.public_send(attr))
        end
      end

      # Merges two groups
      #
      # Only non-nil from the `to` group are considered.
      #
      # @param from [Group] Source group
      # @param to [Group] Target group. This group is modified.
      def merge_groups(from, to)
        to.gid = from.gid

        [:name, :users, :source].each do |attr|
          next unless to.public_send(attr).nil?

          to.public_send("#{attr}=", from.public_send(attr))
        end
      end
    end
  end
end
