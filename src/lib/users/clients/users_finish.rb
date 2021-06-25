# Copyright (c) [2016-2021] SUSE LLC
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
require "installation/finish_client"
# target file to run system reader on target system
require "yast2/target_file"
require "y2issues"
require "y2users/autoinst/reader"
require "y2users/config_merger"
require "y2users/autoinst/config_merger"
require "y2users/linux/reader"
require "y2users/linux/writer"
require "y2users/config"
require "y2users/config_manager"
require "y2issues/reporter"

module Yast
  # This client takes care of setting up the users at the end of the installation
  class UsersFinishClient < ::Installation::FinishClient
    include Logger

    def initialize
      textdomain "users"

      Yast.import "Users"
      Yast.import "Report"
    end

    # Write users
    #
    # The linux writer will process all the differences between the system and the target configs.
    # The target config is created from the system one, and then it adds the users configured during
    # the (auto)installation. As result, target and system configs should only differ on the new
    # added users and on the root user configuration.
    #
    # All the issues detected by the writer are reported to the user.
    def write
      writer = Y2Users::Linux::Writer.new(target_config, system_config)
      issues = writer.write

      return if issues.empty?

      log.error(issues.inspect)
      Y2Issues.report(issues, warn: :continue, error: :continue)
    end

  protected

    # @see Implements ::Installation::FinishClient#modes
    def modes
      [:installation, :live_installation, :autoinst]
    end

    # @see Implements ::Installation::FinishClient#title
    def title
      _("Writing Users Configuration...")
    end

  private

    # Generates the proper target config, depending on the installation mode
    #
    # @return [Y2Users::Config]
    def target_config
      return @target_config if @target_config

      @target_config = system_config.copy

      merger = if Mode.autoinst && Yast::Stage.initial
        # Use an specific merger in the 1st stage
        Y2Users::Autoinst::ConfigMerger
      else
        Y2Users::ConfigMerger
      end

      merger.new(@target_config, Y2Users::ConfigManager.instance.target).merge

      @target_config
    end

    def check_ids
      validator = Y2Users::IdsValidator.new(Y2Users::ConfigManager.instance.target)

      validator.issues
    end

    # System config, which contains all the current users on the system
    #
    # @return [Y2Users::Config]
    def system_config
      @system_config ||= Y2Users::ConfigManager.instance.system(force_read: true)
    end
  end
end
