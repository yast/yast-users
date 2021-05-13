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

require "yast"
require "yast/i18n"
require "yast2/execute"
require "y2issues"

module Y2Users
  module Linux
    # Writes users and groups to the system using Yast2::Execute and standard
    # linux tools.
    #
    # NOTE: currently it only creates new users or modifies the password value
    # of existing ones.  Removing or fully modifying users is still not covered.
    # No group management or passowrd configuration either.
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
      include Yast::I18n
      include Yast::Logger
      # Constructor
      #
      # @param config [Y2User::Config] see #config
      # @param initial_config [Y2User::Config] see #initial_config
      def initialize(config, initial_config)
        textdomain "y2users"

        @config = config
        @initial_config = initial_config
      end

      # Performs the changes in the system
      #
      # @return [Y2Issues::List] the list of issues found while writing changes; empty when none
      def write
        issues = Y2Issues::List.new

        # handle groups first as it does not depend on users uid, but it is vice versa
        new_groups = config.groups.map(&:id) - initial_config.groups.map(&:id)
        new_groups.map! { |id| config.groups.find { |g| g.id == id } }
        new_groups.each { |g| add_group(g, issues) }

        # TODO: modify group?

        users_finder.added.each { |u| add_user(u, issues) }
        users_finder.modified.each { |nu, ou| modify(nu, ou, issues) }

        # TODO: update the NIS database (make -C /var/yp) if needed
        # TODO: remove the passwd cache for nscd (bug 24748, 41648)

        issues
      end

    private

      # Configuration containing the users and groups that should exist in the system after writing
      #
      # @return [Y2User::Config]
      attr_reader :config

      # Initial state of the system (usually a Y2User::Config.system in a running system) that will
      # be compared with {#config} to know what changes need to be performed.
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

      def users_finder
        @users_finder ||= UsersFinder.new(initial_config, config)
      end

      # Executes the command for creating the user
      #
      # @param user [Y2User::User] the user to be created on the system
      # @param issues [Y2Issues::List] a collection for adding an issue if something goes wrong
      def add_user(user, issues)
        Yast::Execute.on_target!(USERADD, *useradd_options(user))
        change_password(user, issues) if user.password
      rescue Cheetah::ExecutionFailed => e
        issues << Y2Issues::Issue.new(
          format(_("The user '%{username}' could not be created"), username: user.name)
        )
        log.error("Error creating user '#{user.name}' - #{e.message}")
      end

      # Command for creating new groups
      GROUPADD = "/usr/sbin/groupadd".freeze
      private_constant :GROUPADD

      # Executes the command for creating the group
      #
      # @param group [Y2User::Group] the group to be created on the system
      # @param issues [Y2Issues::List] a collection for adding an issue if something goes wrong
      def add_group(group, issues)
        args = [GROUPADD]
        args << "--gid" << group.gid if group.gid
        # TODO: system groups?
        Yast::Execute.on_target!(args)
      rescue Cheetah::ExecutionFailed => e
        issues << Y2Issues::Issue.new(
          format(_("The group '%{groupname}' could not be created"), groupname: group.name)
        )
        log.error("Error creating group '#{group.name}' - #{e.message}")
      end

      USERMOD_ATTRS = [:home, :shell, :gecos].freeze

      def modify(new_user, old_user, issues)
        change_password(new_user, issues) if new_user.password != old_user.password

        usermod_changes = USERMOD_ATTRS.any? do |attr|
          !new_user.public_send(attr).nil? &&
            (new_user.public_send(attr) != old_user.public_send(attr))
        end
        # usermod also manage suplimentary groups, so compare also them
        usermod_changes ||= different_groups?(new_user, old_user)
        usermod_modify(new_user, issues) if usermod_changes
      end

      def different_groups?(lhu, rhu)
        lhu.groups(with_primary: false).sort != rhu.groups(with_primary: false).sort
      end

      USERMOD = "/usr/sbin/usermod".freeze
      private_constant :USERMOD
      def usermod_modify(new_user, issues)
        opts = {
          "--home"    => new_user.home,
          "--shell"   => new_user.shell,
          "--comment" => new_user.gecos.join(","),
          "--groups"  => new_users.groups(with_primary: false).join(",")
        }

        opts = opts.compact.flatten
        opts << "--move-home" if opts.include?("--home")
        opts << new_user.name

        Yast::Execute.on_target!(USERMOD, *opts)
      rescue Cheetah::ExecutionFailed => e
        issues << Y2Issues::Issue.new(
          format(_("Failed to modify user '%{username}'"), username: new_user.name)
        )
        log.error("Error modifying '#{new_user.name}' - #{e.message}")
      end

      # Executes the command for setting the password of given user
      #
      # @param user [Y2User::User]
      # @param issues [Y2Issues::List] a collection for adding an issue if something goes wrong
      def change_password(user, issues)
        return unless user.password&.value

        Yast::Execute.on_target!(CHPASSWD, *chpasswd_options(user))
      rescue Cheetah::ExecutionFailed => e
        issues << Y2Issues::Issue.new(
          format(_("The password for '%{username}' could not be set"), username: user.name)
        )
        log.error("Error setting password for '#{user.name}' - #{e.message}")
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
          "--comment"    => user.gecos.join(","),
          "--groups"     => user.groups(with_primary: false).join(",")
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
        opts = []
        opts << "-e" if user.password&.value&.encrypted?
        opts << {
          stdin:    [user.name, user.password&.value&.content].join(":"),
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

      # Helper class to find specific users
      class UsersFinder
        # Constructor
        #
        # @param initial [Config]
        # @param target [Config]
        def initialize(initial, target)
          @initial = initial
          @target = target
        end

        # Users from the target config that do not exist in the initial config
        #
        # @return [Array<User>]
        def added
          ids = target_ids - initial_ids

          ids.map { |i| find_user(target, i) }
        end

        def modified
          ids = target_ids & initial_ids

          pairs = ids.map { |i| [find_user(target, i), find_user(initial, i)] }

          pairs.reject { |target, initial| target == initial }
        end

      private

        # Initial config
        #
        # @return [Config]
        attr_reader :initial

        # Target config
        #
        # @return [Config]
        attr_reader :target

        # Finds an user with the given id inside the given config
        #
        # @param config [Config]
        # @param id [Integer]
        #
        # @return [User, nil] nil if user with the given id is not found
        def find_user(config, id)
          config.users.find { |u| u.id == id }
        end

        # All the users id from the initial config
        #
        # @return [Array<Integer>]
        def initial_ids
          users_id(initial)
        end

        # All the users id from the target config
        #
        # @return [Array<Integer>]
        def target_ids
          users_id(target)
        end

        # Users id from the given config
        #
        # @param config [Config]
        # @return [Array<Integer>]
        def users_id(config)
          config.users.map(&:id).compact
        end
      end
    end
  end
end
