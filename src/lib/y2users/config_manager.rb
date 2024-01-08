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

require "singleton"
require "y2users/config"

module Y2Users
  # Holds references to different configuration instances.
  # It is not mandatory for config to be registered here.
  class ConfigManager
    include Singleton

    def initialize
      @register = {}
    end

    # Register config as given id
    # @param [Config] config
    # @param [Symbol] as id of config
    # @note if given id is already registered, it is overwritten
    def register(config, as:)
      raise ArgumentError, "#{as.inspect} is not Symbol" unless as.is_a?(Symbol)

      @register[as] = config
    end

    # Unregister given id
    # @param [Symbol] id of config
    def unregister(id)
      @register.delete(id)
    end

    # List of registered ids
    # @return [Array<Symbol>]
    def known_ids
      @register.keys
    end

    # returns config for given id
    # @param [Symbol] id of config
    # @return [Config,nil] config registered for given id or nil if not found
    def config(id)
      @register[id]
    end

    # Gets system configuration.
    # @param [#read] reader used to read system configuration.
    #   If not specified it will decide itself which one to use.
    # @param [Boolean] force_read if it can get previous result of system or
    #   force re-read from system.
    # @return [Config]
    def system(reader: nil, force_read: false)
      config = config(:system)
      return config if config && !force_read

      if !reader
        require "y2users/linux/reader"
        reader = Linux::Reader.new
      end

      config = reader.read
      register(config, as: :system)

      config
    end

    # Gets config used to store the configuration to apply.
    # @return [Config,nil] returns nil if no target is yet initialized
    # @note in various scenarious target does not need to be exact target state, but just
    # interstate that is then merged with real system state
    def target
      config(:target)
    end

    # Sets the target configuration, see {#target}.
    # @param [Config] config Note that config should not be frozen as it is expected to be modified
    def target=(config)
      register(config, as: :target)
    end
  end
end
