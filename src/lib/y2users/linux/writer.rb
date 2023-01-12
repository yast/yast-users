# Copyright (c) [2021-2023] SUSE LLC
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
require "y2users/user_commit_config_collection"
require "y2issues/with_issues"
require "y2users/linux/useradd_config_writer"
require "y2users/linux/login_config_writer"
require "y2users/linux/users_writer"
require "y2users/linux/groups_writer"

module Y2Users
  module Linux
    # Writes users and groups to the system using Yast2::Execute and standard
    # linux tools.
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
    # NOTE: no support for the Yast::Users option no_skeleton
    # NOTE: no support for the Yast::Users chown_home=0 option (what is good for?)

    # TODO: no plugin support yet
    # TODO: no authorized keys yet
    class Writer
      include Y2Issues::WithIssues

      # Constructor
      #
      # @param config [Config] see #config
      # @param initial_config [Config] see #initial_config
      # @param commit_configs [UserCommitConfigCollection] configuration to address the commit process
      def initialize(config, initial_config, commit_configs = nil)
        @config = config
        @initial_config = initial_config
        @commit_configs = commit_configs || UserCommitConfigCollection.new
      end

      # Performs the changes in the system
      #
      # @return [Y2Issues::List] the list of issues found while writing changes; empty when none
      def write
        with_issues do |issues|
          # handle groups first as it does not depend on users uid, but it is vice versa
          issues.concat(write_groups)
          # Useradd must be configured before creating the users (for obvious reasons) but after
          # creating the groups (in order to set a group as the default one for useradd, that group
          # must already exist in the system)
          issues.concat(write_useradd_config)
          issues.concat(write_users)
          write_login_config

          # After modifying the users and groups in the system, previous versions of yast-users used
          # to update the NIS database and invalidate the nscd (Name Service Caching Daemon) cache.
          #
          # The nscd cache cleanup was initially introduced in the context of bsc#39748 and
          # bsc#56648.
          # It's not longer needed for local users because:
          #  - The nscd daemon watches for changes in the relevant files (eg. /etc/passwd)
          #  - The current implementation relies on the tools in the shadow suite (eg. useradd),
          #    which already flush nscd and sssd caches when needed.
          #
          # Updating the NIS database (make -C /var/yp) was done if the system was the master server
          # of a NIS domain. But turns out it was likely not that useful and reliable as originally
          # intended for several reasons.
          #  - Detection of the NIS master server was not reliable
          #    * Based on the "yphelper" tool that was never intended to be used by third-party
          #      tools like YaST and that was moved from lib to libexec without YaST being adapted.
          #    * Working only if the command "domainname" printed the right result, something that
          #      seems to happen only if the host is configured both as a NIS server and client.
          #    * Alternative detection mechanisms (eg. relying on the output of the "yppoll"
          #      command) don't seem to be fully reliable either.
          #  - Trying to rebuild the database was pointless in many scenarios. For example, it makes
          #    no sense in (Auto)installation, since users are created before the NIS server could
          #    be configured. The same likely applies to Firstboot.
          #  - The NIS database is never updated by the shadow tools, to which yast2-users should
          #    align as much as possible.
          #  - Properly configured NIS servers are expected to have some mechanism (eg. cron job) to
          #    update the database periodically (eg. every 15 minutes).
          #
          # To avoid the need of maintaining code to perform actions that doesn't have a clear
          # benefit nowadays, YaST does not longer handle the status of nscd or NIS databases.
        end
      end

    private

      # Configuration containing the users and groups that should exist in the system after writing
      #
      # @return [Config]
      attr_reader :config

      # Initial state of the system (usually a Y2Users::Config.system in a running system) that will
      # be compared with {#config} to know what changes need to be performed.
      #
      # @return [Config]
      attr_reader :initial_config

      # Collection of commit configs to address the commit actions for each user
      #
      # @return [UserCommitConfigCollection]
      attr_reader :commit_configs

      # Writes the useradd configuration to the system
      #
      # @return [Y2Issues::List] the list of issues found while writing changes; empty when none
      def write_useradd_config
        UseraddConfigWriter.new(config, initial_config).write
      end

      # Writes the login settings to the system
      def write_login_config
        return unless config.login?

        LoginConfigWriter.new(config.login).write
      end

      # Writes (creates, edits or deletes) groups according to the configs
      #
      # @return [Y2Issues::List] the list of issues found while writing changes; empty when none
      def write_groups
        GroupsWriter.new(config, initial_config).write
      end

      # Writes (creates, edits or deletes) users according to the configs
      #
      # @return [Y2Issues::List] the list of issues found while writing changes; empty when none
      def write_users
        UsersWriter.new(config, initial_config, commit_configs).write
      end
    end
  end
end
