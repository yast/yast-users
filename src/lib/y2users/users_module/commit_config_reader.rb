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
require "y2users/commit_config_collection"
require "y2users/commit_config"

Yast.import "Users"

module Y2Users
  module UsersModule
    # Class for reading the commit configs from Yast::Users module
    #
    # @see CommitConfig
    class CommitConfigReader
      # Generates a collection of commit configs with the information from YaST::Users module
      #
      # @return [CommitConfigCollection]
      def read
        CommitConfigCollection.new.tap do |collection|
          users.each do |user|
            collection.add(commit_config(user))
          end
          removed_users.each do |user|
            update_user(user, collection)
          end
        end
      end

    private

      # Local users from the Yast::Users module
      #
      # @return [Array<Hash>]
      def users
        Yast::Users.GetUsers("uid", "local").values +
          Yast::Users.GetUsers("uid", "system").values
      end

      # Removed local users from the Yast::Users module
      #
      # @return [Array<Hash>]
      def removed_users
        (Yast::Users.RemovedUsers["local"] || {}).values +
          (Yast::Users.RemovedUsers["system"] || {}).values
      end

      # Updates existing commit config or creates a new one
      def update_user(user, collection)
        name = user["uid"]
        config = collection.by_username(name)
        if !config
          config = CommitConfig.new
          config.username = name
          collection.add(config)
        end

        config.remove_home = user["delete_home"]

        nil
      end

      # Generates a commit config from the given user
      #
      # @param user [Hash] a user representation in the format used by Yast::Users
      # @return [CommitConfig]
      def commit_config(user)
        CommitConfig.new.tap do |config|
          config.username = user["uid"]
          config.home_without_skel = user["no_skeleton"]
          config.move_home = move_home?(user)
          config.adapt_home_ownership = user["chown_home"]
        end
      end

      # Whether the home should be moved
      #
      # @param user [Hash] a user representation in the format used by Yast::Users
      # @return [Boolean]
      def move_home?(user)
        # Surprisingly, when a user is edited, the "org_homeDirectory" attribute does not contain
        # the original home value but the current one (i.e., the same value as "homeDirectory"). It
        # is more reliable to check the old value from the "org_user" hash.
        previous_home = user_attr(user.fetch("org_user", {}), "homeDirectory")
        home = user_attr(user, "homeDirectory")

        return false if previous_home.nil? || home.nil?

        user["modified"] == "edited" && previous_home != home && user["create_home"]
      end

      # Value of the given attribute
      #
      # @param user [Hash] a user representation in the format used by Yast::Users
      # @param attr [#to_s] name of the attribute
      #
      # @return [String, nil] nil if the value is missing or empty
      def user_attr(user, attr)
        value = user[attr.to_s]
        return nil if value == ""

        value
      end
    end
  end
end
