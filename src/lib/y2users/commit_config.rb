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

module Y2Users
  # Class for configuring the commit action for a user
  #
  # Writers can receive a collection of objects of this class (see {CommitConfigCollection}) in
  # order to decide what actions to perform over the user. For example, a writer can use the commit
  # config to check whether the content of the home directory should be moved or not.
  class CommitConfig
    # Name of the user this commit config applies to
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
  end
end
