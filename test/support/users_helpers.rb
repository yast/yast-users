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

Yast.import "UsersSimple"

module Yast
  module RSpec
    module UsersHelpers
      # Resets Yast::UsersSimple to an initial state
      def reset_users_simple
        UsersSimple.SetUsers([])
        UsersSimple.SetRootPassword("")
        UsersSimple.SetAutologinUser("")
      end

      # Reads authorized keys from given path
      #
      # @param path [String] the path for reading authorized keys
      def authorized_keys_from(path)
        file_path = File.join(path, ".ssh", "authorized_keys")
        File.read(file_path).lines.map(&:strip).grep(/ssh-/)
      end
    end
  end
end
