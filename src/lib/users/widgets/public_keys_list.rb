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

module Y2Users
  module Widgets
    # This widget is a simple list of SSH public keys. It features a "remove" button for each key in
    # order to remove them from the list.
    class PublicKeysList < ::CWM::CustomWidget
      # @return [Array<SSHPublicKey>] List of SSH public keys
      attr_reader :keys

      # Constructor
      #
      # @param keys [Array<SSHPublicKey>] Initial list of keys
      def initialize(keys = [])
        @keys = keys
        self.widget_id = "public_keys_list"
      end

      # @return [Yast::Term] Dialog content
      # @see CWM::CustomWidget
      def contents
        ReplacePoint(Id(:public_keys_list_items), keys_list)
      end

      # Adds a key to the list
      #
      # @param key [SSHPublicKey] Key to add to the current list
      def add(key)
        change_items(keys + [key])
      end

      # Updates the list of keys
      #
      # @param keys [Array<SSHPublicKey>] Updated list of keys
      def change_items(keys)
        @keys = keys
        Yast::UI.ReplaceWidget(:public_keys_list_items, keys_list)
      end

      # Events handler
      #
      # @see CWM::AbstractWdiget
      def handle(event)
        remove_key(event) if event["ID"].to_s.start_with?("remove_")
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
        keys.empty?
      end

    private

      # Returns the keys list
      #
      # @return [Yast::Term]
      def keys_list
        rows = keys.each_with_index.map do |key, i|
          VBox(
            Left(Label(key.fingerprint)),
            HBox(
              Left(Label(key.comment)),
              Right(PushButton(Id("remove_#{i}"), Opt(:notify), "Remove"))
            )
          )
        end
        VBox(*rows)
      end

      # Remove the selected key
      #
      # @param event [Hash] Event containing the information about the key to remove
      def remove_key(event)
        _prefix, index = event["ID"].split("_")
        keys.delete_at(index.to_i)
        change_items(keys)
      end
    end
  end
end
