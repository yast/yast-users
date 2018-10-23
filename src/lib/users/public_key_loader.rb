# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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

require "fileutils"
require "tmpdir"
require "transfer/file_from_url"

module Y2Users
  # This class retrieves SSH public keys from an USB stick
  class PublicKeyLoader
    include Yast::I18n # missing in yast2-update
    include Yast::Transfer::FileFromUrl

    TYPES = [ "dsa", "ecdsa", "ed25519", "rsa" ].freeze

    def from_usb_stick
      with_tmpdir do |tmpdir|
        files.each_with_object([]) do |name, keys|
          keys.concat(find_keys(name, tmpdir))
        end
      end
    end

  private

    # List of key filenames
    #
    # @return [Array<String>]
    def files
      TYPES.map { |t| "id_#{t}.pub" }
    end

    # Support several types and some kind of generic name (id.pub).
    def find_keys(name, tmpdir)
      localfile = File.join(tmpdir, name)
      get_file_from_url(
        scheme: "usb", host: "", urlpath: "/#{name}", localfile: localfile,
        urltok: {}, destdir: ""
      )
      return [] unless File.exist?(localfile)
      File.readlines(localfile).map(&:strip)
    end

    def with_tmpdir
      dir = Dir.mktmpdir
      begin
        yield dir
      ensure
        ::FileUtils.remove_entry_secure(dir)
      end
    end
  end
end
