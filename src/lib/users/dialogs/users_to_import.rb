# Copyright (c) 2016 SUSE LLC.
#  All Rights Reserved.

#  This program is free software; you can redistribute it and/or
#  modify it under the terms of version 2 or 3 of the GNU General
#  Public License as published by the Free Software Foundation.

#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
#  GNU General Public License for more details.

#  You should have received a copy of the GNU General Public License
#  along with this program; if not, contact SUSE LLC.

#  To contact SUSE about this file by physical or electronic mail,
#  you may find current contact information at www.suse.com

require "yast"
require "ui/dialog"

module Yast
  class UsersToImportDialog < ::UI::Dialog
    def initialize(all, initial)
      super()

      Yast.import "UI"
      Yast.import "Label"

      textdomain "users"

      @all = all
      @initial = initial
    end

    # Event callback for 'select or deselect all'
    def all_handler
      sel = UI.QueryWidget(Id(:all), :Value) ? @all : []
      UI.ChangeWidget(Id(:userlist), :SelectedItems, sel)
    end

    # Event callback for the 'ok' button
    def ok_handler
      selected = UI.QueryWidget(Id(:userlist), :SelectedItems)
      finish_dialog(selected)
    end

  private

    def dialog_content
      HBox(
        VSpacing([@all.size, 15].max),
        VBox(
          HSpacing(50),
          MultiSelectionBox(
            Id(:userlist),
            # selection box label
            _("&Select Users to Read"),
            initial_items
          ),
          Left(
            CheckBox(
              Id(:all),
              Opt(:notify),
              # check box label
              _("Select or Deselect &All"),
              initially_all_checked?
            )
          ),
          HBox(
            PushButton(Id(:ok), Opt(:default), Label.OKButton),
            PushButton(Id(:cancel), Label.CancelButton)
          )
        )
      )
    end

    def dialog_options
      Opt(:decorated)
    end

    def initial_items
      @all.map { |u| Item(Id(u), u, @initial.include?(u)) }
    end

    def initially_all_checked?
      @all.size == @initial.size
    end
  end
end
