# Copyright (c) [2021] SUSE LLC
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

require "y2issues"
require "y2users/validation_config"

module Y2Users
  # Internal class to validate the attributes of a {User} object.
  # This is not part of the stable API.
  class UserValidator
    include Yast::I18n

    # Issue location describing the User#name attribute
    NAME_LOC = "field:name".freeze
    # Issue location describing the User#full_name attribute
    FULL_NAME_LOC = "field:full_name".freeze
    private_constant :NAME_LOC, :FULL_NAME_LOC

    # Constructor
    #
    # @param user [Y2Users::User] see {#user}
    def initialize(user)
      textdomain "users"
      @user = user
    end

    # Returns a list of issues found while checking the user validity
    #
    # @param skip [Array<Symbol>] list of user attributes that should not be checked
    # @return [Y2Issues::List]
    def issues(skip: [])
      list = Y2Issues::List.new

      if !skip.include?(:name)
        err = check_length
        add_fatal_issue(list, err, NAME_LOC)

        err = check_characters
        add_fatal_issue(list, err, NAME_LOC)

        err = check_username_conflict
        add_fatal_issue(list, err, NAME_LOC)
      end

      if !skip.include?(:full_name)
        err = check_full_name
        add_fatal_issue(list, err, FULL_NAME_LOC)
      end

      if !skip.include?(:password) && user.password
        user.password_issues.map do |issue|
          list << issue
        end
      end

      list
    end

  private

    # @return [Y2Users::User] user to validate
    attr_reader :user

    # @return [ValidationConfig]
    def config
      @config ||= ValidationConfig.new
    end

    # Adds a fatal issue to the given list to represent the given error, if any
    def add_fatal_issue(list, error, location)
      return if error.empty?

      list << Y2Issues::Issue.new(error, location: location, severity: :error)
    end

    MIN_LENGTH = 2
    # reason: see for example man utmp, UT_NAMESIZE
    MAX_LENGTH = 32
    def check_length
      # note duplicite string as in UsersSimple. Keep them in sync.
      return _("No username entered.\nTry again.") if user.name.nil? || user.name.empty?

      return "" if (MIN_LENGTH..MAX_LENGTH).include?(user.name.size)

      # note duplicite string as in UsersSimple. Keep them in sync.
      format(_("The username must be between %i and %i characters in length.\n" \
        "Try again."), MIN_LENGTH, MAX_LENGTH)
    end

    LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz".freeze
    NUMBERS = "0123456789".freeze
    # Regexp for allowed characters.
    # NOTE: this is based on default in login.defs, maybe read it on running system?
    CHAR_REGEXP = /\A[#{LETTERS}_][#{LETTERS}#{NUMBERS}_.-]*[#{LETTERS}#{NUMBERS}_.$-]?\z/.freeze
    def check_characters
      return "" if user.name =~ CHAR_REGEXP

      # note duplicite string as in UsersSimple. Keep them in sync.
      _("The username may contain only\n" \
        "Latin letters and digits, \"-\", \".\", and \"_\"\n" \
        "and must begin with a letter or \"_\".\n" \
        "Try again.")
    end

    # hard-coded list of known system users
    KNOWN_USERS = [
      "root",
      "bin",
      "uucp",
      "daemon",
      "lp",
      "mail",
      "news",
      "uucp",
      "games",
      "man",
      "at",
      "wwwrun",
      "ftp",
      "named",
      "gdm",
      "postfix",
      "sshd",
      "ntp",
      "ldap",
      "nobody",
      "amanda",
      "vscan",
      "bigsister",
      "wnn",
      "cyrus",
      "dpbox",
      "gnats",
      "gnump3d",
      "hacluster",
      "irc",
      "mailman",
      "mdom",
      "mysql",
      "oracle",
      "postgres",
      "pop",
      "sapdb",
      "snort",
      "squid",
      "stunnel",
      "zope",
      "radiusd",
      "otrs",
      "privoxy",
      "vdr",
      "icecream",
      "bitlbee",
      "dhcpd",
      "distcc",
      "dovecot",
      "fax",
      "partimag",
      "avahi",
      "beagleindex",
      "casaauth",
      "dvbdaemon",
      "festival",
      "haldaemon",
      "icecast",
      "lighttpd",
      "nagios",
      "pdns",
      "polkituser",
      "pound",
      "pulse",
      "quagga",
      "sabayon-admin",
      "tomcat",
      "pegasus",
      "cimsrvr",
      "ulogd",
      "uuidd",
      "suse-ncc",
      "messagebus",
      "nx"
    ].freeze

    # Checks whether the user name already exists in the config or it is included in a hard-coded
    # list of system user names that are expected to exist in a system.
    #
    # @return [String] empty if no error
    def check_username_conflict
      usernames = []
      usernames += user.config.users.without(user.id).map(&:name).compact if user.attached?
      usernames += KNOWN_USERS

      return "" unless usernames.include?(user.name)

      # note duplicite string as in UsersSimple. Keep them in sync.
      _("There is a conflict between the entered\n" \
        "username and an existing username.\n" \
        "Try another one.")
    end

    def check_full_name
      return "" unless user.full_name

      return "" if user.full_name !~ /[:,]/

      # note duplicite string as in UsersSimple. Keep them in sync.
      _("The user's full name cannot contain\n" \
        "\":\" or \",\" characters.\n" \
        "Try again.")
    end
  end
end
