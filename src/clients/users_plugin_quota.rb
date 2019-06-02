# encoding: utf-8

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
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------

# File:
#	include/users/users_plugin_quota.ycp
#
# Package:
#	Configuration of Users
#
# Summary:
#	This is GUI part of UsersPluginQuota,
#	plugin for configuration of user and group quotas
#
# Authors:
#	Jiri Suchomel <jsuchome@suse.cz>
#
# $Id$
module Yast
  class UsersPluginQuotaClient < Client
    def main
      Yast.import "UI"
      textdomain "users"

      Yast.import "Label"
      Yast.import "Report"
      Yast.import "Users"
      Yast.import "UsersPluginQuota" # plugin module
      Yast.import "Wizard"

      @ret = nil
      @func = ""
      @config = {}
      @data = {}

      # read arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @config = Convert.convert(
            WFM.Args(1),
            :from => "any",
            :to   => "map <string, any>"
          )
        end
        if Ops.greater_than(Builtins.size(WFM.Args), 2) &&
            Ops.is_map?(WFM.Args(2))
          @data = Convert.convert(
            WFM.Args(2),
            :from => "any",
            :to   => "map <string, any>"
          )
        end
      end
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("users plugin started: UsersPluginQuota")

      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("config=%1", @config)
      Builtins.y2debug("data=%1", @data)

      # maximal value of IntFields
      @max = 999999999

      # ----------------------------- now, the main body ----------------

      if @func == "Summary"
        @ret = UsersPluginQuota.Summary(@config, {})
      elsif @func == "Name"
        @ret = UsersPluginQuota.Name(@config, {})
      elsif @func == "Dialog"
        @caption = UsersPluginQuota.Name(@config, {})
        # list of edited settings (for each filesystem)
        @quota_list = []
        @what = Ops.get_string(@config, "what", "user")

        # helptext for quota
        @help_text = _(
          "<p>Configure quota settings for the user on selected file systems.</p>"
        ) +
          # helptext for quota, cont.
          _(
            "<p>Define a size limit by specifying the number of 1 KB blocks the\nuser may have on this file system. Additionally, you can define an inode limit specifying the number of inodes the user may have on the file system.</p>\n"
          ) +
          # helptext for quota, cont.
          _(
            "<p>You can specify both soft and hard limits for size and number of inodes. The soft limits define a warning level at which users are informed they are nearing their limit, whereas the hard limits define the limit at which write requests are denied.</p>"
          ) +
          # helptext for quota, cont.
          _(
            "<p>As soon as the user has reached the soft limit, the input fields for the grace interval are activated. Specify the time period for which the user is allowed to exceed the soft limits set above. The countdown of the grace interval starts immediately.</p>"
          )

        if @what == "group"
          # helptext for quota
          @help_text = _(
            "<p>Configure quota settings for the group on selected file systems.</p>"
          ) +
            # helptext for quota, cont.
            _(
              "<p>Define a size limit by specifying the number of 1 kB blocks the\ngroup may use on this file system. Additionally, you can define an inode limit specifying the number of inodes the group may use on the file system.</p>\n"
            ) +
            # helptext for quota, cont.
            _(
              "<p>You can specify both soft and hard limits for size and number of inodes. The soft limits define a warning level at which groups are informed they are nearing their limit, whereas the hard limits define the limit at which write requests are denied.</p>"
            ) +
            # helptext for quota, cont.
            _(
              "<p>As soon as the group has reached the soft limit, the input fields for the grace interval are activated. Specify the time period for which the group is allowed to exceed the soft limits set above. The countdown of the grace interval starts immediately.</p>"
            )
        end

        @modified = Ops.get_integer(@data, "plugin_modified", 0) == 1
        @current = 0 # current fs (index in the list)
        @current_quota = Ops.get_list(@data, "quota", [])

        # map of quota settings for current fs
        @quotamap = Convert.convert(
          Ops.get(@current_quota, @current, {}),
          :from => "map",
          :to   => "map <string, any>"
        )

        # helper to obtain integer when value might be string or integer...
        def get_int(key)
          value = Ops.get(@quotamap, key)
          return 0 if value == nil
          return Convert.to_integer(value) if Ops.is_integer?(value)
          if Ops.is_string?(value) && value != ""
            return Builtins.tointeger(Convert.to_string(value))
          end
          0
        end

        @quota_blocks_soft = get_int("quota_blocks_soft")
        @quota_blocks_hard = get_int("quota_blocks_hard")
        @quota_blocks_grace = get_int("quota_blocks_grace")
        @quota_inodes_soft = get_int("quota_inodes_soft")
        @quota_inodes_hard = get_int("quota_inodes_hard")
        @quota_inodes_grace = get_int("quota_inodes_grace")

        @i = -1
        # go through whole quota list, generate items for filesystem combo,
        # and create tmp quota maps for each fs
        @fs_items = Builtins.maplist(@current_quota) do |q|
          fs = Ops.get_string(q, "quota_fs", "")
          @i = Ops.add(@i, 1)
          # data that cannot be modified
          fixed = { "quota_fs" => fs }
          if Builtins.haskey(q, "quota_blocks_grace_exceeded")
            Ops.set(fixed, "quota_blocks_grace_exceeded", 1)
          end
          if Builtins.haskey(q, "quota_inodes_grace_exceeded")
            Ops.set(fixed, "quota_inodes_grace_exceeded", 1)
          end
          @quota_list = Builtins.add(@quota_list, fixed)
          Item(Id(@i), fs, @i == @current)
        end

        @contents = HBox(
          HSpacing(3),
          VBox(
            VSpacing(0.4),
            Left(
              ComboBox(
                Id("quota_fs"),
                Opt(:notify),
                # combo box label
                _("&File System"),
                @fs_items
              )
            ),
            VSpacing(0.4),
            # frame label
            Frame(
              _("Size Limits"),
              HBox(
                HSpacing(0.5),
                VBox(
                  IntField(
                    Id("quota_blocks_soft"),
                    Opt(:hstretch),
                    # intfield label
                    _("&Soft limit"),
                    0,
                    @max,
                    @quota_blocks_soft
                  ),
                  IntField(
                    Id("quota_blocks_hard"),
                    # intfield label
                    _("&Hard limit"),
                    0,
                    @max,
                    @quota_blocks_hard
                  ),
                  VSpacing(0.2),
                  ReplacePoint(
                    Id("quota_blocks_grace"),
                    time_dialog("quota_blocks_grace", @quota_blocks_grace)
                  ),
                  VSpacing(0.2)
                ),
                HSpacing(0.5)
              )
            ),
            # 2 small spaces instead of one big because of ncurses:
            VSpacing(0.4),
            VSpacing(0.4),
            # frame label
            Frame(
              _("I-nodes Limit"),
              HBox(
                HSpacing(0.5),
                VBox(
                  IntField(
                    Id("quota_inodes_soft"),
                    # intfield label
                    _("S&oft limit"),
                    0,
                    @max,
                    @quota_inodes_soft
                  ),
                  IntField(
                    Id("quota_inodes_hard"),
                    # intfield label
                    _("Har&d limit"),
                    0,
                    @max,
                    @quota_inodes_hard
                  ),
                  VSpacing(0.2),
                  ReplacePoint(
                    Id("quota_inodes_grace"),
                    time_dialog("quota_inodes_grace", @quota_inodes_grace)
                  ),
                  VSpacing(0.2)
                ),
                HSpacing(0.5)
              )
            ),
            VSpacing(0.4)
          ),
          HSpacing(3)
        )

        Wizard.CreateDialog
        Wizard.SetDesktopIcon("org.opensuse.yast.Users")

        Wizard.SetContentsButtons(
          UsersPluginQuota.Name(@config, {}),
          @contents,
          @help_text,
          Label.CancelButton,
          Label.OKButton
        )

        Wizard.HideAbortButton

        # grace time widgets are only available when soft limit was passed
        if !Builtins.haskey(@quotamap, "quota_blocks_grace_exceeded")
          Builtins.foreach(["d", "h", "m", "s"]) do |k|
            UI.ChangeWidget(
              Id(Ops.add("quota_blocks_grace", k)),
              :Enabled,
              false
            )
          end
        end
        if !Builtins.haskey(@quotamap, "quota_inodes_grace_exceeded")
          Builtins.foreach(["d", "h", "m", "s"]) do |k|
            UI.ChangeWidget(
              Id(Ops.add("quota_inodes_grace", k)),
              :Enabled,
              false
            )
          end
        end

        @ret = :next
        begin
          @ret = UI.UserInput
          if @ret == "quota_fs" || @ret == :next
            @sel = Convert.to_integer(UI.QueryWidget(Id("quota_fs"), :Value))
            if @sel != @current || @ret == :next
              # error popup
              @msg = _("Soft limit cannot be higher than the hard limit.")
              if Ops.greater_than(
                  Convert.to_integer(
                    UI.QueryWidget(Id("quota_blocks_soft"), :Value)
                  ),
                  Convert.to_integer(
                    UI.QueryWidget(Id("quota_blocks_hard"), :Value)
                  )
                )
                Report.Error(@msg)
                UI.SetFocus(Id("quota_blocks_soft"))
                @ret = :notnext
                next
              end
              if Ops.greater_than(
                  Convert.to_integer(
                    UI.QueryWidget(Id("quota_inodes_soft"), :Value)
                  ),
                  Convert.to_integer(
                    UI.QueryWidget(Id("quota_inodes_hard"), :Value)
                  )
                )
                Report.Error(@msg)
                UI.SetFocus(Id("quota_inodes_soft"))
                @ret = :notnext
                next
              end

              Builtins.foreach(
                [
                  "quota_blocks_soft",
                  "quota_blocks_hard",
                  "quota_inodes_soft",
                  "quota_inodes_hard",
                  "quota_blocks_grace",
                  "quota_inodes_grace"
                ]
              ) do |key|
                # read the new map for selected fs
                if Ops.get(@quota_list, [@sel, key]) != nil
                  Ops.set(@quotamap, key, Ops.get(@quota_list, [@sel, key]))
                else
                  Ops.set(@quotamap, key, Ops.get(@data, ["quota", @sel, key]))
                end
                if !Builtins.issubstring(key, "grace")
                  # save current status (still in UI)
                  Ops.set(
                    @quota_list,
                    [@current, key],
                    UI.QueryWidget(Id(key), :Value)
                  )
                  # ... and update UI with the new one
                  if @ret != :next
                    UI.ChangeWidget(Id(key), :Value, get_int(key))
                  end
                else
                  # save the old
                  Ops.set(@quota_list, [@current, key], get_seconds_value(key))
                  # show the new
                  update_time_widget(key, get_int(key)) if @ret != :next
                end
              end
              if @ret != :next
                UI.ChangeWidget(
                  Id("quota_fs"),
                  :Value,
                  Ops.get_string(@quota_list, [@sel, "quota_fs"], "")
                )
              end
              @current = @sel
            end
          end
          if @ret == :next
            @i2 = 0
            Builtins.foreach(@quota_list) do |qmap|
              Builtins.foreach(
                Convert.convert(
                  qmap,
                  :from => "map",
                  :to   => "map <string, any>"
                )
              ) do |key, val|
                next if key == "quota_fs"
                if Builtins.sformat("%1", val) !=
                    Builtins.tostring(
                      Ops.get_string(@current_quota, [@i2, key], "0")
                    )
                  @modified = true
                end
              end
              @i2 = Ops.add(@i2, 1)
            end
            break if !@modified

            # modified data to add to user/group
            @tmp_data = { "quota" => @quota_list, "plugin_modified" => 1 }

            # if this plugin wasn't in default set, we must save its name
            # (this is probably obsolete, users module should take care)
            if !Builtins.contains(
                Ops.get_list(@data, "plugins", []),
                "UsersPluginQuota"
              )
              Ops.set(
                @tmp_data,
                "plugins",
                Builtins.add(
                  Ops.get_list(@tmp_data, "plugins", []),
                  "UsersPluginQuota"
                )
              )
            end
            if Ops.get_string(@data, "what", "") == "edit_user"
              Users.EditUser(@tmp_data)
            elsif Ops.get_string(@data, "what", "") == "add_user"
              Users.AddUser(@tmp_data)
            elsif Ops.get_string(@data, "what", "") == "edit_group"
              Users.EditGroup(@tmp_data)
            elsif Ops.get_string(@data, "what", "") == "add_group"
              Users.AddGroup(@tmp_data)
            end
          end
        end until Ops.is_symbol?(@ret) &&
          Builtins.contains(
            [:next, :abort, :back, :cancel],
            Convert.to_symbol(@ret)
          )
        Wizard.CloseDialog
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = false
      end
      Builtins.y2milestone("users plugin finished with %1", @ret)
      Builtins.y2milestone("----------------------------------------")
      deep_copy(@ret)
    end

    # helper for updating values of time widget from number of seconds
    # @param [String] id string that preceedes the subwidgets id's
    # @param [Fixnum] seconds number of seconds to be shown in the widget
    def update_time_widget(id, seconds)
      days = Ops.divide(seconds, 24 * 60 * 60)
      if Ops.greater_than(days, 0)
        seconds = Ops.subtract(
          seconds,
          Ops.multiply(Ops.multiply(Ops.multiply(days, 24), 60), 60)
        )
      end
      hours = Ops.divide(seconds, 60 * 60)
      if Ops.greater_than(hours, 0)
        seconds = Ops.subtract(
          seconds,
          Ops.multiply(Ops.multiply(hours, 60), 60)
        )
      end
      minutes = Ops.divide(seconds, 60)
      if Ops.greater_than(minutes, 0)
        seconds = Ops.subtract(seconds, Ops.multiply(minutes, 60))
      end
      UI.ChangeWidget(Id(Ops.add(id, "d")), :Value, days)
      UI.ChangeWidget(Id(Ops.add(id, "h")), :Value, hours)
      UI.ChangeWidget(Id(Ops.add(id, "m")), :Value, minutes)
      UI.ChangeWidget(Id(Ops.add(id, "s")), :Value, seconds)

      nil
    end

    # helper for creating widget with time settings
    # @param [String] id string that preceedes the subwidgets id's
    # @param [Fixnum] seconds number of seconds to be shown in the widget
    def time_dialog(id, seconds)
      days = Ops.divide(seconds, 24 * 60 * 60)
      if Ops.greater_than(days, 0)
        seconds = Ops.subtract(
          seconds,
          Ops.multiply(Ops.multiply(Ops.multiply(days, 24), 60), 60)
        )
      end
      hours = Ops.divide(seconds, 60 * 60)
      if Ops.greater_than(hours, 0)
        seconds = Ops.subtract(
          seconds,
          Ops.multiply(Ops.multiply(hours, 60), 60)
        )
      end
      minutes = Ops.divide(seconds, 60)
      if Ops.greater_than(minutes, 0)
        seconds = Ops.subtract(seconds, Ops.multiply(minutes, 60))
      end
      HBox(
        IntField(Id(Ops.add(id, "d")), _("Days"), 0, @max, days),
        IntField(Id(Ops.add(id, "h")), _("Hours"), 0, 23, hours),
        IntField(Id(Ops.add(id, "m")), _("Minutes"), 0, 59, minutes),
        IntField(Id(Ops.add(id, "s")), _("Seconds"), 0, 59, seconds)
      )
    end

    # helper for reading the content of time widget
    # @param [String] id string that preceedes the subwidgets id's
    # @return the number of seconds shown in the time widget
    def get_seconds_value(id)
      days = Convert.to_integer(UI.QueryWidget(Id(Ops.add(id, "d")), :Value))
      hours = Convert.to_integer(UI.QueryWidget(Id(Ops.add(id, "h")), :Value))
      minutes = Convert.to_integer(UI.QueryWidget(Id(Ops.add(id, "m")), :Value))
      seconds = Convert.to_integer(UI.QueryWidget(Id(Ops.add(id, "s")), :Value))
      Ops.add(
        Ops.add(
          Ops.add(
            Ops.multiply(Ops.multiply(Ops.multiply(days, 24), 60), 60),
            Ops.multiply(Ops.multiply(hours, 60), 60)
          ),
          Ops.multiply(minutes, 60)
        ),
        seconds
      )
    end
  end
end

Yast::UsersPluginQuotaClient.new.main
