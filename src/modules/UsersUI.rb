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

# File:	modules/UsersUI.ycp
# Package:	Configuration of users and groups
# Summary:	UI-related routines to be run from perl modules (Users.pm etc.)
# Author:	Jiri Suchomel <jsuchome@suse.cz>
#
# $Id$
require "yast"

module Yast
  class UsersUIClass < Module
    def main
      Yast.import "UI"
      textdomain "users"

      Yast.import "Label"
    end

    # Return the translated name for system user
    def SystemUserName(name)
      # TODO users are added manualy.... :-(
      _SystemUsers = {
        # User name for user: "root"
        "root"                                           => _(
          "root"
        ),
        # User name for user: "bin"
        "bin"                                            => _(
          "bin"
        ),
        # User name for user: "daemon"
        "Daemon"                                         => _(
          "Daemon"
        ),
        # User name for user: "lp"
        "Printing daemon"                                => _(
          "Printing Daemon"
        ),
        # User name for user: "mail"
        "Mailer daemon"                                  => _(
          "Mailer Daemon"
        ),
        # User name for user: "news"
        "News system"                                    => _(
          "News System"
        ),
        # User name for user: "uucp"
        "Unix-to-Unix CoPy system"                       => _(
          "Unix-to-Unix Copy System"
        ),
        # User name for user: "games"
        "Games account"                                  => _(
          "Games Account"
        ),
        # User name for user: "man"
        "Manual pages viewer"                            => _(
          "Manual Page Viewer"
        ),
        # User name for user: "at"
        "Batch jobs daemon"                              => _(
          "Batch Jobs Daemon"
        ),
        # User name for user: "wwwrun"
        "WWW daemon apache"                              => _(
          "WWW Daemon Apache"
        ),
        # User name for user: "ftp"
        "FTP account"                                    => _(
          "FTP Account"
        ),
        # User name for user: "named"
        "Nameserver daemon"                              => _(
          "Name Server Daemon"
        ),
        # User name for user: "gdm"
        "Gnome Display Manager daemon"                   => _(
          "GNOME Display Manager Daemon"
        ),
        # User name for user: "postfix"
        "Postfix Daemon"                                 => _(
          "Postfix Daemon"
        ),
        # User name for user: "sshd"
        "SSH daemon"                                     => _(
          "SSH Daemon"
        ),
        # User name for user: "ntp"
        "NTP daemon"                                     => _(
          "NTP Daemon"
        ),
        # User name for user: "ldap"
        "User for OpenLDAP"                              => _(
          "User for OpenLDAP"
        ),
        # User name for user: "nobody"
        "nobody"                                         => _(
          "Nobody"
        ),
        # User name for user: "amanda"
        "Amanda admin"                                   => _(
          "Amanda Admin"
        ),
        # User name for user: "vscan"
        "Vscan account"                                  => _(
          "Vscan Account"
        ),
        # User name for user: "bigsister"
        "Big Sister"                                     => _(
          "Big Sister"
        ),
        # User name for user: "wnn"
        "Wnn System Account"                             => _(
          "Wnn System Account"
        ),
        # User name for user: "cyrus"
        "User for cyrus-imapd"                           => _(
          "User for cyrus-imapd"
        ),
        # User name for user: "dpbox"
        "DpBox account"                                  => _(
          "DpBox Account"
        ),
        # User name for user: "gnats"
        "GNATS GNU Backtracking System"                  => _(
          "GNATS GNU Backtracking System"
        ),
        # User name for user: "gnump3d"
        "GNUMP3 daemon"                                  => _(
          "GNUMP3 Daemon"
        ),
        # User name for user: "hacluster"
        "heartbeat processes"                            => _(
          "Heartbeat Processes"
        ),
        # User name for user: "irc"
        "IRC daemon"                                     => _(
          "IRC Daemon"
        ),
        # User name for user: "mailman"
        "GNU mailing list manager"                       => _(
          "GNU Mailing List Manager"
        ),
        # User name for user: "mdom"
        "Mailing list agent"                             => _(
          "Mailing List Agent"
        ),
        # User name for user: "mysql"
        "MySQL database admin"                           => _(
          "MySQL Database Admin"
        ),
        # User name for user: "oracle"
        "Oracle user"                                    => _(
          "Oracle User"
        ),
        # User name for user: "postgres"
        "PostgreSQL Server"                              => _(
          "PostgreSQL Server"
        ),
        # User name for user: "pop"
        "POP admin"                                      => _(
          "POP Admin"
        ),
        # User name for user: "sapdb"
        "SAPDB account"                                  => _(
          "SAPDB Account"
        ),
        # User name for user: "snort"
        "Snort network monitor"                          => _(
          "Snort Network Monitor"
        ),
        # User name for user: "squid"
        "WWW-proxy squid"                                => _(
          "WWW Proxy Squid"
        ),
        # User name for user: "stunnel"
        "Daemon user for stunnel (universal SSL tunnel)" => _(
          "Daemon User for stunnel (Universal SSL Tunnel)"
        ),
        # User name for user: "zope"
        "Zope"                                           => _(
          "Zope"
        ),
        # User name for user: "radiusd"
        "Radius daemon"                                  => _(
          "Radius Daemon"
        ),
        # User name for user: "otrs"
        "OTRS System User"                               => _(
          "OTRS System User"
        ),
        # User name for user: "privoxy"
        "Daemon user for privoxy"                        => _(
          "Daemon User for privoxy"
        ),
        # User name for user: "vdr"
        "Video Disk Recorder"                            => _(
          "Video Disk Recorder"
        ),
        # User name for user: "icecream"
        "Icecream Daemon"                                => _(
          "Icecream Daemon"
        ),
        # User name for user: "bitlbee"
        "Bitlbee Daemon User"                            => _(
          "Bitlbee Daemon User"
        ),
        # User name for user: "dhcpd"
        "DHCP server daemon"                             => _(
          "DHCP Server Daemon"
        ),
        # User name for user: "distcc"
        "Distcc Daemon"                                  => _(
          "Distcc Daemon"
        ),
        # User name for user: "dovecot"
        "Dovecot imap daemon"                            => _(
          "Dovecot IMAP Daemon"
        ),
        # User name for user: "fax"
        "Facsimile agent"                                => _(
          "Facsimile Agent"
        ),
        # User name for user: "partimag"
        "Partimage Daemon User"                          => _(
          "Partimage Daemon User"
        ),
        # User name for user: "avahi"
        "User for Avahi"                                 => _(
          "User for Avahi"
        ),
        # User name for user: "beagleindex"
        "User for Beagle indexing"                       => _(
          "User for Beagle indexing"
        ),
        # User name for user: "casaauth"
        "casa_atvd System User"                          => _(
          "casa_atvd System User"
        ),
        # User name for user: "dvbdaemon"
        "User for DVB daemon"                            => _(
          "User for DVB daemon"
        ),
        # User name for user: "festival"
        "Festival daemon"                                => _(
          "Festival daemon"
        ),
        # User name for user: "haldaemon"
        "User for haldaemon"                             => _(
          "User for haldaemon"
        ),
        # User name for user: "icecast"
        "Icecast streaming server"                       => _(
          "Icecast streaming server"
        ),
        # User name for user: "lighttpd"
        "user for lighttpd"                              => _(
          "User for lighttpd"
        ),
        # User name for user: "nagios"
        "User for Nagios"                                => _(
          "User for Nagios"
        ),
        # User name for user: "pdns"
        "pdns"                                           => _(
          "User for PowerDNS"
        ),
        # User name for user: "polkituser"
        "PolicyKit"                                      => _(
          "PolicyKit"
        ),
        # User name for user: "pound"
        "Pound"                                          => _(
          "User for Pound"
        ),
        # User name for user: "pulse"
        "PulseAudio daemon"                              => _(
          "PulseAudio daemon"
        ),
        # User name for user: "quagga"
        "Quagga routing daemon"                          => _(
          "Quagga routing daemon"
        ),
        # User name for user: "sabayon-admin"
        "Sabayon user"                                   => _(
          "Sabayon user"
        ),
        # User name for user: "tomcat"
        "Tomcat - Apache Servlet/JSP Engine"             => _(
          "Tomcat - Apache Servlet/JSP Engine"
        ),
        # User name for user: "tomcat"
        "Apache Tomcat"                                  => _(
          "Apache Tomcat"
        ),
        # User name for user: "pegasus"
        # User name for user: "cimsrvr"
        "tog-pegasus OpenPegasus WBEM/CIM services"      => _(
          "tog-pegasus OpenPegasus WBEM/CIM services"
        ),
        # User name for user: "ulogd"
        "ulog daemon"                                    => _(
          "ulog daemon"
        ),
        # User name for user: "uuidd"
        "User for uuidd"                                 => _(
          "User for uuidd"
        ),
        # User name for user: "suse-ncc"
        "Novell Customer Center User"                    => _(
          "Novell Customer Center User"
        )
      }
      Ops.get_string(_SystemUsers, name, name)
    end

    # Ask user for configuration type (standard or NIS)
    # @param [String] dir string directory with NIS settings
    # @return [Symbol] `passwd or `nis or `abort
    def getConfigurationType(dir)
      contents = VBox(
        # label
        Label(
          _(
            "You have installed a NIS master server.\n" +
              "It is configured to use a different database\n" +
              "of users and groups than the local system \n" +
              "database in the /etc directory.\n" +
              "Select which one to configure.\n"
          )
        ),
        VSpacing(1),
        RadioButtonGroup(
          Id(:configtype),
          VBox(
            # radio button
            RadioButton(
              Id(:passwd),
              Opt(:hstretch),
              _("&Local (/etc directory)"),
              true
            ),
            VSpacing(1),
            # radio button, %1 is path (eg. /etc)
            RadioButton(
              Id(:nis),
              Opt(:hstretch),
              Builtins.sformat(_("&NIS (%1 directory)"), dir),
              false
            )
          )
        ),
        VSpacing(1),
        HBox(
          HStretch(),
          PushButton(Id(:ok), Opt(:default), Label.OKButton),
          HStretch(),
          PushButton(Id(:abort), Label.AbortButton),
          HStretch()
        )
      )
      UI.OpenDialog(contents)
      ret = nil
      while ret == nil
        ret = Convert.to_symbol(UI.UserInput)
        next if ret != :cancel && ret != :ok
      end
      if ret == :ok
        ret = Convert.to_symbol(UI.QueryWidget(Id(:configtype), :CurrentButton))
      end
      UI.CloseDialog
      ret
    end

    # If we can ask and are a NIS server, ask which set of users
    # to administer and set UserWriteStack accordingly.
    # @param [String] basedir the directory, where the data are stored
    # @return directory
    def ReadNISConfigurationType(basedir)
      ypdir = Convert.to_string(
        SCR.Read(path(".sysconfig.ypserv.YPPWD_SRCDIR"))
      )
      while Builtins.substring(ypdir, Ops.subtract(Builtins.size(ypdir), 1)) == "/"
        ypdir = Builtins.substring(
          ypdir,
          0,
          Ops.subtract(Builtins.size(ypdir), 1)
        )
      end
      ypdir = basedir if ypdir == "" || ypdir == nil
      if ypdir != basedir
        type = getConfigurationType(ypdir)
        return nil if type == :abort
        ypdir = basedir if type != :nis
      end
      ypdir
    end

    def ChooseTemplates(user_templates, group_templates)
      user_templates = deep_copy(user_templates)
      group_templates = deep_copy(group_templates)
      user_template = Ops.get(user_templates, 0, "")
      group_template = Ops.get(group_templates, 0, "")

      # label above radiobutton box
      rbu_buttons = VBox(Left(Label(_("User Templates"))))
      # label above radiobutton box
      rbg_buttons = VBox(Left(Label(_("Group Templates"))))
      Builtins.foreach(user_templates) do |templ|
        rbu_buttons = Builtins.add(
          rbu_buttons,
          Left(RadioButton(Id(templ), templ, true))
        )
      end
      Builtins.foreach(group_templates) do |templ|
        rbg_buttons = Builtins.add(
          rbg_buttons,
          Left(RadioButton(Id(templ), templ, true))
        )
      end
      rb_users = RadioButtonGroup(Id(:rbu), rbu_buttons)
      rb_groups = RadioButtonGroup(Id(:rbg), rbg_buttons)

      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          HSpacing(1),
          VBox(
            HSpacing(50),
            VSpacing(0.5),
            # label
            Label(
              _(
                "Multiple templates are defined as default. Select the one to read."
              )
            ),
            VSpacing(0.5),
            user_templates == [] ? Empty() : rb_users,
            VSpacing(0.5),
            group_templates == [] ? Empty() : rb_groups,
            HBox(
              PushButton(Id(:ok), Opt(:default), Label.OKButton),
              PushButton(Id(:cancel), Label.CancelButton)
            )
          ),
          HSpacing(1)
        )
      )
      ret = UI.UserInput
      if ret == :ok
        if user_templates != []
          user_template = Convert.to_string(
            UI.QueryWidget(Id(:rbu), :CurrentButton)
          )
        end
        if group_templates != []
          group_template = Convert.to_string(
            UI.QueryWidget(Id(:rbg), :CurrentButton)
          )
        end
      end
      UI.CloseDialog
      { "user" => user_template, "group" => user_template }
    end

    # Error messages for errors detected during reading via .passwd agent
    # @param errno [Integer] number returned by passwd-agent
    # @param more [String] additional information
    # @return error message
    def GetPasswdErrorMessage(errno, more)
      last =
        # error message 2/2 (= next sentence)
        _("Correct them manually before running the YaST users module again.")

      read_error = {
        2 => Builtins.sformat(
          # error message 1/2: %1 is file name, %2 is username, %3 is next sentence (2/2)
          _(
            "There are multiple users with the same name (\"%2\") in the file %1.\n%3"
          ),
          "/etc/passwd",
          more,
          last
        ),
        3 => Builtins.sformat(
          # error message 1/2: %1 is file name, %2 is username, %3 is next sentence (2/2)
          _(
            "There are multiple users with the same name (\"%2\") in the file %1.\n%3"
          ),
          "/etc/shadow",
          more,
          last
        ),
        6 => Builtins.sformat(
          # error message 1/2: %1 is file name, %2 is groupname, %3 next sentence (2/2)
          _(
            "There are multiple groups with the same name (\"%2\") in the file %1.\n%3"
          ),
          "/etc/group",
          more,
          last
        ),
        7 => Builtins.sformat(
          # error message 1/2: %1 is file name, %2 is line
          _(
            "There is a strange line in the file %1:\n" +
              "%2\n" +
              "Perhaps the number of colons is wrong or some line entry is missing.\n" +
              "Correct the file manually before running the YaST users module again."
          ),
          "/etc/passwd",
          more
        ),
        8 => Builtins.sformat(
          # error message 1/2: %1 is file name, %2 is line
          _(
            "There is a strange line in the file %1:\n" +
              "%2\n" +
              "Perhaps the number of colons is wrong or some line entry is missing.\n" +
              "Correct the file manually before running the YaST users module again."
          ),
          "/etc/group",
          more
        ),
        9 => Builtins.sformat(
          # error message 1/2: %1 is file name
          _(
            "There is a strange line in the file %1.\n" +
              "Perhaps the number of colons is wrong or some line entry is missing.\n" +
              "Correct the file manually before running the YaST users module again."
          ),
          "/etc/shadow"
        )
      }

      # default error message
      Ops.get_locale(read_error, errno, _("Cannot read user or group data."))
    end


    # recode the string from "environment encoding" to UTF-8
    def RecodeUTF(text)
      Convert.to_string(UI.Recode(WFM.GetEnvironmentEncoding, "UTF-8", text))
    end


    def HashPassword(method, pw)
      return Builtins.cryptmd5(pw) if method == "md5"
      return Builtins.cryptblowfish(pw) if method == "blowfish"
      return Builtins.cryptsha256(pw) if method == "sha256"
      return Builtins.cryptsha512(pw) if method == "sha512"
      Builtins.crypt(pw)
    end

    publish :function => :SystemUserName, :type => "string (string)"
    publish :function => :ReadNISConfigurationType, :type => "string (string)"
    publish :function => :ChooseTemplates, :type => "map (list <string>, list <string>)"
    publish :function => :GetPasswdErrorMessage, :type => "string (integer, string)"
    publish :function => :RecodeUTF, :type => "string (string)"
    publish :function => :HashPassword, :type => "string (string, string)"
  end

  UsersUI = UsersUIClass.new
  UsersUI.main
end
