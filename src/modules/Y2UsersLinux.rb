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
require "y2users/linux/useradd_config_reader"

module Yast
  # Module to make possible for Yast::Users to use some of the Y2Users::Linux components, like
  # the {Y2Users::Linux::UseraddConfigReader}
  class Y2UsersLinuxClass < Module
    EXPORTED_USERADD_ATTRS =
      ["group", "home", "inactivity_period", "expiration", "shell", "umask"].freeze
    private_constant :EXPORTED_USERADD_ATTRS

    # Reads the defaults for useradd
    #
    # These values are used by {Yast::Users} for initializing the UI fields
    #
    # @return [Hash<String, String>]
    def read_useradd_config
      useradd_config = Y2Users::Linux::UseraddConfigReader.new.read

      EXPORTED_USERADD_ATTRS.each_with_object({}) do |attr, result|
        result[attr] = useradd_config.public_send(attr) || ""
      end
    end

    publish function: :read_useradd_config, type: "map ()"
  end

  Y2UsersLinux = Y2UsersLinuxClass.new
end
