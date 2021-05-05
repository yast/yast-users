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
require "y2users/user"
require "y2users/password"

module Y2Users
  module Linux
    # Reads users configuration from the system using getent utility.
    class Reader
      include Yast::Logger

      def read_to(config)
        config.attach(users + groups)
      end

    private

      PASSWD_MAPPING = {
        "name"   => 0,
        "passwd" => 1,
        "uid"    => 2,
        "gid"    => 3,
        "gecos"  => 4,
        "home"   => 5,
        "shell"  => 6
      }.freeze
      private_constant :PASSWD_MAPPING

      # Returns the collection of users retrieved via getent
      #
      # @return [Array<User>]
      def users
        getent = Yast::Execute.on_target!("/usr/bin/getent", "passwd", stdout: :capture)
        getent.lines.map do |line|
          values = line.chomp.split(":")
          username = values[PASSWD_MAPPING["name"]]
          user = User.new(username)
          user.uid =   values[PASSWD_MAPPING["uid"]]
          user.gid =   values[PASSWD_MAPPING["gid"]]
          user.shell = values[PASSWD_MAPPING["shell"]]
          user.gecos = values[PASSWD_MAPPING["gecos"]].to_s.split(",")
          user.home =  values[PASSWD_MAPPING["home"]]
          user.password = passwords[username]
          user
        end
      end

      GROUP_MAPPING = {
        "name"   => 0,
        "passwd" => 1,
        "gid"    => 2,
        "users"  => 3
      }.freeze
      private_constant :GROUP_MAPPING

      # Returns the collection of groups retrieved via getent
      #
      # @return [Array<Group>]
      def groups
        getent = Yast::Execute.on_target!("/usr/bin/getent", "group", stdout: :capture)
        getent.lines.map do |line|
          values = line.chomp.split(":")
          group = Group.new(values[GROUP_MAPPING["name"]])
          group.gid = values[GROUP_MAPPING["gid"]]
          group.users_name = values[GROUP_MAPPING["users"]].to_s.split(",")
          group
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
      private_constant :SHADOW_MAPPING

      def passwords
        return @passwords if @passwords

        getent = Yast::Execute.on_target!("/usr/bin/getent", "shadow", stdout: :capture)
        @passwords = getent.lines.each_with_object({}) do |line, collection|
          values = line.chomp.split(":")

          collection[values[SHADOW_MAPPING["username"]]] = parse_getent_password(values)
        end
      end

      def parse_getent_password(values)
        max_age = values[SHADOW_MAPPING["maximum_age"]]
        inactivity_period = values[SHADOW_MAPPING["inactivity_period"]]
        expiration = parse_account_expiration(values[SHADOW_MAPPING["account_expiration"]])

        password_value = PasswordEncryptedValue.new(values[SHADOW_MAPPING["value"]])
        password = Password.new(password_value)
        password.last_change = parse_last_change(values[SHADOW_MAPPING["last_change"]])
        password.minimum_age = values[SHADOW_MAPPING["minimum_age"]].to_i
        password.maximum_age = max_age&.to_i
        password.warning_period = values[SHADOW_MAPPING["warning_period"]].to_i
        password.inactivity_period = inactivity_period&.to_i
        password.account_expiration = expiration
        password
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
