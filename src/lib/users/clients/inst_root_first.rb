# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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
require "users/dialogs/inst_root_first"
require "users/public_key_loader"
Yast.import "SSHAuthorizedKeys"

module Y2Users
  module Clients
    class InstRootFirst
      def main
        import_public_keys
        Yast::InstRootFirstDialog.new.run
      end

    private

      # Import public keys from an USB device
      def import_public_keys
        keys = Y2Users::PublicKeyLoader.new.from_usb_stick
        Yast::SSHAuthorizedKeys.import_keys("/root", keys) unless keys.empty?
      end
    end
  end
end
