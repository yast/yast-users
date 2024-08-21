# Copyright (c) 2016 SUSE LLC.
#  All Rights Reserved.
#
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of version 2 or 3 of the GNU General
#  Public License as published by the Free Software Foundation.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, contact SUSE LLC.
#
#  To contact SUSE about this file by physical or electronic mail,
#  you may find current contact information at www.suse.com

require "yast"
require "users/ssh_authorized_keyring"

Yast.import "Message"

module Yast
  # This module add support to handle SSH authorized keys.
  #
  # It's inteded to be a thin layer on top of SSHAuthorizedKeyring to be used by
  # yast2-users module (which is mainly written in Perl).
  class SSHAuthorizedKeysClass < Module
    include Logger

    def main
      textdomain "users"
    end

    # Read keys from a given home directory
    #
    # @see Y2Y2Users::SSHAuthorizedKeyring#read_keys
    def read_keys(home)
      keyring = Y2Users::SSHAuthorizedKeyring.new(home)
      keyring.read_keys
    end

    # Write keys to a given home directory
    #
    # @see Y2Y2Users::SSHAuthorizedKeyring#write_keys
    def write_keys(home, keys)
      keyring = Y2Users::SSHAuthorizedKeyring.new(home)
      keyring.add_keys(keys)
      keyring.write_keys
    rescue Y2Users::SSHAuthorizedKeyring::HomeDoesNotExist => e
      log.warn(e.message)
      Report.Warning(
        # TRANSLATORS: '%s' is a directory path
        format(_("Home directory '%s' does not exist\n" \
                 "so authorized keys will not be written."), e.path)
      )
    rescue Y2Users::SSHAuthorizedKeyring::NotRegularSSHDirectory => e
      log.warn(e.message)
      Report.Warning(
        # TRANSLATORS: '%s' is a directory path
        format(_("'%s' exists but it is not a directory. It might be\n" \
                 "a security issue so authorized keys will not\n" \
                 "be written."), e.path)
      )
    rescue Y2Users::SSHAuthorizedKeyring::NotRegularAuthorizedKeysFile => e
      log.warn(e.message)
      Report.Warning(
        # TRANSLATORS: '%s' is a directory path
        format(_("'%s' exists but it is not a file. It might be\n" \
                 "a security issue so authorized keys will not\n" \
                 "be written."), e.path)
      )
    rescue Y2Users::SSHAuthorizedKeyring::CouldNotCreateSSHDirectory => e
      log.warn(e.message)
      Report.Warning(
        Message.UnableToCreateDirectory(e.path) + "\n" +
          _("Authorized keys will not be written.")
      )
    end

    publish function: :read_keys, type: "boolean (string)"
    publish function: :write_keys, type: "boolean (string, list <string>)"
  end

  SSHAuthorizedKeys = SSHAuthorizedKeysClass.new
  SSHAuthorizedKeys.main
end
