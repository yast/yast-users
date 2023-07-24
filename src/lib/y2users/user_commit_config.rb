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

module Y2Users
  # Class for configuring the commit action for a user
  #
  # @see CommitConfig
  #
  # TODO: It has been mentioned that it is confusing to have a single class to define the
  # configuration of the different actions that can be performed on a user. In the future we could
  # consider to split it.
  class UserCommitConfig
    # Name of the user this configuration applies to
    #
    # @return [String]
    attr_accessor :username

    # Whether the home should be empty after the creation (i.e., do not use skels)
    #
    # @return [Boolean]
    attr_writer :home_without_skel

    # Whether to move the content of the current home directory to the new location
    #
    # @return [Boolean]
    attr_writer :move_home

    # Whether this user should own the home. This is useful when changing the home to reuse an
    # existing directory/subvolume.
    #
    # @return [Boolean]
    attr_writer :adapt_home_ownership

    # Whether to remove user home when removing it.
    #
    # @return [Boolean]
    attr_writer :remove_home

    # @return [Boolean]
    def home_without_skel?
      !!@home_without_skel
    end

    # @return [Boolean]
    def move_home?
      !!@move_home
    end

    # @return [Boolean]
    def adapt_home_ownership?
      !!@adapt_home_ownership
    end

    # @return [Boolean]
    def remove_home?
      !!@remove_home
    end
  end
end
