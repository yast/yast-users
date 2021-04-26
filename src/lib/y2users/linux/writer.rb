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
    # NOTE: we need to check why nscd_passwd is relevant
    # NOTE: no support for the Yast::Users option no_skeleton
    # NOTE: no support for the Yast::Users chown_home=0 option (what is good for?)

    # TODO: no plugin support yet
    # TODO: other password attributes like #maximum_age, #inactivity_period, etc.
    # TODO: no authorized keys yet
    class Writer
      include Yast::Logger
      # Constructor
      #
      # @param config [Y2User::Config] see #config
      # @param initial_config [Y2User::Config] see #initial_config
      def initialize(config, initial_config)
        @config = config
        @initial_config = initial_config
      end

      # Performs the changes in the system
      def write
        config.users.map { |user| add_user(user) }
        # TODO: update the NIS database (make -C /var/yp) if needed
        # TODO: remove the passwd cache for nscd (bug 24748, 41648)
        nil
      end

    private

      # Configuration containing the users and groups that should exist in the system after writing
      #
      # @return [Y2User::Config]
      attr_reader :config

      # Initial state of the system that will be compared with {#config} to know what changes need
      # to be performed
      #
      # @return [Y2User::Config]
      attr_reader :initial_config

      # Command for creating new users
      USERADD = "/usr/sbin/useradd".freeze
      private_constant :USERADD

      # Command for setting a user password
      #
      # This command is "preferred" over
      #   * the `passwd` command because the password at this point is already
      #   encrypted (see Y2Users::Password#value). Additionally, this command
      #   requires to enter the password twice, which it's not possible using
      #   the Cheetah stdin argument.
      #
      #   * the `--password` useradd option because the encrypted
      #   password is visible as part of the process name
      CHPASSWD = "/usr/sbin/chpasswd".freeze
      private_constant :CHPASSWD

      def add_user(user)
        Yast::Execute.on_target!(USERADD, *useradd_options(user))
        Yast::Execute.on_target!(CHPASSWD, *chpasswd_options(user)) if user.password&.value
      rescue Cheetah::ExecutionFailed => e
        if e.message.include?(USERADD)
          log.error("Error creating user '#{user.name}' - #{e.message}")
        else
          log.error("Error setting password for '#{user.name}' - #{e.message}")
        end
      end

      # Generates and returns the options expected by `useradd` for given user
      #
      # @param user [Y2Users::User]
      # @return [Array<String>]
      def useradd_options(user)
        opts = {
          "--uid"        => user.uid,
          "--gid"        => user.gid,
          "--shell"      => user.shell,
          "--home-dir"   => user.home,
          "--expiredate" => user.expire_date.to_s,
          "--comment"    => user.gecos.join(",")
        }
        opts = opts.reject { |_, v| v.to_s.empty? }.flatten

        if user.system?
          opts << "--system"
        else
          opts.concat(create_home_options(user))
        end

        opts << user.name
        opts
      end

      # Options for `useradd` to create the home directory
      #
      # @param _user [Y2Users::User]
      # @return [Array<String>]
      def create_home_options(_user)
        # TODO: "--btrfs-subvolume-home" if needed
        ["--create-home"]
      end

      # Generates and returns the options expected by `chpasswd` for given user
      #
      # @param user [Y2Users::User]
      # @return [Array<String, Hash>]
      def chpasswd_options(user)
        opts = ["-e"] # Y2Users::Password#value returns the encrypted password
        opts << {
          stdin:    [user.name, user.password&.value].join(":"),
          recorder: cheetah_recorder
        }
        opts
      end

      # Custom Cheetah recorder to prevent leaking the password to the logs
      #
      # @return [Recorder]
      def cheetah_recorder
        @cheetah_recorder ||= Recorder.new(Yast::Y2Logger.instance)
      end

      # Class to prevent Yast::Execute from leaking to the logs passwords
      # provided via stdin
      class Recorder < Cheetah::DefaultRecorder
        # To prevent leaking stdin, just do nothing
        def record_stdin(_stdin); end
      end
    end
  end
end
