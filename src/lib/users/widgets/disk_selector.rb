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

require "cwm"
require "users/leaf_blk_device"

module Y2Users
  module Widgets
    # This widget allows to select a removable device
    class DiskSelector < ::CWM::ComboBox
      # Constructor
      def initialize
        textdomain "users"
        self.widget_id = "disk_selector"
      end

      # @see CWM::AbstractWidget
      def label
        ""
      end

      # @see CWM::AbstractWidget
      def init
        self.value = devices.first.name unless devices.empty?
      end

      # @see CWM::ComboBox#items
      def items
        devices.map { |d| [d.name, item_label(d)] }
      end

    private

      # Returns the list of devices that can be selected
      #
      # @note Basically only removable devices are supported.
      #
      # @return [Array<LeafBlkDevice>]
      def devices
        @devices ||= LeafBlkDevice.all.select(&:filesystem?)
      end

      # Returns the description to be used for a given item
      #
      # @return [String]
      def item_label(dev)
        "#{dev.model} (#{dev.name})"
      end
    end
  end
end
