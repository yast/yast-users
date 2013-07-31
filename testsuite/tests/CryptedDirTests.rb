# encoding: utf-8

# File		: CryptedDirTests.ycp
# Module	: Users configurator
# Summary	: Testing functions from UsersRoutines related to crypted dirs
# Author	: Jiri Suchomel <jsuchome@suse.cz>
#
# $Id$
module Yast
  class CryptedDirTestsClient < Client
    def main
      Yast.import "Directory"
      Yast.import "Mode"
      Yast.import "UsersRoutines"

      @READ = {
        "target" => {
          "stat"   => { "size" => 1 },
          "size"   => -1,
          "tmpdir" => "/tmp/YaST"
        },
        "anyxml" => {
          "pam_mount" => [
            {
              "volume" => [
                {
                  "user"      => "hh",
                  "path"      => "/home/hh.img",
                  "fskeypath" => "/home/hh.key"
                }
              ]
            }
          ]
        }
      }
      @WRITE = {}
      @EXEC = {}

      Yast.import "Testsuite"

      Mode.SetTest("test")

      Testsuite.Test(lambda { UsersRoutines.ReadCryptedHomesInfo }, [
        @READ,
        @WRITE,
        @EXEC
      ], 0)

      Testsuite.Test(lambda { UsersRoutines.CryptedKeyPath("hh") }, [], 0)
      Testsuite.Test(lambda { UsersRoutines.CryptedImagePath("hh") }, [], 0)
      # no such user -> empty string
      Testsuite.Test(lambda { UsersRoutines.CryptedKeyPath("hhh") }, [], 0)

      Testsuite.Test(lambda { UsersRoutines.CryptedImageOwner("/home/hh.img") }, [], 0)
      Testsuite.Test(lambda { UsersRoutines.CryptedKeyOwner("/home/hh.key") }, [], 0)
      # no such key file -> empty string
      Testsuite.Test(lambda { UsersRoutines.CryptedKeyOwner("/home/hh.img") }, [], 0)

      @RSIZE = { "target" => { "stat" => {} } }
      Testsuite.Test(lambda { UsersRoutines.FileSizeInMB("/home/hh.img") }, [
        @RSIZE,
        {},
        {}
      ], 0)
      Ops.set(@RSIZE, ["target", "stat", "size"], 1024)
      Testsuite.Test(lambda { UsersRoutines.FileSizeInMB("/home/hh.img") }, [
        @RSIZE,
        {},
        {}
      ], 0)
      Ops.set(@RSIZE, ["target", "stat", "size"], 1024 * 1024)
      Testsuite.Test(lambda { UsersRoutines.FileSizeInMB("/home/hh.img") }, [
        @RSIZE,
        {},
        {}
      ], 0)
      Ops.set(@RSIZE, ["target", "stat", "size"], 1024 * 1024 * 42)
      Testsuite.Test(lambda { UsersRoutines.FileSizeInMB("/home/hh.img") }, [
        @RSIZE,
        {},
        {}
      ], 0)

      nil
    end
  end
end

Yast::CryptedDirTestsClient.new.main
