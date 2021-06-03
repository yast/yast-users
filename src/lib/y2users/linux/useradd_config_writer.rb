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

module Y2Users
  module Linux
    # Configures useradd in the target system according to a given {UseraddConfig} object
    class UseraddConfigWriter
      include Yast::I18n
      include Yast::Logger
      Yast.import "ShadowConfig"

      # Constructor
      #
      # @param config [Config] see #config
      # @param initial_config [Config] see #initial_config
      def initialize(config, initial_config)
        textdomain "users"

        @config = config
        @initial_config = initial_config
      end

      # Performs the changes in the system
      #
      # @param issues [Y2Issues::List] the list of issues found while writing changes
      def write(issues)
        write_useradd(issues)
        write_shadow_config
      end

    private

      # General configuration object containing the useradd configuration to apply to the system
      #
      # @return [Config]
      attr_reader :config

      # Initial state of the system (usually a Y2Users::Config.system in a running system) that will
      # be compared with {#config} to know what changes need to be performed.
      #
      # @return [Config]
      attr_reader :initial_config

      # Object containing the useradd configuration
      #
      # @return [UseraddConfig]
      def useradd_config
        config&.useradd
      end

      # Object containing the useradd configuration fron the initial state
      #
      # @return [UseraddConfig]
      def initial_useradd_config
        initial_config&.useradd
      end

      # Value for the given attribute in the target useradd configuration
      #
      # @param attr [Symbol]
      def value(attr)
        useradd_config&.public_send(attr)
      end

      # Value for the given attribute in the initial useradd configuration
      #
      # @param attr [Symbol]
      def initial_value(attr)
        initial_useradd_config&.public_send(attr)
      end

      # Command for writing the useradd default values
      USERADD = "/usr/sbin/useradd".freeze
      private_constant :USERADD

      # Mapping between {UseraddConfig} attributes and useradd arguments
      USERADD_ATTRS = {
        group:             "--gid",
        home:              "--base-dir",
        shell:             "--shell",
        expiration:        "--expiredate",
        inactivity_period: "--inactive"
      }.freeze
      private_constant :USERADD_ATTRS

      # Writes the attributes that are handled via "useradd -D"
      #
      # @param issues [Y2Issues::List]
      def write_useradd(issues)
        return unless write_useradd?

        # Instead of modifying directly the /etc/default/useradd file using the agent
        # etc.default.useradd, we rely on "useradd -D". That should be more future-proof because:
        #   - It should keep working if some of the parameters is moved to another file
        #   - It will report an issue if we write a value that useradd considers to be wrong
        #
        # useradd allows to specify several default values at one shot like this:
        #   useradd -D --base-dir /people --gid users --shell /bin/zsh
        # But that works on a all-or-nothing fashion, ie. if one of the values is wrong (eg. the
        # group "users" does not exist) none of the values is written
        #
        # To reduce the impact of a wrong value, let's change them one by one
        USERADD_ATTRS.each do |attr, arg_name|
          configure_useradd_attr(attr, arg_name, issues)
        end
      end

      # Whether executing "useradd -D" is really needed
      #
      # @return [Boolean]
      def write_useradd?
        return false if useradd_config.nil?
        return true if initial_useradd_config.nil?

        USERADD_ATTRS.keys.any? { |attr| value(attr) != initial_value(attr) }
      end

      # Writes the attributes that are handled via login.defs
      def write_shadow_config
        return unless write_shadow_config?

        Yast::ShadowConfig.set(:umask, value(:umask))
        Yast::ShadowConfig.write
      end

      # Whether writing to login.defs is really needed
      #
      # @return [Boolean]
      def write_shadow_config?
        return false if value(:umask).nil?

        value(:umask) != initial_value(:umask)
      end

      # @see #write_useradd
      #
      # @param attr [Symbol]
      # @param arg [String]
      # @param issues [Y2Issues::List]
      def configure_useradd_attr(attr, arg, issues)
        value = value(attr)
        return if value.nil?

        Yast::Execute.on_target!(USERADD, "-D", arg, value)
      rescue Cheetah::ExecutionFailed => e
        issues << Y2Issues::Issue.new(
          # TRANSLATORS: %s is the name of one of the useradd default values, like 'HOME' or 'GROUP'
          format(_("Something went wrong writing the useradd default for '%s'"), arg)
        )
        log.error("Error configuring useradd' - #{e.message}")
      end
    end
  end
end
