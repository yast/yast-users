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

require "json"
require "yast2/execute"

module Y2Users
  # This class represents a block device reported by `lsblk` as a leaf node
  #
  # As we cannot use a devicegraph for the time being, this class extracts the
  # block devices information from the lsblk command. Only the leaf devices
  # are taken into account and it only includes information which is relevant
  # for the {Y2Users::Widgets::DiskSelector} widget.
  class LeafBlkDevice
    class << self
      # Returns all relevant block devices
      #
      # @note It takes the information from `lsblk`
      #
      # @return [Array<LeafBlkDevice>] List of relevant block devices
      def all
        lsblk["blockdevices"].map { |h| new_from_hash(h) }
      end

      # Instantiates a new object
      #
      # @note It uses a Hash with information from `lsblk`.
      #
      # @return [LeafBlkDevice] New LeafBlkDevice instance
      def new_from_hash(hash)
        parent = find_root_device(hash)
        new(
          name: hash["name"], disk: parent["name"], model: parent["model"],
          fstype: hash["fstype"]
        )
      end

    private

      # Gets `lsblk` into a Hash
      #
      # @return [Hash] Hash containing data from `lsblk`
      def lsblk
        output = Yast::Execute.locally(
          "/usr/bin/lsblk", "--inverse", "--json", "--paths",
          "--output", "NAME,FSTYPE,MODEL", stdout: :capture
        )
        return { "blockdevices" => [] } if output.nil?
        JSON.parse(output)
      end

      # Finds the root for a given device
      #
      # @return [Hash]
      def find_root_device(hash)
        hash.key?("children") ? find_root_device(hash["children"][0]) : hash
      end
    end

    # @return [String] Kernel name
    attr_reader :name

    # @return [String] Hardware model
    attr_reader :model

    # @return [String] Disk's kernel name
    attr_reader :disk

    # @return [Symbol] Filesystem type
    attr_reader :fstype

    # Constructor
    #
    # @param name      [String]  Kernel name
    # @param disk      [String]  Disk's kernel name
    # @param model     [String]  Hardware model
    # @param fstype    [Symbol]  Filesystem type
    def initialize(name:, disk:, model:, fstype: nil)
      @name = name
      @model = model.strip if model
      @disk = disk
      @fstype = fstype.to_sym if fstype
    end

    # Determines whether the device has a filesystem
    #
    # @return [Boolean]
    def filesystem?
      !!fstype
    end
  end
end
