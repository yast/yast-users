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

require "yast2/secret_attributes"

module Y2Users
  # Password configuration for an user
  class Password
    # Password value. Can be any subclass of {PasswordValue}.
    #
    # @return [PasswordValue, nil] nil if password is not set
    attr_accessor :value

    # Last password change
    #
    # @return [Date, :force_change, nil] date of the last change or :force_change when the next
    #   login forces the user to change the password or nil for disabled aging feature.
    attr_accessor :last_change

    # The minimum number of days required between password changes
    #
    # @return [Integer] 0 means no restriction
    attr_accessor :minimum_age

    # The maximum number of days the password is valid. After that, the password is forced to be
    # changed.
    #
    # @return [Integer, nil] nil means no restriction
    attr_accessor :maximum_age

    # The number of days before the password is to expire that the user is warned for changing the
    # password.
    #
    # @return [Integer] 0 means no warning
    attr_accessor :warning_period

    # The number of days after the password expires that account is disabled
    #
    # @return [Integer, nil] nil means no limit
    attr_accessor :inactivity_period

    # Date when whole account expires
    #
    # @return [Date, nil]  nil if there is no account expiration
    attr_accessor :account_expiration

    # Creates a new password with a plain value
    #
    # @param value [String] plain password
    # @return [Password]
    def self.create_plain(value)
      new(PasswordPlainValue.new(value))
    end

    # Creates a new password with an encrypted value
    #
    # @param value [String] encrypted password
    # @return [Password]
    def self.create_encrypted(value)
      new(PasswordEncryptedValue.new(value))
    end

    # Constructor
    #
    # @param value [PasswordValue]
    def initialize(value)
      @value = value
    end

    def clone
      cloned = super
      cloned.value = value.clone

      cloned
    end

    # Password equality
    #
    # Two passwords are equal if all their attributes are equal
    #
    # @param other [Password]
    # @return [Boolean]
    def ==(other)
      [:value, :last_change, :minimum_age, :maximum_age, :warning_period, :inactivity_period,
       :account_expiration].all? do |a|
        public_send(a) == other.public_send(a)
      end
    end

    alias_method :eql?, :==
  end

  # Represents a password value. Its specific type is defined as subclass and can be queried.
  class PasswordValue
    include Yast2::SecretAttributes

    secret_attr :content

    # Constructor
    #
    # @param content [String] password value
    def initialize(content)
      self.content = content
    end

    # Whether it is a plain password
    #
    # @return [Boolean]
    def plain?
      false
    end

    # Whether it is an encrypted password
    #
    # @return [Boolean]
    def encrypted?
      false
    end

    # Password value equality
    #
    # Two password values are equal if their content are equal
    #
    # @param other [PasswordValue]
    # @return [Boolean]
    def ==(other)
      content == other.content
    end

    alias_method :eql?, :==
  end

  # Represents a plain password value
  class PasswordPlainValue < PasswordValue
    # @see PasswordValue#plain?
    def plain?
      true
    end
  end

  # Represents an encrypted password value
  class PasswordEncryptedValue < PasswordValue
    # @see PasswordValue#encrypted?
    def encrypted?
      true
    end

    # Whether the encrypted password is locked
    #
    # @return [Boolean]
    def locked?
      content.start_with?("!$")
    end

    # Whether the encrypted password is disabled
    #
    # @return [Boolean]
    def disabled?
      ["*", "!"].include?(content)
    end
  end
end
