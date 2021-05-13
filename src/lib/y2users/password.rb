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
require "y2users/shadow_date_helper"

module Y2Users
  # Password configuration for an user
  class Password
    # Password value. Can be any subclass of {PasswordValue}.
    #
    # @return [PasswordValue, nil] nil if password is not set
    attr_accessor :value

    # Aging information for the password, based on the content of the third field of a shadow file
    #
    # [PasswordAging, nil] nil means information is unknown (eg. new user without a shadow entry)
    attr_accessor :aging

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
      return false unless other.is_a?(self.class)

      [:value, :aging, :minimum_age, :maximum_age, :warning_period, :inactivity_period,
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
      return false unless other.is_a?(self.class)

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

  # Represents one entry in the third field of the shadow file
  class PasswordAging
    include ShadowDateHelper

    # Constructor
    #
    # @param value [String, Date] content of the field, automatically converted to the right format
    #   if provided as a Date object
    def initialize(value = "")
      value = date_to_shadow_string(value) if value.is_a?(Date)
      @content = value
    end

    # Content of the field
    #
    # @return [String]
    attr_accessor :content

    def to_s
      content
    end

    # Whether password aging features are enabled
    #
    # @return [Boolean]
    def enabled?
      content != ""
    end

    # Sets the content to the value that disables password aging features
    def disable
      self.content = ""
    end

    # Whether the user must change the password in the next login
    #
    # @return [Boolean]
    def force_change?
      content == "0"
    end

    # Sets the content to the value that enforces a password change in the next login
    def force_change
      self.content = "0"
    end

    # Date of the latest password change, or nil if that date is irrelevant
    #
    # The date is irrelevant in these two scenarios:
    #
    #   - password aging features are disabled (see {#enabled?})
    #   - the user is forced to change the password in the next login (see {#force_change?})
    #
    # @return [Date, nil]
    def last_change
      return nil unless enabled?
      return nil if force_change?

      shadow_string_to_date(content)
    end

    # Sets the content to the given date
    #
    # Note this enables the password aging features and sets {#force_change?} to false
    #
    # @param date [Date]
    def last_change=(date)
      self.content = date_to_shadow_string(date)
    end

    # Aging equality
    #
    # @param other [Object]
    # @return [Boolean]
    def ==(other)
      return false unless other.is_a?(self.class)

      content == other.content
    end
  end
end
