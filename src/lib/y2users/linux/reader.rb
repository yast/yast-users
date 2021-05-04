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
require "date"

require "y2users/group"
require "y2users/parsers/passwd"
require "y2users/password"

module Y2Users
  module Linux
    # Reads users configuration from the system using getent utility.
    class Reader
      include Yast::Logger

      def read_to(config)
        config.users = read_users(config)
        config.groups = read_groups(config)
        # read passwords after user, as user has to exist in advance
        read_passwords(config)
      end

    private

      def read_users(config)
        getent = Yast::Execute.on_target!("/usr/bin/getent", "passwd", stdout: :capture)
        parser = Parsers::Passwd.new

        parser.parse(getent)
      end

      GROUP_MAPPING = {
        "name"   => 0,
        "passwd" => 1,
        "gid"    => 2,
        "users"  => 3
      }.freeze

      def read_groups(config)
        getent = Yast::Execute.on_target!("/usr/bin/getent", "group", stdout: :capture)
        getent.lines.map do |line|
          values = line.chomp.split(":")
          Group.new(
            config,
            values[GROUP_MAPPING["name"]],
            gid:        values[GROUP_MAPPING["gid"]],
            users_name: values[GROUP_MAPPING["users"]]&.split(",") || []
          )
        end
      end

      SHADOW_MAPPING = {
        "username"           => 0,
        "value"              => 1,
        "last_change"        => 2,
        "minimum_age"        => 3,
        "maximum_age"        => 4,
        "warning_period"     => 5,
        "inactivity_period"  => 6,
        "account_expiration" => 7
      }.freeze

      def read_passwords(config)
        getent = Yast::Execute.on_target!("/usr/bin/getent", "shadow", stdout: :capture)
        getent.lines.each do |line|
          password = parse_getent_password(config, line)
          user = config.users.find { |u| u.name == password.name }
          if !user
            log.warn "Found password for non existing user #{password.name}."
            next
          end

          user.password = password
        end
      end

      def parse_getent_password(config, line)
        values = line.chomp.split(":")
        max_age = values[SHADOW_MAPPING["maximum_age"]]
        inactivity_period = values[SHADOW_MAPPING["inactivity_period"]]
        expiration = parse_account_expiration(values[SHADOW_MAPPING["account_expiration"]])
        Password.new(
          config,
          values[SHADOW_MAPPING["username"]],
          value:              PasswordEncryptedValue.new(values[SHADOW_MAPPING["value"]]),
          last_change:        parse_last_change(values[SHADOW_MAPPING["last_change"]]),
          minimum_age:        values[SHADOW_MAPPING["minimum_age"]].to_i,
          maximum_age:        max_age&.to_i,
          warning_period:     values[SHADOW_MAPPING["warning_period"]].to_i,
          inactivity_period:  inactivity_period&.to_i,
          account_expiration: expiration
        )
      end

      def parse_last_change(value)
        return nil if !value || value.empty?

        return :force_change if value == "0"

        # last_change is days till unix start 1970, so we expand it to number of seconds
        unix_time = value.to_i * 24 * 60 * 60
        Date.strptime(unix_time.to_s, "%s")
      end

      def parse_account_expiration(value)
        return nil if !value || value.empty?

        # last_change is days till unix start 1970, so we expand it to number of seconds
        unix_time = value.to_i * 24 * 60 * 60
        Date.strptime(unix_time.to_s, "%s")
      end
    end
  end
end
