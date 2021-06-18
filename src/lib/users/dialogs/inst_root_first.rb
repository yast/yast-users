# ------------------------------------------------------------------------------
# Copyright (c) 2006-2012 Novell, Inc. All Rights Reserved.
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------

require "yast"
require "cwm/dialog"
require "users/widgets/inst_root_first"

Yast.import "Mode"
Yast.import "Popup"

module Yast
  # This library provides a simple dialog for setting new password for the system administrator
  # (root) including checking quality of the password itself. The new password is not written to the
  # system, just stored in the target config and written later during inst_finish.
  class InstRootFirstDialog < ::CWM::Dialog
    # Constructor
    #
    # @param root_user [Y2Users::Users] object holding the root user configuration
    def initialize(root_user)
      textdomain "users"

      @root_user = root_user
    end

    # @return [String] Dialog's title
    # @see CWM::AbstractWidget
    def title
      _("Authentication for the System Administrator \"root\"")
    end

    # Returns a UI widget-set for the dialog
    def contents
      VBox(
        Y2Users::Widgets::InstRootFirst.new(@root_user)
      )
    end

    # Request confirmation for aborthing the dialog
    def abort_handler
      Yast::Popup.ConfirmAbort(:painless)
    end

  private

    # Returns whether we need/ed to create new UI Wizard
    #
    # @see CWM::Dialog
    #
    # @note We do not need to create a wizard dialog in installation, but it's helpful when testing
    #   all manually on a running system
    def should_open_dialog?
      Mode.normal
    end
  end
end
