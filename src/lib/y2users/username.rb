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

module Y2Users
  # Helper module for generating valid usernames
  module Username
    class << self
      # Generates a valid username based on the first word of given input
      #
      # @param text [String] text for generating the username (usually the user fullname)
      # @return [String] a valid username
      def generate_from(text)
        username = text.split(" ").first || ""
        username = transliterate(username)
        username = sanitize(username)
        username.downcase
      end

    private

      # Command for convert text from one character encoding to another
      # @see .transliterate
      ICONV = "/usr/bin/iconv".freeze
      private_constant :ICONV

      # Valid characters for a username
      # @see .sanitize
      VALID_CHARS =
        "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ._-".freeze
      private_constant :VALID_CHARS

      # Converts UTF-8 characters in given input to similar ASCII ones
      #
      # @param text [String] the text to be transformed
      # @return [String] transliterated text or the given input if the execution of the command
      #   fails
      def transliterate(text)
        Yast::Execute.locally!(
          ICONV,
          "-t", "ascii//translit",
          stdin: text, stdout: :capture
        ).chomp
      rescue Cheetah::ExecutionFailed => e
        log.error("Something went wrong when executing iconv for #{text} - #{e.message}")
        text
      end

      # Cleans up given input preserving only username VALID_CHARS
      #
      # @param text [String] the input to be sanitized
      # @return [String] sanitized string
      def sanitize(text)
        text.delete("^#{VALID_CHARS}")
      end
    end
  end
end
