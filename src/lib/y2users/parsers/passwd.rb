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

require "y2users/user"

module Y2Users
  module Parsers
    # Parses passwd style string and return users defined in it
    class Passwd
      # Mapping of attributes to index in passwd file
      PASSWD_MAPPING = {
        "name"   => 0,
        "passwd" => 1,
        "uid"    => 2,
        "gid"    => 3,
        "gecos"  => 4,
        "home"   => 5,
        "shell"  => 6
      }.freeze

      # Parses content and returns users defined there without password value.
      # @param content [String]
      # @return [Array<User>]
      def parse(content)
        content.lines.map do |line|
          values = line.chomp.split(":")
          gecos = values[PASSWD_MAPPING["gecos"]] || ""
          username = values[PASSWD_MAPPING["name"]]
          user = User.new(username)
          user.uid =   values[PASSWD_MAPPING["uid"]]
          user.gid =   values[PASSWD_MAPPING["gid"]]
          user.shell = values[PASSWD_MAPPING["shell"]]
          user.gecos = values[PASSWD_MAPPING["gecos"]].to_s.split(",")
          user.home =  values[PASSWD_MAPPING["home"]]
          user
        end
      end
    end
  end
end
