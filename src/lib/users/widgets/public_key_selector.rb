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
require "yast2/execute"
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
          ReplacePoint(Id(:fingerprint), Empty())
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
        Yast::SSHAuthorizedKeys.import_keys("/root", [value]) if value
        nil
      end

    private

      attr_writer :value

      # Builds a widget to select the disk to read the public key from
      #
      # @return [DiskSelector] Disk selection widget
      def disk_selector
        @disk_selector ||= DiskSelector.new
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
            self.value = read_key_from(dir)
            refresh_fingerprint
          else
            report_mount_error(disk_selector.value)
          end
        ensure
          Yast::SCR.Execute(Yast::Path.new(".target.umount"), dir) if mounted
          FileUtils.remove_entry_secure(dir)
        end
      end

      # Reads a the key from the given directory
      #
      # @note Asks the user to select a file and tries to read it.
      def read_key_from(dir)
        path = Yast::UI.AskForExistingFile(dir, "*", _("Select a public key"))
        File.read(path) if path && File.exist?(path)
      end

      # Refreshes the fingerprint which is shown in the UI.
      def refresh_fingerprint
        Yast::UI::ReplaceWidget(
          Id(:fingerprint), Left(Label(fingerprint(value)))
        )
      end

      # Displays an error about the device which failed to be mounted
      #
      # @param device [String] Device's name
      def report_mount_error(device)
        message = format(_("Could not mount device %s"), device)
        Yast2::Popup.show(message, headline: :error)
      end

      # Calculates the fingerprint for a given key
      #
      # @param key [String] SSH public key
      # @return [String] Key's fingerprint
      def fingerprint(key)
        return "" unless key
        output = Yast::Execute.locally!(
          ["echo", key], ["ssh-keygen", "-l", "-f", "/dev/stdin"], stdout: :capture
        )
        output.split(" ").at(1).to_s
      end
    end
  end
end
