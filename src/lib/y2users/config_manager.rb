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

module Y2Users
  # Holds references to different configuration instances.
  # It is not mandatory for config to be registered here.
  class ConfigManager
    class << self
      # @return [Hash<Symbol, Config> register of hold configs.
      def configs
        @configs ||= {}
      end

      def system(reader: nil, force_read: false)
        res = configs[:system]
        return res if res && !force_read

        if !reader
          require "y2users/linux/reader"
          reader = Linux::Reader.new
        end

        require "y2users/config"
        res = Config.new
        reader.read_to(res)
        configs[:system] = res

        res
      end
    end
  end
end
