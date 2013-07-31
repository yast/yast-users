# encoding: utf-8

# File:
#  shells.ycp
#
# Module:
#  Users
#
# Summary:
#  Available shells listing test.
#
# Authors:
#  Petr Blahos <pblahos@suse.cz>
#
# $Id$
#
module Yast
  class ReadShellsClient < Client
    def main
      Yast.import "Testsuite"

      Yast.import "Users"

      @READ = {
        "target" => {
          "string" => "/bin/ash\n" +
            "/bin/bash\n" +
            "/bin/bash1\n" +
            "/bin/csh\n" +
            "/bin/false\n" +
            "/bin/ksh\n" +
            "/bin/sh",
          "stat"   => { 1 => 1 },
          # means 'file exists'
          "tmpdir" => "/tmp/YaST"
        }
      }

      Testsuite.Test(lambda { Users.ReadAllShells }, [@READ, {}, {}], 0)
      Testsuite.Dump(
        "=========================================================="
      )
      Testsuite.Dump(Builtins.sformat("shells: %1", Users.AllShells))

      nil
    end
  end
end

Yast::ReadShellsClient.new.main
