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
require "y2users/shadow_date"
require "yast2/equatable"

module Y2Users
  # Password configuration for an user
  class Password
    include Yast2::Equatable

    # Password value. Can be any subclass of {PasswordValue}.
    #
    # @return [PasswordValue, nil] nil if password is not set
    attr_accessor :value

    # Aging information for the password, based on the content of the third field of a shadow file
    #
    # [PasswordAging, nil] nil means information is unknown (eg. new user without a shadow entry)
    attr_accessor :aging

    # String representation of the minimum number of days required between password changes
    #
    # The "" and "0" values mean no restriction.
    #
    # @return [String, nil] nil if unknown
    attr_accessor :minimum_age

    # String representation of the maximum number of days the password is valid. After that, the
    # password is forced to be changed.
    #
    # The "" value means no restriction.
    #
    # @return [String, nil] nil if unknown
    attr_accessor :maximum_age

    # String representation of the number of days before the password is to expire that the user is
    # warned for changing the password.
    #
    # The "" and "0" values mean no warning.
    #
    # @return [String, nil] nil if unknown
    attr_accessor :warning_period

    # String representation of the number of days after the password expires that account is
    # disabled.
    #
    # The "" value means no inactivity period.
    #
    # @return [String, nil] nil if unknown
    attr_accessor :inactivity_period

    # Information about the account expiration, based on the content of the shadow file
    #
    # @return [AccountExpiration, nil] nil if unknown
    attr_accessor :account_expiration

    # Two passwords are equal if all their attributes are equal
    eql_attr :value, :aging, :minimum_age, :maximum_age, :warning_period, :inactivity_period,
      :account_expiration

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

    # Generates a deep copy of the password
    #
    # @return [Password]
    def copy
      password = clone
      password.value = value.clone
      password.aging = aging.clone
      password.account_expiration = account_expiration.clone

      password
    end
  end

  # Class to represent a field in the shadow file
  class ShadowField
    include Yast2::Equatable

    # Content of the field
    #
    # @return [String]
    attr_reader :content

    eql_attr :content

    # Constructor
    #
    # @param value [String]
    def initialize(value = "")
      @content = value
    end

    def to_s
      content
    end
  end

  # Class to represent a field in the shadow file, which can allocate a date
  class ShadowDateField < ShadowField
    # Constructor
    #
    # @param value [String, Date]
    def initialize(value = "")
      @content = value.is_a?(Date) ? to_shadow(value) : super
    end

  private

    # Converts a date to the shadow format
    #
    # @see ShadowDate
    #
    # @return [String]
    def to_shadow(date)
      ShadowDate.new(date).to_s
    end

    # Converts the content to a Date object
    #
    # @see ShadowDate
    #
    # @return [Date]
    def to_date
      ShadowDate.new(content).to_date
    end
  end

  # Represents a password value. Its specific type is defined as subclass and can be queried.
  class PasswordValue < ShadowField
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

  # Represents the last password change field of the shadow file
  class PasswordAging < ShadowDateField
    # Whether the password aging feature is enabled
    #
    # @return [Boolean]
    def enabled?
      !content.empty?
    end

    # Disables the password aging feature
    #
    # @note There is not a counterpart method called 'enable'. To activate password aging,
    #   use {#force_change} or {#last_change=}.
    def disable
      @content = ""
    end

    # Whether the user must change the password in the next login
    #
    # @return [Boolean]
    def force_change?
      content == "0"
    end

    # Sets the content to the value that enforces a password change in the next login
    def force_change
      @content = "0"
    end

    # Date of the latest password change, or nil if that date is irrelevant
    #
    # The date is irrelevant in these two scenarios:
    #
    #   - password aging features are disabled (see {#enabled?})
    #   - the user is forced to change the password in the next login (see {#force_change?})
    #
    # @see ShadowDateField#to_date
    #
    # @return [Date, nil]
    def last_change
      return nil unless enabled?
      return nil if force_change?

      to_date
    end

    # Sets the content to the given date
    #
    # @note This enables the password aging features and sets {#force_change?} to false.
    #
    # @see ShadowDateField#to_shadow
    #
    # @param date [Date]
    def last_change=(date)
      @content = to_shadow(date)
    end
  end

  # Represents the account expiration field of the shadow file
  class AccountExpiration < ShadowDateField
    # Whether the account has an expiration date
    #
    # @return [Boolean]
    def expire?
      !content.empty?
    end

    # Disables the account expiration
    #
    # @note There is not a counterpart method called 'enable'. To activate the account expiration,
    #   use {#date=} to assign an expiration date.
    def disable
      @content = ""
    end

    # Expiration date
    #
    # @see ShadowDateField#to_date
    #
    # @return [Date, nil] nil if the account does not expire
    def date
      return nil unless expire?

      to_date
    end

    # Sets an expiration date
    #
    # @see ShadowDateField#to_shadow
    #
    # @param [Date] date
    def date=(date)
      @content = to_shadow(date)
    end
  end
end
