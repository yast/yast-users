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
require "yast2/execute"
require "y2users/useradd_config"

module Y2Users
  module Linux
    # Reads the useradd configuration from the current system
    class UseraddConfigReader
      include Yast::Logger
      Yast.import "ShadowConfig"

      # Creates a {UseraddConfig} object with the system configuration
      #
      # @return [UseraddConfig]
      def read
        attrs = read_shadow_config.merge(read_useradd)
        UseraddConfig.new(attrs)
      end

    private

      # Command for reading the useradd default values
      USERADD = "/usr/sbin/useradd".freeze
      private_constant :USERADD

      # Mapping between useradd keys and {UseraddConfig} attributes
      USERADD_ATTRS = {
        group:             "GROUP",
        home:              "HOME",
        inactivity_period: "INACTIVE",
        expiration:        "EXPIRE",
        shell:             "SHELL",
        skel:              "SKEL",
        usrskel:           "USRSKEL",
        create_mail_spool: "CREATE_MAIL_SPOOL"
      }.freeze
      private_constant :USERADD_ATTRS

      # Values from "useradd -D"
      #
      # @return [Hash]
      def read_useradd
        output = Yast::Execute.on_target!(USERADD, "-D", stdout: :capture)
        values = output.lines.map(&:strip).map { |line| line.split("=", -1) }.to_h
        USERADD_ATTRS.keys.map { |attr| [attr, useradd_value(values, attr)] }.to_h
      rescue Cheetah::ExecutionFailed => e
        log.warn("Failed to read useradd default values' - #{e.message}")
        {}
      end

      # @see #read_useradd
      def useradd_value(values, attr)
        value = values[USERADD_ATTRS[attr]]

        case attr
        when :inactivity_period
          value.to_i
        when :create_mail_spool
          value == "yes"
        else
          value
        end
      end

      # Values from login.defs
      #
      # @return [Hash]
      def read_shadow_config
        { umask: Yast::ShadowConfig.fetch(:umask) }
      end
    end
  end
end
