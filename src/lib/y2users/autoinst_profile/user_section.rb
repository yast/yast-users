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

require "installation/autoinst_profile/section_with_attributes"
require "y2users/autoinst_profile/password_settings_section"

module Y2Users
  module AutoinstProfile
    # Represents a <user> element from a users list
    #
    #   <user>
    #     <fullname>SUSE user</fullname>
    #     <username>suse</username>
    #     <uid>1000</uid>
    #     <gid>100</gid>
    #     <home>/home/suse</home>
    #     <user_password>linux</user_password>
    #     <encrypted config:type="boolean">true</encrypted>
    #     <password_settings>
    #       <max>60</max>
    #       <warn>7</warn>
    #     </password_setting>
    #     <authorized_keys config:type="list">
    #       <listentry>ssh-rsa ...</listentry>
    #     </authorized_keys>
    #  </user>
    class UserSection < ::Installation::AutoinstProfile::SectionWithAttributes
      def self.attributes
        [
          { name: :username },
          { name: :fullname },
          { name: :forename },
          { name: :surname },
          { name: :uid },
          { name: :gid },
          { name: :home },
          { name: :home_btrfs_subvolume },
          { name: :shell },
          { name: :user_password },
          { name: :encrypted },
          { name: :password_settings },
          { name: :authorized_keys }
        ]
      end

      define_attr_accessors

      # @!attribute username
      #   @return [String,nil] Username (login name)

      # @!attribute fullname
      #   @return [String,nil] User's full name

      # @!attribute forename
      #   @return [String,nil] User's forename

      # @!attribute surname
      #   @return [String,nil] User's surname

      # @!attribute uid
      #   @return [String,nil] User's ID number

      # @!attribute gid
      #   @return [String,nil] Initial group ID

      # @!attribute home
      #   @return [String,nil] Home path
      #
      # @!attribute home_btrfs_subvolume
      #   @return [Boolean,nil] Whether to home directory in a Btrfs subvolume
      #
      # @!attribute shell
      #   @return [String,nil] Default shell
      #
      # @!attribute user_password
      #   @return [String,nil] User's password.
      #
      # @!attribute encrypted
      #   @return [Boolean,nil] Determine whether #user_password is encrypted or not.
      #
      # @!attribute password_settings
      #   @return [PasswordSettingSection,nil] Password settings
      #
      # @!attribute authorized_keys
      #   @return [Array<String>] Return authorized keys
      def initialize(parent = nil)
        super
        @authorized_keys = []
      end

      # Method used by {.new_from_hashes} to populate the attributes.
      #
      # @param hash [Hash] see {.new_from_hashes}
      def init_from_hashes(hash)
        super
        @authorized_keys = hash["authorized_keys"] if hash.key?("authorized_keys")
        return unless hash.key?("password_settings")

        @password_settings = PasswordSettingsSection.new_from_hashes(hash["password_settings"])
      end

      # Returns the section path
      #
      # The <user> section is an special case of a collection, so
      # we need to redefine the #section_path method completely.
      #
      # @return [Installation::AutoinstProfile::ElementPath] Section path or
      #   nil if the parent is not set
      def section_path
        return nil unless parent

        idx = parent.users.index(self)
        parent.section_path.join(idx)
      end
    end
  end
end
