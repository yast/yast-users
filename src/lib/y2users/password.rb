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

require "yast2/execute"
require "yast2/secret_attributes"

module Y2Users
  # Password configuration for user including its hashed value.
  class Password
    include Yast2::SecretAttributes

    # @return [String] login name for given password
    attr_reader :name

    # @!attribute value
    # @return [String, nil] Encrypted password. It can have several specific values:
    #   - "!" or "*" is disabled login by password
    #   - "" password-less login allowed
    #   - "!..." disabled password. After exclamation mark is old value that no longer can be used
    #     for login
    #   - nil means password is not yet set
    secret_attr :value

    # @!attribute plain_value
    # @return [String, nil] Plain unexcrypted password. Nil means not set or only encrypted one is known
    secret_attr :plain_value

    # @return [Date, :force_change, nil] Possible value are date of the last change, :force_change
    #   when next login force user to change it and nil for disabled aging feature
    attr_reader :last_change

    # @return [Integer] Minimum number of days before next password change. 0 means no restriction.
    attr_reader :minimum_age

    # @return [Integer, nil] Maximum number of days after which user is forced to change password.
    #   nil means no restriction.
    attr_reader :maximum_age

    # @return [Integer] Number of days before expire date happen. 0 means no warning.
    attr_reader :warning_period

    # @return [Integer, nil] Number of days after expire date when old password can be still used.
    #   nil means no limit
    attr_reader :inactivity_period

    # @return [Date, nil] Date when whole account expire or nil if there are no account expiration.
    attr_reader :account_expiration

    # @return [:local, :ldap, :unknown] where is user defined
    attr_reader :source

    # @see respective attributes for possible values
    # @todo: avoid long list of parameters
    # rubocop: disable Metrics/ParameterLists
    def initialize(config, name, value: nil, last_change: nil, minimum_age: nil,
      maximum_age: nil, warning_period: nil, inactivity_period: nil,
      account_expiration: nil, source: :unknown)
      @config = config
      @name = name
      @value = value
      @last_change = last_change
      @minimum_age = minimum_age
      @maximum_age = maximum_age
      @warning_period = warning_period
      @inactivity_period = inactivity_period
      @account_expiration = account_expiration
      @source = source
    end
    # rubocop: enable Metrics/ParameterLists

    ATTRS = [:name, :value, :last_change, :minimum_age, :maximum_age, :warning_period,
             :inactivity_period, :account_expiration].freeze

    # Clones password to different configuration object.
    # @return [Y2Users::Password] newly cloned password object
    def clone_to(config)
      attrs = ATTRS.each_with_object({}) { |a, r| r[a] = public_send(a) }
      attrs.delete(:name) # name is separate argument
      self.class.new(config, name, attrs)
    end

    # Compares password object if all attributes are same excluding configuration reference.
    # @return [Boolean] true if it is equal
    def ==(other)
      # do not compare configuration to allow comparison between different configs
      ATTRS.all? { |a| public_send(a) == other.public_send(a) }
    end
  end
end
