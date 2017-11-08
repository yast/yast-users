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

#
# File:	include/users/helps.ycp
# Package:	Configuration of users and groups
# Summary:	Helptext for the users module
# Authors:	Johannes Buchhold <jbuch@suse.de>,
#		Jiri Suchomel <jsuchome@suse.cz>
#
# $Id$
#
module Yast
  module UsersHelpsInclude
    def initialize_users_helps(include_target)
      textdomain "users"

      Yast.import "Label"
      Yast.import "Ldap"
      Yast.import "Stage"
      Yast.import "Users"
      Yast.import "UsersCache"
      Yast.import "UsersLDAP"
      Yast.import "UsersRoutines"
    end

    # Password help text.
    # @param [String] type user type
    # @return [String] help text
    def help_password(type)
      password_length = ""
      enc_to_string = {
        # encryption type
        "des"   => _("DES"),
        # encryption type
        "crypt" => _("DES"),
        # encryption type
        "md5"   => _("MD5")
      }
      method = Users.EncryptionMethod
      method = UsersLDAP.GetEncryption if type == "ldap"

      # help text 1/4
      help_text = _(
        "<p>\n" +
          "When entering a password, distinguish between uppercase and\n" +
          "lowercase. Passwords should not contain any accented characters or umlauts. \n" +
          "</p>\n"
      )

      # help text 2/4 %1 is encryption type, %2,%3 numbers
      help_text = Ops.add(
        help_text,
        Builtins.sformat(
          _(
            "<p>\n" +
              "With the current password encryption (%1), the password length should be between\n" +
              " %2 and %3 characters.\n" +
              "</p>"
          ),
          Ops.get_string(enc_to_string, method, method),
          Users.GetMinPasswordLength(type),
          Users.GetMaxPasswordLength(type)
        )
      )

      help_text = Ops.add(help_text, Users.ValidPasswordHelptext)

      #help text 4/4
      help_text = Ops.add(
        help_text,
        _(
          "<p>\n" +
            "To ensure that the password was entered correctly,\n" +
            "repeat it exactly in a second field. Do not forget your password.\n" +
            "</p>\n"
        )
      )
      help_text
    end

    # @return [String] The help text.
    def DefaultsDialogHelp
      # Help text 0/6
      _(
        "<p>\n" +
          "Here, set default values to use when creating new local or system users.\n" +
          "</p>\n"
      ) +
        # Help text 1/6
        _(
          "<p>\n" +
            "<b>Default Group</b><br>\n" +
            "The group name of a new user's primary group.\n" +
            "</p>\n"
        ) +
        # Help text 1.5/6
        _(
          "<p>\n" +
            "<b>Secondary Groups</b><br>\n" +
            "Names of additional groups to which to assign new users.\n" +
            "</p>\n"
        ) +
        # Help text 2/6
        _(
          "<p><b>Default Login Shell</b><br>\nThe name of the new user's login shell. Select one from the list or enter your own path to the shell.</P>\n"
        ) +
        #Help text 3/6
        _(
          "<p><b>Default Home</b><br>\n" +
            "The initial path prefix for a new user's home directory. The username is added\n" +
            "to the end of this value to create the default name of the home directory.\n" +
            "</P>\n"
        ) +
        # Help text 4/6
        _(
          "<p><b>Skeleton Directory</b><br>\nThe contents of this directory are copied to a user's home directory when a new user is added. </p>\n"
        ) +
        # Help text 4.5/6
        _(
          "<p><b>Umask for Home Directory</b><br>\nUmask to use for creating new home directories.</p>\n"
        ) +
        # Help text 5/6:
        # Don't reorder letters YYYY-MM-DD, date must be set in this format
        _(
          "<p><b>Expiration Date</b><br>\n" +
            "The date on which the user account is disabled. The date must be in the format\n" +
            "YYYY-MM-DD. Leave it empty if this account never expires.</P>\n"
        ) +
        # Help text 6/6
        _(
          "<P><B>Days after Password Expiration Login Is Usable</B><BR>\n" +
            "Users can log in after expiration of passwords. Set how many days \n" +
            "after expiration login is allowed. Use -1 for unlimited access.\n" +
            "</P>\n"
        )
    end


    # Help for the ReadDialog () dialog.
    # @return [String] The help text.
    def ReadDialogHelp
      # For translators: read dialog help, part 1 of 2
      _(
        "<P><B><BIG>Initializing User Management</BIG></B><BR>\n" +
          "Please wait...\n" +
          "<BR></P>\n"
      ) +
        # For translators: read dialog help, part 2 of 2
        _(
          "<P><B><BIG>Aborting the Initialization</BIG></B><BR>\n" +
            "You can safely abort the configuration utility by pressing <B>Abort</B>\n" +
            "now.\n" +
            "</P>"
        )
    end

    # Help for the WriteDialog () dialog.
    # @return [String] The help text.
    def WriteDialogHelp
      # For translators: read dialog help, part 1 of 2
      _(
        "<P><B><BIG>Saving User Configuration</BIG></B><BR>\n" +
          "Please wait...\n" +
          "<BR></P>\n"
      ) +
        # For translators: read dialog help, part 2 of 2
        _(
          "<P><B><BIG>Aborting the Save Process:</BIG></B><BR>\n" +
            "Abort the save process by pressing <B>Abort</B>.\n" +
            "An additional dialog will inform you whether it is safe to do so.\n" +
            "</P>\n"
        )
    end


    # Help for EditUserDialog.
    # @param [Boolean] mail if checkbox for mail forwarding should be included
    # @param [String] type type of user created
    # @return [String] help text
    def EditUserDialogHelp(mail, type, what)
      help = ""
      if type == "ldap"
        # help text 1/7
        help = _(
          "<p>\n" +
            "Enter the <b>First Name</b>, <b>Last Name</b>, \n" +
            "<b>Username</b>, and\n" +
            "<b>Password</b> to assign to this user.\n" +
            "</p>\n"
        )
      else
        # alternative help text 1/7
        help = _(
          "<p>\n" +
            "Enter the <b>User's Full Name</b>, <b>Username</b>, and <b>Password</b> to\n" +
            "assign to this user account.\n" +
            "</p>\n"
        )
      end

      help = Ops.add(help, help_password(type))

      if what == "add_user"
        help = Ops.add(
          help,
          # help text 2/7
          _(
            "<p>\n" +
              "Create the <b>Username</b> from components of the full name by\n" +
              "clicking <b>Suggestion</b>. It may be modified, but use only\n" +
              "letters (no accented characters), digits, and <tt>._-</tt>.\n" +
              "Do not use uppercase letters in this entry unless you know what you are doing.\n" +
              "Usernames have stricter restrictions than passwords. You can redefine the\n" +
              "restrictions in the /etc/login.defs file. Read its man page for information.\n" +
              "</p>\n"
          )
        )
      else
        help = Ops.add(
          help,
          # alternative help text 2/7
          _(
            "<p>\n" +
              "For the <b>Username</b>, use only\n" +
              "letters (no accented characters), digits, and <tt>._-</tt>.\n" +
              "Do not use uppercase letters in this entry unless you know what you are doing.\n" +
              "Usernames have stricter restrictions than passwords. You can redefine the\n" +
              "restrictions in the /etc/login.defs file.  Read its man page for information.\n" +
              "</p>\n"
          )
        )
      end

      if mail # these are used only during installation time
        # help text 4/7 (only during installation)
        help = Ops.add(
          Ops.add(
            Ops.add(
              help,
              _(
                "<p>\nThe username and password created here are needed to log in and work with your Linux system. With <b>Automatic Login</b> enabled, the login procedure is skipped. This user is logged in automatically.</p>\n"
              )
            ),
            # help text 5/7 (only during installation)
            _(
              "<p>\nHave mail for root forwarded to this user by checking <b>Receive System Mail</b>.</p>\n"
            )
          ),
          # help text 6/7 (only during installation)
          _(
            "<p>Press <b>User Management</b> to add more users or groups to your system.</p>"
          )
        )
      else
        # alternative help text 4/7
        help = Ops.add(
          Ops.add(
            help,
            _(
              "<p>\n" +
                "To see more details, such as the home directory or the user ID, click\n" +
                "<b>Details</b>.\n" +
                "</p>\n"
            )
          ),
          # alternative help text 5/7
          _(
            "<p>\nTo edit various password settings of this user, such as expiration date, click <b>Password Settings</b>.</p>\n"
          )
        )
      end

      if !mail && type != "nis"
        # help text 7/7
        help = Ops.add(
          help,
          _(
            "<p>To forbid this user to\nlog in, check <b>Disable User Login</b>.</p>"
          )
        )
      end
      help
    end




    # Help for EditGroupDialog.
    # @param [Boolean] more if the widget with more_users will be shown
    # @return [String] help text
    def EditGroupDialogHelp(more)
      # help text 1/6
      helptext = Ops.add(
        Ops.add(
          Ops.add(
            Ops.add(
              _("<p>\nEnter the group data here.   \n</p>\n") +
                # help text 2/6
                _(
                  "<p>\n" +
                    "<b>Group Name:</b>\n" +
                    "Avoid long names for groups. Normal lengths are between \n" +
                    "two and eight characters.  \n" +
                    "You can redefine the list of characters allowed for group names in\n" +
                    "the /etc/login.defs file. Read its man page for information.\n" +
                    "</p>\n"
                ),
              # help text 3/6, %1 is number
              Builtins.sformat(
                _(
                  "<p>\n" +
                    "<b>Group ID (gid):</b>\n" +
                    "In addition to its name, a group must be assigned a numerical ID for its\n" +
                    "internal representation. These values are between 0 and\n" +
                    "%1. Some of the IDs are already assigned during installation. You will be\n" +
                    "warned if you try to use an already set one.\n" +
                    "</p>\n"
                ),
                UsersCache.GetMaxGID("local")
              )
            ),
            # help text 4/6
            _(
              "<p>\n" +
                "<b>Password:</b>\n" +
                "To require users who are not members of the group to identify themselves when\n" +
                "switching to this group (see the man page of <tt>newgrp</tt>), assign a\n" +
                "password to this group. For security reasons, this password is not shown\n" +
                "here. This entry is not required.\n" +
                "</p>\n"
            )
          ),
          # help text 5/6
          _(
            "<p>\n" +
              "<b>Confirm Password:</b>\n" +
              "Enter the password a second time to avoid typing errors.\n" +
              "</p>\n"
          )
        ),
        # help text 6/6
        _(
          "<p>\n" +
            "<b>Group Members:</b>\n" +
            "Here, select which users should be members of this group.\n" +
            "</p>\n"
        )
      )

      if more
        helptext = Ops.add(
          helptext,
          # additional helptext for EditFroup dialog
          _(
            "The second list shows users for which this group is the default\n        group. The default group can only be changed by editing the user."
          )
        )
      end

      helptext
    end


    # Help for EditUserDetailsDialog.
    # @param [String] user_type type of edited user (local/system/ldap/nis)
    # @param [String] what what to do with a user (add_user/edit_user)
    # @return [String] help text
    def EditUserDetailsDialogHelp(user_type, what)
      # help text 1/8
      helptext = Ops.add(
        Ops.add(
          Ops.add(
            _("<p>\nAdditional user data includes:\n</p>"),
            # help text 2/8, %1 is number
            Builtins.sformat(
              _(
                "<p>\n" +
                  "<b>User ID (uid):</b>\n" +
                  "Each user is known to the system by a unique number,\n" +
                  "the user ID. For normal users, you should use\n" +
                  "a UID larger than %1 because the smaller UIDs are used\n" +
                  "by the system for special purposes and pseudo logins.\n" +
                  "</p>\n"
              ),
              UsersCache.GetMaxUID("system")
            )
          ),
          # help text 3/8
          _(
            "<p>\n" +
              "If you change the UID of an existing user, the rights of the files\n" +
              "this user owns must be changed. This is done automatically\n" +
              "for the files in the user's home directory, but not for files \n" +
              "located elsewhere.</p>\n"
          )
        ),
        # help text 4/8
        _(
          "<p>\n" +
            "<b>Home Directory:</b>\n" +
            "The home directory of the user. Normally this is\n" +
            "/home/username. \n" +
            "To select an existing directory, click <b>Browse</b>.\n" +
            "</p>\n"
        )
      )
      if what == "add_user"
        # help text for user's home directory mode
        helptext = Ops.add(
          helptext,
          _(
            "<p>Optionally, set the <b>Home Directory Permission Mode</b> for this user's home directory different from the default.</p>"
          )
        )

        defaults = Users.GetLoginDefaults
        helptext = Ops.add(
          helptext,
          # alternate helptext 4.5/8; %1 is directory (e.g. '/etc/skel')
          Builtins.sformat(
            _(
              "<p>To create only an empty home directory,\n" +
                "check <b>Empty Home</b>. Otherwise, the new home directory\n" +
                "is created from the default skeleton (%1).</p>\n"
            ),
            Ops.get_string(defaults, "skel", "")
          )
        )
      else
        # help text for Move to new location checkbox
        helptext = Ops.add(
          helptext,
          _(
            "<p>If changing the location of a user's home directory, move the contents of the current directory with <b>Move to New Location</b>, activated by default. Otherwise a new home directory is created without any of the existing data.</p>"
          )
        )
      end

      if user_type == "ldap"
        helptext = Ops.add(
          helptext,
          # alternate helptext 5/8
          _(
            "<p>\n" +
              "The home directory of an LDAP user can be changed only on the\n" +
              "file server.</p>"
          )
        )
      elsif user_type == "system" || user_type == "local"
        helptext = Ops.add(
          helptext,
          # alternate helptext 5/8
          _(
            "<p><b>Additional Information:</b>\n" +
              "Some additional user data could be set here. This field may contain up to\n" +
              "three parts, separated by commas. The standard usage is to write\n" +
              "<i>office</i>,<i>work phone</i>,<i>home phone</i>. This information is \n" +
              "shown when you use the <i>finger</i> command on this user.</p>\n"
          )
        )
      end

      # help text 6/8
      helptext = Ops.add(
        Ops.add(
          Ops.add(
            helptext,
            _(
              "<p>\n" +
                "<b>Login Shell:</b>\n" +
                "The login shell (command interpreter) for the user.\n" +
                "Select a shell from the list of all shells installed\n" +
                "on your system.\n" +
                "</p>"
            )
          ),
          # help text 7/8
          _(
            "<p>\n" +
              "<b>Default Group:</b>\n" +
              "The primary group to which the user belongs. Select one group\n" +
              "from the list of all groups existing on your system.\n" +
              "</p>"
          )
        ),
        # help text 8/8
        _(
          "<p>\n" +
            "<b>Additional Groups:</b>\n" +
            "Select additional groups in which the user should be a member.\n" +
            "</p>\n"
        )
      )
      helptext
    end

    # help text for dualogs with plugins
    def PluginDialogHelp
      # helptxt for plugin dialog 1/2
      _(
        "<p>Here, see the list of plug-ins, the\nextensions of user and group configuration.</p>\n"
      ) +
        # helptext for plugin dialog 2/3
        _(
          "The check mark in the left part of the table indicates that the plug-in\nis currently in use."
        ) +
        # helptext for plugin dialog 3/3
        _(
          "<p>Start the detailed configuration of a particular plug-in by selecting <b>Launch</b>.</p>"
        )
    end


    # Help for usersSave.
    # @return [String] help text
    def usersSaveDialogHelp
      # help texts 1/1
      _(
        "<p>\n" +
          "Save the current user and group settings to the system.\n" +
          "</p>"
      )
    end

    # Help for editing password settings
    # @return [String] help text
    def EditUserPasswordDialogHelp
      # Help text 1/6
      _(
        "<p>Activate <b>Force Password Change</b> to force the user to change the\n" +
          "password at the next login. If <b>Last Password Change</b> is set to\n" +
          "<i>Never</i>, the user will be forced to change the password.</p>"
      ) +
        # Help text 2/6
        _(
          "<p>\n" +
            "<b>Days before Password Expiration to Issue Warning</B><BR>\n" +
            "Users can be warned before their passwords expire. Set \n" +
            "how long before expiration the warning should be issued. Set -1 to disable\n" +
            "the warning. \n" +
            "</p>\n"
        ) +
        # Help text 3/6
        _(
          "<P><B>Days after Password Expires with Usable Login</B><BR>\n" +
            "Users can log in after their passwords have expired. Set how many days to\n" +
            "allow login. Use -1 for unlimited access.\n" +
            "</P>\n"
        ) +
        #Help text 4/6
        _(
          "<P><B>Maximum Number of Days for the Same Password</B><BR>Set how many days a user \ncan use the same password before it expires.</P>\n"
        ) +
        # Help text 5/6
        _(
          "<P><B>Minimum Number of Days for the Same Password</B><BR>Set the minimum age of \na password before a user is allowed to change it.</P>\n"
        ) +
        # Help text 6/6 : Don't reorder letters YYYY-MM-DD, date must be set in this format
        _(
          "<P><B>Expiration Date</B><BR>Set the date when this account expires. \n" +
            "The date must be in the format YYYY-MM-DD. \n" +
            "Leave it empty if this account never expires.</P>\n"
        )
    end

    def AuthentizationDialogHelp
      help_text =
        # help text 1/2
        _(
          "<p>\n" +
            "<b>Configuration Overview</b><br>\n" +
            "Here, see a summary of modules that could affect sources\n" +
            "of user accounts or authentication type.\n" +
            "</p>\n"
        ) +
          # help text 2/2
          _(
            "<p>\n" +
              "<b>Changing the Values</b><br>\n" +
              "You can configure these settings by running appropriate modules. Select the module with <b>Configure</b>.\n" +
              "</p>\n"
          )

      help_text
    end
  end
end
