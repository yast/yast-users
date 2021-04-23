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

require "yast2/execute"

module Y2Users
  module Linux
    # Writes users and groups to the system using Yast2::Execute and standard
    # linux tools.
    #
    # NOTE: currently it only creates new users, removing or modifying users is
    # still not covered. No group management either.
    #
    # A brief history of the differences with the Yast::Users (perl) module:
    #
    # Both useradd and YaST::Users call the helper script useradd.local which
    # performs several actions at the end of the user creation process. Those
    # actions has changed over time. See chapters below.
    #
    # Chapter 1 - skel files
    #
    # Historically, both useradd and YaST took the reponsibility of copying
    # files from /etc/skel to the home directory of the new user.
    #
    # Then, useradd.local copied files from /usr/etc/skel (note the "usr" part)
    #
    # So the files from /usr/etc/skel were always copied to the home directory
    # if possible, no matter if it was actually created during the process or it
    # already existed before (both situations look the same to useradd.local).
    #
    # Equally, YaST always copied the /etc/skel files and did all the usual
    # operations in the home directory (eg. adjusting ownership).
    #
    # That YaST behavior was different to what useradd does. It skips copying
    # skel and other actions if the home directory existed in advance.
    #
    # The whole management of skel changed as consequence of boo#1173321
    #   - Factory sr#872327 and SLE sr#235709
    #     * useradd.local does not longer deal with skel files
    #     * useradd copies files from both /etc/skel and /usr/etc/skel
    #   - https://github.com/yast/yast-users/pull/240
    #     * Equivalent change for Yast (copy both /etc/skel & /usr/etc/skel)
    #
    # Chapter 2 - updating the NIS database
    #
    # At some point in time, useradd.local took care of updating the NIS
    # database executing "make -C /var/yp". That part of the script was commented
    # out at some point in time, so it does not do it anymore.
    #
    # Yast::Users also takes care of updating the NIS database calling the very
    # same command (introduced at commit eba0eddc5d72 on Jan 7, 2004)
    # Bear in mind that YaST only executes that "make" command once, after
    # having removed, modified and created all users. So the database gets
    # updated always, no matter whether useradd.local has been called.
    #
    #
    #
    # NOTE: we need to check why nscd_passwd is relevant
    # NOTE: no support for the Yast::Users option no_skeleton
    # NOTE: no support for the Yast::Users chown_home=0 option (what is good for?)

    # TODO: no plugin support yet
    # TODO: other password attributes like #maximum_age, #inactivity_period, etc.
    # TODO: no authorized keys yet
    class Writer
      # Constructor
      #
      # NOTE: right now we consider the system is empty, so we only receive one parameter.
      #   But in the future we might need another configuration describing the initial state,
      #   so we can compare and know what changes are actually needed.
      #
      # @param configuration [Y2User::Configuration] configuration containing the users
      #   and groups that should exist in the system after writing
      def initialize(configuration)
        @configuration = configuration
      end

      # Performs the changes in the system
      def write
        configuration.users.map { |user| add_user(user) }
        # TODO: update the NIS database (make -C /var/yp) if needed
        # TODO: remove the passwd cache for nscd (bug 24748, 41648)
        nil
      end

    private

      # Configuration containing the users and groups that should exist in the system after writing
      #
      # @return [Y2User::Configuration]
      attr_reader :configuration

      def add_user(user)
        # useradd pepe --uid X --gid Y --shell S --home-dir H --comment GECOS
        #   --expiredate password.account_expiration
        # if home_wanted?
        #   --create-home
        #   --btrfs-subvolume-home if so
        # end
        #
        # chpasswd
      end
    end
  end
end
