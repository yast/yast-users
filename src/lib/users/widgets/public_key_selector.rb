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
require "users/ssh_public_key"
require "yast2/popup"
require "tmpdir"

Yast.import "UI"
Yast.import "SSHAuthorizedKeys"

module Y2Users
  module Widgets
    # This widget allows to select a public key from a removable device
    class PublicKeySelector < ::CWM::CustomWidget
      # @!attribute [r]
      #   @return [SSHPublicKey] SSH public key
      attr_reader :value

      alias_method :key, :value

      # Constructor
      def initialize
        textdomain "users"
      end

      # @return [String] Widget label
      def label
        _("Import Public Key")
      end

      # @return [Yast::Term] Dialog content
      # @see CWM::CustomWidget
      def contents
        VBox(
          Left(Label(label)),
          ReplacePoint(Id(:inner_content), inner_content)
        )
      end

      # Events handler
      #
      # @see CWM::AbstractWdiget
      def handle(event)
        case event["ID"]
        when :browse
          read_key
        when :remove
          remove_key
        end
        refresh

        nil
      end

      # @see CWM::AbstractWdiget
      def store
        Yast::SSHAuthorizedKeys.import_keys("/root", [value.to_s]) if value
        nil
      end

      # Forces this widget to listen to all events
      #
      # @return [Boolean]
      def handle_all_events
        true
      end

      # Determines whether the public keys list is empty or not
      #
      # @return [Boolena] true if empty; false otherwise
      def empty?
        value.nil?
      end

    private

      attr_writer :value

      # @return [String] Selected block device name
      attr_reader :selected_blk_device_name


      # Widget's inner content
      #
      # It displays the public key content or a disk selector if no key has been selected.
      #
      # @return [Yast::Term]
      def inner_content
        VBox(empty? ? blk_device_selector : public_key_content)
      end

      # Disk selector
      #
      # This widget displays includes a list of selectable disk and a button to browse the
      # selected one.
      #
      # @return [Yast::Term]
      def blk_device_selector
        VBox(
          Left(MinWidth(50, blk_devices_combo_box)),
          Left(PushButton(Id(:browse), Opt(:notify), _("Browse..."))),
        )
      end

      # UI which shows the public key content
      #
      # @return [Yast::Term]
      def public_key_content
        VBox(
          Left(MinWidth(50, Label(value.fingerprint))),
          HBox(
            Left(Label(value.comment)),
            Right(PushButton(Id(:remove), Opt(:notify), _("Remove")))
          )
        )
      end

      # Disk combo box
      #
      # Displays a combo box containing al selectable devices.
      #
      # @return [Yast::Term]
      def blk_devices_combo_box
        options = available_blk_devices.map do |dev|
          Item(Id(dev.name), "#{dev.model} (#{dev.name})", dev.name == selected_blk_device_name)
        end
        ComboBox(Id(:blk_device), "", options)
      end

      # Returns a list of devices that can be selected
      #
      # @return [Array<LeafBlkDevice>] List of devices
      def available_blk_devices
        @available_blk_devices ||= LeafBlkDevice.all.select(&:filesystem?)
      end

      # Selects the current block device
      def select_blk_device
        @selected_blk_device_name = Yast::UI.QueryWidget(Id(:blk_device), :Value)
      end

      # Refreshes widget content
      def refresh
        Yast::UI.ReplaceWidget(Id(:inner_content), inner_content)
      end

      # Reads the key selected by the user
      #
      # @note This method mounts the selected filesystem.
      #
      # @return [String] Key content
      def read_key
        select_blk_device
        dir = Dir.mktmpdir
        begin
          mounted = Yast::SCR.Execute(
            Yast::Path.new(".target.mount"), [selected_blk_device_name, dir], "-o ro"
          )
          if mounted
            read_key_from(dir)
          else
            report_mount_error(selected_blk_device_name)
          end
        ensure
          Yast::SCR.Execute(Yast::Path.new(".target.umount"), dir) if mounted
          FileUtils.remove_entry_secure(dir)
        end
      end

      # Reads a key from the given directory
      #
      # @note Asks the user to select a file and tries to read it.
      def read_key_from(dir)
        path = Yast::UI.AskForExistingFile(dir, "*", _("Select a public key"))
        return unless path && File.exist?(path)
        self.value = SSHPublicKey.new(File.read(path))
      rescue SSHPublicKey::InvalidKey
        report_invalid_key
      end

      # Removes the selected key
      def remove_key
        self.value = nil
      end

      # Displays an error about the device which failed to be mounted
      #
      # @param device [String] Device's name
      def report_mount_error(device)
        message = format(_("Could not mount device %s"), device)
        Yast2::Popup.show(message, headline: :error)
      end

      # Displays an error about an invalid SSH key
      def report_invalid_key
        Yast2::Popup.show(_("A valid key was not found"), headline: :error)
      end
    end
  end
end
