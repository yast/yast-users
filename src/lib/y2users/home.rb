# Copyright (c) [2021-2022] SUSE LLC
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

require "yast2/equatable"

module Y2Users
  # Class for representing a user home
  class Home
    include Yast2::Equatable

    # Home path (e.g., "/home/username")
    #
    # @return [String, nil] nil if unknown
    attr_accessor :path

    # Home permissions
    #
    # It represents an octal number starting by 0 (e.g., "0755")
    #
    # @return [String, nil] nil if unknown
    attr_accessor :permissions

    # Sets whether home is a btrfs subvolume
    #
    # @return [Boolean]
    attr_accessor :btrfs_subvol

    eql_attr :path, :permissions, :btrfs_subvol

    # Constructor
    #
    # @param path [String, nil] home path
    def initialize(path = nil)
      @path = path
    end

    # Whether home is a btrfs subvolume
    #
    # @return [Boolean]
    def btrfs_subvol?
      !!@btrfs_subvol
    end

    # Whether home has a defined path
    #
    # @return [Boolean]
    def path?
      !path.to_s.empty?
    end
  end
end
