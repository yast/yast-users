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
require "y2users"
require "y2users/users_simple"

Yast.import "Arch"
Yast.import "Label"
Yast.import "UI"

module Y2Users
  module Widgets
    # This widget allows to select a public key from a removable device
    class PublicKeySelector < ::CWM::CustomWidget
      class << self
        # We want this information (the selected device name and the SSH key) to be remembered
        attr_accessor :selected_blk_device_name, :value
      end

      # Constructor
      def initialize
        textdomain "users"

        @users_config = Y2Users::Config.new
        Y2Users::UsersSimple::Reader.new.read_to(@users_config)

        @root_user = @users_config.users.root
      end

      # @return [String] Widget label
      def label
        _("Import Public SSH Key")
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
        when :refresh
          reset_available_blk_devices
        end
        update

        nil
      end

      # @see CWM::AbstractWdiget
      def store
        @root_user.authorized_keys = [value.to_s]
        Y2Users::UsersSimple::Writer.new(@users_config).write
        nil
      end

      # Forces this widget to listen to all events
      #
      # @return [Boolean]
      def handle_all_events
        true
      end

      # Determines whether a public key is selected or not
      #
      # @return [Boolean] true if empty; false otherwise
      def empty?
        value.nil?
      end

      # Helper method to get the current value (the selected public key)
      #
      # @return [SSHPublicKey,nil] Return the selected public key (or nil if no key is selected)
      def value
        self.class.value
      end

      # Returns the help text regarding the use of a public key for authentication
      #
      # @return [String] Help text
      def help
        @help ||= _(
          "<p>\n" \
          "In some situations it is preferred to access to the system remotely via SSH\n" \
          "using a public key instead of a password. This screen allows you to select\n" \
          "one public key from an USB stick, a CD/DVD ROM or even from an existing\n" \
          "partition.\n" \
          "</p>\n" \
          "<p>\n" \
          "If the public key is stored on a removable device, you do not need to keep\n" \
          "the device connected during the whole installation. You can remove it right\n" \
          "after selecting the key.\n" \
          "</p>\n" \
          "<p>\n" \
          "Take into account that the root password and the public key are not mutually\n" \
          "exclusive: you can provide both if you want.\n" \
          "</p>\n"
        )
      end

    private

      # Helper method to set the current value (the selected public key)
      #
      # @param key [SSHPublicKey] Return the current public key
      def value=(key)
        self.class.value = key
      end

      def selected_blk_device_name
        self.class.selected_blk_device_name
      end

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
      # This widget display includes a list of selectable disks and a button to browse the
      # selected one.
      #
      # @return [Yast::Term]
      def blk_device_selector
        # no block devices in WSL
        if Yast::Arch.is_wsl
          Left(PushButton(Id(:browse), Opt(:notify), Yast::Label.BrowseButton))
        else
          browser_button_opt = if available_blk_devices.empty?
            Opt(:notify, :disabled)
          else
            Opt(:notify)
          end

          VBox(
            Left(
              HBox(
                blk_devices_combo_box,
                PushButton(Id(:refresh), Opt(:notify), Yast::Label.RefreshButton)
              )
            ),
            Left(PushButton(Id(:browse), browser_button_opt, Yast::Label.BrowseButton))
          )
        end
      end

      # UI which shows the public key content
      #
      # @return [Yast::Term]
      def public_key_content
        VBox(
          Left(Label(value.formatted_fingerprint)),
          HBox(
            Left(Label(value.comment)),
            Right(PushButton(Id(:remove), Opt(:notify), Yast::Label.RemoveButton))
          )
        )
      end

      # Key comment to show to the user
      #
      # @note When no comment is present, the widget shows 'no comment' just as ssh-keygen does.
      #
      # @return [String]
      def comment_value
        # TRANSLATORS: the public key does not contain a comment (which  is often used as some sort
        # of description in order to identify the key)
        value.comment || _("no comment")
      end

      # Disk combo box
      #
      # Displays a combo box containing all selectable devices.
      #
      # @return [Yast::Term]
      def blk_devices_combo_box
        options = available_blk_devices.map do |dev|
          label = dev.model ? "#{dev.model} (#{dev.name})" : dev.name
          Item(Id(dev.name), label, dev.name == selected_blk_device_name)
        end
        ComboBox(Id(:blk_device), Opt(:hstretch), "", options)
      end

      EXCLUDED_FSTYPES = [:squashfs, :swap].freeze
      # Returns a list of devices that can be selected
      #
      # Only the devices that meet the following conditions are considered:
      #
      # * It has a transport (so loop devices are automatically discarded).
      # * It has a filesystem but it is not squashfs, as it is used by the installer.
      #
      # The first condition should be enough. However, we want to avoid future problems if the lsblk
      # authors decide to show some information in the 'TRAN' (transport) property for those devices
      # that do not have one (for instance, something like 'none').
      #
      # @return [Array<LeafBlkDevice>] List of devices
      def available_blk_devices
        @available_blk_devices ||= LeafBlkDevice.all.select do |dev|
          dev.filesystem? && !EXCLUDED_FSTYPES.include?(dev.fstype)
        end
      end

      # Selects the current block device
      def select_blk_device
        self.class.selected_blk_device_name = Yast::UI.QueryWidget(Id(:blk_device), :Value)
      end

      # Refreshes widget content
      def update
        Yast::UI.ReplaceWidget(Id(:inner_content), inner_content)
      end

      # Reads the key selected by the user
      #
      # @note This method mounts the selected filesystem.
      #
      # @return [String] Key content
      def read_key
        # /mnt has windows drives mounted by default
        return read_key_from("/mnt") if Yast::Arch.is_wsl

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
        # TRANSLATORS: title of a dialog which allows to select a file to be used
        # as SSH public key
        path = Yast::UI.AskForExistingFile(dir, "*.pub", _("Select a public key"))
        return unless path && File.exist?(path)

        self.value = SSHPublicKey.new(File.read(path))
      rescue SSHPublicKey::InvalidKey
        report_invalid_key
      end

      # Removes the selected key
      def remove_key
        self.value = nil
      end

      # Resets the devices list
      def reset_available_blk_devices
        @available_blk_devices = nil
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
        Yast2::Popup.show(
          _("The selected file does not contain a valid public key"), headline: :error
        )
      end
    end
  end
end
