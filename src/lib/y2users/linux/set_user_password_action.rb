# Copyright (c) [2021-2023] SUSE LLC
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

require "yast"
require "yast/i18n"
require "yast2/execute"
require "y2issues/issue"
require "y2users/linux/action"
require "y2users/linux/root_path"

module Y2Users
  module Linux
    # Action for setting the user password
    class SetUserPasswordAction < Action
      include Yast::I18n
      include Yast::Logger
      include RootPath

      root_path_option :root

      # Constructor
      #
      # @see Action
      def initialize(user, root_path: nil)
        textdomain "users"

        super(user)
        @root_path = root_path
      end

    private

      alias_method :user, :action_element

      # @see Action#run_action
      def run_action
        set_password_value && set_password_attributes
      end

      # Command for setting a user password
      #
      # This command is "preferred" over
      #   * the `passwd` command because the password at this point is already
      #   encrypted (see Y2Users::Password#value). Additionally, this command
      #   requires to enter the password twice, which it's not possible using
      #   the Cheetah stdin argument.
      #
      #   * the `--password` option of `useradd` because the encrypted
      #   password is visible as part of the process name
      CHPASSWD = "/usr/sbin/chpasswd".freeze
      private_constant :CHPASSWD

      # Command for configuring the attributes in /etc/shadow
      CHAGE = "/usr/bin/chage".freeze
      private_constant :CHAGE

      # Executes the command for setting the password
      #
      # Issues are generated when the password cannot be set.
      #
      # @return [Boolean] true on success
      def set_password_value
        options = chpasswd_options
        Yast::Execute.on_target!(CHPASSWD, *options) if options.any?
        true
      rescue Cheetah::ExecutionFailed => e
        issues << Y2Issues::Issue.new(
          # TRANSLATORS: %s is a placeholder for a username
          format(_("The password for '%s' could not be set"), user.name)
        )
        log.error("Error setting password for '#{user.name}' - #{e.message}")
        false
      end

      # Executes the command for setting the dates and limits in /etc/shadow
      #
      # Issues are generated when the password options cannot be set.
      #
      # @return [Boolean] true on success
      def set_password_attributes
        options = chage_options
        Yast::Execute.on_target!(CHAGE, *options, user.name) if options.any?
        true
      rescue Cheetah::ExecutionFailed => e
        issues << Y2Issues::Issue.new(
          # TRANSLATORS: %s is a placeholder for a username
          format(_("Error setting the properties of the password for '%s'"), user.name)
        )
        log.error("Error setting password attributes for '#{user.name}' - #{e.message}")
        false
      end

      # Generates options for `chpasswd`
      #
      # @return [Array<String, Hash>]
      def chpasswd_options
        return [] unless user.password&.value

        opts = root_path_options
        opts << "-e" if user.password&.value&.encrypted?
        opts << {
          stdin:    [user.name, user.password_content].join(":"),
          recorder: cheetah_recorder
        }
        opts
      end

      # Generates options for `chage`
      #
      # @return [Array<String>]
      def chage_options
        return [] unless user.password

        opts = {
          "--mindays"    => chage_value(user.password.minimum_age),
          "--maxdays"    => chage_value(user.password.maximum_age),
          "--warndays"   => chage_value(user.password.warning_period),
          "--inactive"   => chage_value(user.password.inactivity_period),
          "--expiredate" => chage_value(user.password.account_expiration),
          "--lastday"    => chage_value(user.password.aging)
        }

        opts.reject { |_, v| v.nil? }.flatten + root_path_options
      end

      # Returns the right value for a given `chage` option value
      #
      # @see #chage_options
      #
      # @param value [String, Integer, Date, nil]
      # @return [String]
      def chage_value(value)
        return if value.nil?

        result = value.to_s
        result.empty? ? "-1" : result
      end

      # Custom Cheetah recorder to prevent leaking the password to the logs
      #
      # @return [Recorder]
      def cheetah_recorder
        @cheetah_recorder ||= Recorder.new(Yast::Y2Logger.instance)
      end

      # Class to prevent Yast::Execute from leaking to the logs passwords provided via stdin
      class Recorder < Cheetah::DefaultRecorder
        # To prevent leaking stdin, just do nothing
        def record_stdin(_stdin); end
      end
    end
  end
end
