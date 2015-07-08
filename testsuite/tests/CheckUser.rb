module Yast
  class CheckUserClient < Client
    def main
      # testedfiles: Users.pm
      Yast.import "Testsuite"
      Yast.import "Users"
      Yast.import "UsersSimple"
      Yast.import "Mode"

      # When Mode.test, some code does not get executed.
      # In this case, we need UsersCache.UsernameExists to
      # behave in a normal way.
      old_test_mode = Mode.testMode
      Mode.SetTest("none")

      @READ = { "uid" => { "username" => 1 } }
      @WRITE = {}
      @EXEC = { "target" => { "bash_output" => { "stdout" => "checkuser" } } }

      user = { "uid" => "checkuser", "uidNumber" => 2000,
               "what" => "add_user", "userPassword" => "n0ts3cr3t",
               "type" => "local"}

      # Test correct user
      test_user("Correct user", user)

      # Test user without uid
      test_user("Without uid", user.merge("uid" => ""))

      # Test user without uidNumber
      test_user("With not valid uidNumber", user.merge("uidNumber" => 70000))

      # Test user without password
      test_user("Without password", user.merge("userPassword" => ""))

      # Test user without password (but with an encrypted password)
      test_user("Without password (but with an encrypted one)",
                user.merge("userPassword" => "", "encrypted" => "$$$"))

      # Test user with duplicated uid
      test_user("With duplicated uid", user,
                read: @READ.merge("uid" => { "username" => 0 }))

      # Restore test mode
      Mode.SetTest(old_test_mode)
    end

    def test_user(title, user, read: nil, write: nil, execute: nil)
      read ||= @READ
      write ||= @WRITE
      execute ||= @EXEC
      Testsuite.Dump(Builtins.sformat("------- %1", title))
      err = Convert.to_string(
        Testsuite.Test(-> { Users.CheckUser(user) }, [read, write, execute], 0)
      )
      Testsuite.Dump(Builtins.sformat("------- error: %1", err)) unless err.empty?
    end
  end
end

Yast::CheckUserClient.new.main
