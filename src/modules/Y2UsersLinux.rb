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
require "y2users/users_module/reader"
require "y2users/users_module/commit_config_reader"
require "y2users/linux/writer"
require "y2issues"

module Yast
  # Module to make possible for Yast::Users to use some of the Y2Users::Linux components, like
  # the {Y2Users::Linux::Writer} and the # {Y2Users::Linux::UseraddConfigReader
  class Y2UsersLinuxClass < Module
    include Yast::Logger

    # Persists the changes from {Yast::Users} to the system
    #
    # @return [Array<String>] errors triggered during the write process, empty array if everything
    #   went fine
    def write_from_users_module
      system_config, target_config = Y2Users::UsersModule::Reader.new.read
      commit_configs = Y2Users::UsersModule::CommitConfigReader.new.read
      writer = Y2Users::Linux::Writer.new(target_config, system_config, commit_configs)

      issues = writer.write
      log_errors(issues)

      issues.map(&:message)
    end

    publish function: :write_from_users_module, type: "list <string> ()"

  private

    # Writes the given list of issues to the YaST logs if needed
    def log_errors(issues)
      return if issues.empty?

      presenter = Y2Issues::Presenter.new(issues)
      log.error("Errors found calling Y2Users::Linux::Writer: #{presenter.to_plain}")
    end
  end

  Y2UsersLinux = Y2UsersLinuxClass.new
end
