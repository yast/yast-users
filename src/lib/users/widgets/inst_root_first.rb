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
require "users/widgets"
require "users/widgets/public_key_selector"
require "ui/widgets"
require "yast2/popup"

module Y2Users
  module Widgets
    # This class displays the initial configuration settings for the root user.
    class InstRootFirst < ::CWM::CustomWidget
      # Constructor
      def initialize
        textdomain "users"
      end

      # Returns a UI widget-set for the dialog
      def contents
        @contents ||=
          VBox(
            VStretch(),
            HSquash(
              VBox(
                password_widget,
                ::UI::Widgets::KeyboardLayoutTest.new,
                VSpacing(2.4),
                public_key_selector
              )
            ),
            VStretch()
          )
      end

      # @see CWM::AbstractWidget
      def validate
        return true unless password_widget.empty? && public_key_selector.empty?
        Yast2::Popup.show(
          _("You need to provide at least a password or a public key."), headline: :error
        )
        false
      end

    private

      # Returns a password widget
      #
      # @note The widget is memoized
      #
      # @return [Users::PasswordWidget] Password widget
      def password_widget
        @password_widget ||= ::Users::PasswordWidget.new(focus: true, allow_empty: true)
      end

      # Returns a public key selection widget
      #
      # @note The widget is memoized
      #
      # @return [Y2Users::Widgets::PublicKeySelector] Public key selection widget
      def public_key_selector
        @public_key_selector ||= ::Y2Users::Widgets::PublicKeySelector.new
      end
    end
  end
end
