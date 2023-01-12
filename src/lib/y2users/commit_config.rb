# Copyright (c) [2023] SUSE LLC
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

require "y2users/user_commit_config_collection"

module Y2Users
  # Class for configuring the commit actions
  #
  # Writers can receive an object of this class in order to decide what actions to perform and how.
  # For example, a writer can use the commit config to check whether the content of the home
  # directory of a specific user should be moved or not.
  class CommitConfig
    # Configuration for each user
    #
    # @return [UserCommitConfigCollection]
    attr_reader :user_configs

    # Constructor
    def initialize
      @user_configs = UserCommitConfigCollection.new
    end
  end
end
