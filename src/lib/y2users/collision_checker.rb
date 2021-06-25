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

require "y2issues"

module Y2Users
  # Internal class to check if there are collisions in config.
  # This is not part of the stable API.
  class CollisionChecker
    include Yast::I18n

    # Constructor
    #
    # @param config [Y2Users::Config] config to detect colliding ids
    def initialize(config)
      textdomain "users"
      @config = config
    end

    # Returns a list of issues found while checking collisions
    #
    # @return [Y2Issues::List]
    def issues
      list = Y2Issues::List.new

      list.concat(duplicate_users_ids)
      list.concat(duplicate_users_names)
      list.concat(duplicate_groups_ids)
      list.concat(duplicate_groups_names)

      list
    end

  private

    # @return [Y2Users::Config] config to validate
    attr_reader :config

    def duplicate_users_ids
      duplicate_issues(config.users, :uid) do |uid, users|
        msg = format(_("Users %{users} have same UID %{uid}."),
          users: users.map(&:name).join(", "),
          uid:   uid)
        Y2Issues::Issue.new(msg, severity: :warn)
      end
    end

    def duplicate_users_names
      duplicate_issues(config.users, :name) do |name, _users|
        msg = format(_("User %{user} is specified multiple times."),
          user: name)
        Y2Issues::Issue.new(msg, severity: :warn)
      end
    end

    def duplicate_groups_ids
      duplicate_issues(config.groups, :gid) do |gid, groups|
        msg = format(_("Groups %{groups} have same GID %{gid}."),
          groups: groups.map(&:name).join(", "),
          gid:    gid)
        Y2Issues::Issue.new(msg, severity: :warn)
      end
    end

    def duplicate_groups_names
      duplicate_issues(config.groups, :name) do |name, _groups|
        msg = format(_("Group %{name} is specified multiple times."),
          name: name)
        Y2Issues::Issue.new(msg, severity: :warn)
      end
    end

    def duplicate_issues(elements, attr, &block)
      grouped = elements.all.group_by(&attr)
      # missing or invalid values are caught by other validation, so skip it here
      grouped.delete(nil)
      grouped.delete("")
      grouped.select! { |_k, v| v.size > 1 } # more them one, so collision

      issues = grouped.map do |k, v|
        block.call(k, v)
      end

      Y2Issues::List.new(issues)
    end
  end
end
