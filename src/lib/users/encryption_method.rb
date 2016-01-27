# Copyright (c) 2016 SUSE LLC.
#  All Rights Reserved.

#  This program is free software; you can redistribute it and/or
#  modify it under the terms of version 2 or 3 of the GNU General
#  Public License as published by the Free Software Foundation.

#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
#  GNU General Public License for more details.

#  You should have received a copy of the GNU General Public License
#  along with this program; if not, contact SUSE LLC.

#  To contact SUSE about this file by physical or electronic mail,
#  you may find current contact information at www.suse.com

require "yast"
Yast.import "UsersSimple"

module Users
  # Object oriented wrapper to read and set the password encryption method at
  # Yast::UsersSimple
  #
  # @example
  #   md5 = EncryptionMethod.new("md5") # Raises exception on wrong id
  #   puts "The system is configured to use #{md5.label}" if md5.current?
  class EncryptionMethod
    class Error < RuntimeError
    end

    class NotFoundError < Error
    end

    extend Yast::I18n
    textdomain "users"

    attr_accessor :id

    # "blowfish" is also known to UsersSimple, but it's not longer offered
    # as a valid option. See fate#312321
    LABELS = {
      # TRANSLATORS: encryption type
      "des"    => _("DES"),
      # TRANSLATORS: encryption type
      "md5"    => _("MD5"),
      # TRANSLATORS: encryption type
      "sha256" => _("SHA-256"),
      # TRANSLATORS: encryption type
      "sha512" => _("SHA-512")
    }
    private_constant :LABELS

    DEFAULT_ID = "sha512"
    private_constant :DEFAULT_ID

    def initialize(id)
      EncryptionMethod.raise_if_not_found(id)
      @id = id
    end

    def ==(other)
      other.is_a?(EncryptionMethod) && other.id == id
    end
    alias_method :eql?, :==

    # Internationalized name of the method
    #
    # @return [String]
    def label
      LABELS[id]
    end

    # Check whether this is the selected method for the system
    #
    # @return [Boolean]
    def current?
      id == Yast::UsersSimple.EncryptionMethod
    end

    # Sets this method as the chosen one
    def set_as_current
      Yast::UsersSimple.SetEncryptionMethod(id)
    end

    # List of all supported encryption methods
    #
    # @return [Array<EncryptionMethod>]
    def self.all
      LABELS.keys.sort.map { |id| new(id) }
    end

    # Current encryption method
    #
    # Raises an exception if the id returned by UsersSimple is unknown
    #
    # @return [EncryptionMethod]
    def self.current
      id = Yast::UsersSimple.EncryptionMethod
      new(id)
    end

    # Default encryption method, the one used if not changed by the user
    #
    # @return [EncryptionMethod]
    def self.default
      new(DEFAULT_ID)
    end

  private

    def self.raise_if_not_found(id)
      return if LABELS.has_key?(id)
      raise NotFoundError, "#{id} is not a known encryption method"
    end
  end
end
