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

module Users
  # Class that allows to memorize the user's database (/etc/passwd and
  # associated files) of any partition.
  #
  # Used to implement the users importing functionality.
  #
  # It provides class methods to hold a list of databases (in case many
  # partitions with /etc/passwd are found)
  class UsersDatabase
    attr_accessor :passwd
    attr_accessor :shadow
    attr_accessor :atime

    @all = []

    # List of imported user databases, sorted by access time (the first element
    # is the most recently accessed).
    #
    # @return [Array<UsersDatabase>]
    def self.all
      @all
    end

    # Imports users data from a given root directory and stores it in .all
    #
    # @param root_dir [String] Path where the original "/" is mounted
    def self.import(root_dir)
      data = UsersDatabase.new
      data.read_files(File.join(root_dir, "etc"))
      return if data.passwd.nil? || data.passwd.empty?

      push(data)
    end

    # Populates the object with information read from a directory
    #
    # @param dir [String] path to a directory containing passwd and shadow files
    def read_files(dir)
      passwd = File.join(dir, "passwd")
      shadow = File.join(dir, "shadow")
      return unless File.exist?(passwd) && File.exist?(shadow)

      self.passwd = IO.read(passwd)
      self.shadow = IO.read(shadow)
      self.atime = [File.atime(passwd), File.atime(shadow)].max
    end

    # Writes passwd and shadow files to a directory
    #
    # @param dir [String] path of the target directory
    def write_files(dir)
      passwd = File.join(dir, "passwd")
      shadow = File.join(dir, "shadow")
      IO.write(passwd, self.passwd)
      IO.write(shadow, self.shadow)
    end

  protected

    # Adds a database to #all, honoring the expected order
    def self.push(database)
      @all << database
      @all.sort_by!(&:atime)
      @all.reverse!
    end
  end
end
