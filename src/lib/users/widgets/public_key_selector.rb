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
require "users/widgets/disk_selector"
require "users/widgets/public_keys_list"
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
      #   @return [String] Public key content
      attr_reader :value

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
          HBox(
            disk_selector,
            HStretch(),
            PushButton(Id(:browse), "Browse..."),
          ),
          public_keys_list
        )
      end

      # Events handler
      #
      # @see CWM::AbstractWdiget
      def handle(event)
        read_key if event["ID"] == :browse

        nil
      end

      # @see CWM::AbstractWdiget
      def store
        Yast::SSHAuthorizedKeys.import_keys("/root", keys.map(&:to_s)) unless keys.empty?
        nil
      end

      # Forces this widget to listen to all events
      #
      # @return [Boolean]
      def handle_all_events
        true
      end

      # Returns the list of added keys
      #
      # @return [Array<SSHPublicKey>] List of public keys
      def keys
        public_keys_list.keys
      end

    private

      attr_writer :value

      # Returns the disk selector widget
      #
      # @note The widget is memoized
      #
      # @return [DiskSelector] Disk selection widget
      def disk_selector
        @disk_selector ||= DiskSelector.new
      end

      # Public keys list widget
      #
      # @note The widget is memoized
      #
      # @return [PublicKeyList] Public keys list widget
      def public_keys_list
        @public_keys_list ||= PublicKeysList.new
      end

      # Reads the key selected by the user
      #
      # @note This method mounts the selected filesystem.
      #
      # @return [String] Key content
      def read_key
        dir = Dir.mktmpdir
        begin
          mounted = Yast::SCR.Execute(
            Yast::Path.new(".target.mount"), [disk_selector.value, dir], "-o ro"
          )
          if mounted
            read_key_from(dir)
          else
            report_mount_error(disk_selector.value)
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
        public_keys_list.add(SSHPublicKey.new(File.read(path)))
      rescue SSHPublicKey::InvalidKey
        report_invalid_key
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
