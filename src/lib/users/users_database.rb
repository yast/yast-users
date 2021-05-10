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

require "y2users"
require "y2users/linux/local_reader"

module Users
  # Class that allows to memorize the user's database (/etc/passwd and
  # associated files) of any partition.
  #
  # Used to implement the users importing functionality.
  #
  # It provides class methods to hold a list of databases (in case many
  # partitions with /etc/passwd are found)
  class UsersDatabase
    include Yast::Logger

    attr_accessor :atime

    @all = []

    # List of imported user databases, sorted by access time (the first element
    # is the most recently accessed).
    #
    # @return [Array<UsersDatabase>]
    class << self
      attr_reader :all

    protected

      # Adds a database to #all, honoring the expected order
      def push(database)
        @all << database
        @all.sort_by!(&:atime)
        @all.reverse!
      end
    end

    # Imports users data from a given root directory and stores it in .all
    #
    # @param root_dir [String] Path where the original "/" is mounted
    def self.import(root_dir)
      data = UsersDatabase.new
      data.read_files(root_dir)
      if data.users.empty?
        log.info "No users to import (#{root_dir})"
        return
      end

      push(data)
    end

    # Users that can be imported from this database
    #
    # @return [Array<Y2Users::User>]
    def users
      config&.users&.reject { |u| u.system? } || []
    end

    # Y2Users config object containing only the users that correspond to the given names
    # and nothing else
    #
    # @param names [Array<String>] names to filter by
    # @return [Y2Users::Config]
    def filtered_config(names)
      filtered = config.clone

      filtered.detach(*filtered.groups)
      skipped = filtered.users.reject { |u| names.include?(u.name) }
      filtered.detach(*skipped)

      filtered
    end

    # Populates the object with information read from a directory
    #
    # @param root_dir [String] Path where the original "/" is mounted
    def read_files(root_dir)
      dir = File.join(root_dir, "etc")
      passwd = File.join(dir, "passwd")
      shadow = File.join(dir, "shadow")
      return unless File.exist?(passwd) && File.exist?(shadow)

      @config = Y2Users::Config.new
      Y2Users::Linux::LocalReader.new(root_dir).read_to(config)

      self.atime = [File.atime(passwd), File.atime(shadow)].max
    end

  private

    attr_reader :config
  end
end
