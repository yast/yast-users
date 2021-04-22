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

Yast.import "UsersSimple"

module Y2Users
  module UsersSimple
    # Class for reading users configuration from old Yast Module UsersSimple.
    class Reader
      def read_to(configuration)
        users = Yast::UsersSimple.GetUsers
        # TODO: only created users, not imported ones for now
        users.each do |user|
          configuration.users << User.new(configuration, user["uid"], gecos: [user["cn"]])
          # lets just use the strongest available
          configuration.passwords << Password.new(configuration, user["uid"],
            value: Yast::Builtins.cryptsha512(user["userPassword"]))
        end
      end
    end
  end
end
