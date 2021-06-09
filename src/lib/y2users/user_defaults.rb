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

require "forwardable"

module Y2Users
  # Class to represent the configuration and default values to apply when creating new users
  #
  # For historical reasons (see {#skel} and {#secondary_groups} for some background), this is a
  # superset of the useradd configuration represented by a {UseraddConfig} object. Apart from the
  # attributes included there, this class includes mechanisms used by AutoYaST to overwrite the
  # default skel directory and to specify a default list of secondary groups.
  class UserDefaults
    extend Forwardable

    def_delegators :@useradd,
      :group, :home, :umask, :expiration, :inactivity_period, :shell, :usrskel

    # @!attribute [r] group
    #   See {UseraddConfig#group}
    #   @return [String, nil]

    # @!attribute [r] home
    #   See {UseraddConfig#home}
    #   @return [String, nil]

    # @!attribute [r] umask
    #   See {UseraddConfig#umask}
    #   @return [String, nil]

    # @!attribute [r] expiration
    #   See {UseraddConfig#expiration}
    #   @return [String, nil]

    # @!attribute [r] inactivity_period
    #   See {UseraddConfig#inactivity_period}
    #   @return [Integer, nil]

    # @!attribute [r] shell
    #   See {UseraddConfig#shell}
    #   @return [String, nil]

    # @!attribute [r] usrskel
    #   See {UseraddConfig#usrskel}
    #   @return [String, nil]

    # Constructor
    #
    # @param useradd [UseraddConfig]
    def initialize(useradd)
      @useradd = useradd
      @secondary_groups = []
    end

    # Part of the configuration that is directly managed by useradd
    #
    # @return [UseraddConfig]
    attr_accessor :useradd

    # List of secondary groups to assign new users to
    #
    # Currently this is only honored by AutoYaST (represented in the <user_defaults> section of the
    # profile by the "groups" and "no_groups" entries). There is no counterpart in the useradd
    # configuration, since the corresponding key GROUPS was dropped from the useradd configuration
    # with no substitute when the package "pwdutils" was dropped in favor of "shadow" (see more at
    # bsc#1099153). Even if the GROUPS key is present in /etc/default/useradd, its value will be
    # completely ignored by useradd and in most cases by YaST (with the exception of AutoYaST).
    #
    # @return [Array<String>]
    attr_accessor :secondary_groups

    # Skeleton directory that can override the default skel used by useradd
    #
    # @see UseraddConfig#skel
    #
    # For reasons explained in the documentation of {UseraddConfig}, there is no setter in that
    # class to write the value of the "skel" option and make it persistent in the useradd
    # configuration of the final system. But the <user_defaults> section of the AutoYaST profile
    # allows to specify a custom skel directory. This attribute makes possible to handle that.
    # By default {#skel} just returns the value of {UseraddConfig#skel}, but this class also
    # offers a setter that can be used to override its value (setting the value to nil restores
    # the default behavior of just returning the corresponding useradd value).
    #
    # @return [String, nil]
    def skel
      @skel || useradd.skel
    end

    attr_writer :skel

    # @see Config#copy
    def copy
      defaults = self.class.new(useradd.dup)
      defaults.secondary_groups = secondary_groups.dup
      defaults.skel = @skel
      defaults
    end
  end
end
