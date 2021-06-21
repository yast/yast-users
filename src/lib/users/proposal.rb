# Copyright (c) [2016-2021] SUSE LLC
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
require "y2users"
require "users/users_database"
require "installation/proposal_client"

module Users
  # Default proposal for the users YaST module
  class Proposal < ::Installation::ProposalClient
    include Yast::I18n
    include Yast::Logger

    def initialize
      Yast.import "Wizard"
      Yast.import "Mode"
      textdomain "users"
    end

    def make_proposal(_attrs)
      if Mode.auto
        {
          "preformatted_proposal" => HTML.List([users_ay]),
          "language_changed"      => false,
          "links"                 => []
        }
      else
        {
          "preformatted_proposal" => HTML.List([users_proposal, root_proposal]),
          "language_changed"      => false,
          "links"                 => [USERS_EVENT_ID, ROOT_EVEN_ID]
        }
      end
    end

    def ask_user(param)
      args = {
        "enable_back" => true,
        "enable_next" => param.fetch("has_next", false),
        "going_back"  => true
      }

      Wizard.OpenAcceptDialog

      case param["chosen_id"]
      when ROOT_EVEN_ID
        client = "inst_root_first"
        args["force"] = true
      when USERS_EVENT_ID
        client = "inst_user_first"
      else
        raise "Unknown action id: #{param["chosen_id"]}"
      end

      result = WFM.CallFunction(client, [args])

      Wizard.CloseDialog

      log.info "Returning from users proposal ask_user with #{result}"
      { "workflow_sequence" => result }
    end

    def description
      id = ""
      menu = []

      if !Mode.auto
        id = USERS_EVENT_ID
        menu = [
          # menu button label
          { "id" => "users--user", "title" => _("&User") },
          # menu button label
          { "id" => "users--root", "title" => _("&Root Password") }
        ]
      end

      {
        "id"              => id,
        # rich text label
        "rich_text_title" => _("User Settings"),
        "menu_titles"     => menu
      }
    end

  private

    USERS_EVENT_ID = "users--user".freeze
    ROOT_EVENT_ID = "users--root".freeze

    private_constant :USERS_EVENT_ID, :ROOT_EVENT_ID

    # The config holding users and groups to create
    #
    # @return [Y2Users::Config]
    def config
      @config ||= Y2Users::ConfigManager.instance.target&.copy || Y2Users::Config.new
    end

    # All users to be created
    #
    # @return [Array<Y2Users::User>]
    def users
      return @users if @users

      @users = config.users
      @users = @users.reject(&:root?) unless Mode.auto
    end

    # The first user to be created
    #
    # @return [Y2Users::User]
    def user
      @user = users.first
    end

    # The root user
    #
    # @return [Y2Users::User]
    def root_user
      @root_user ||= config.users.root || Y2Users::User.create_root
    end

    # Whether {#users} is the result of importing a user from another system
    #
    # @return [Boolean] true if config holds more than one user or it was imported; false otherwise
    def imported_users?
      users.size > 1 || importable_users.include?(user)
    end

    # Users from a different system that can be imported into the new installation
    #
    # @return [Array<Y2Users::User>]
    def importable_users
      UsersDatabase.all.first&.users || []
    end

    def users_ay
      ret = _("Number of defined users/groups:")
      ret += "<ul>\n<li>" + format(_("Users: %d"), config.users.size) + "</li>\n"
      ret += "<li>" + format(_("Groups: %d"), config.groups.size) + "</li></ul>"
      ret
    end

    # Returns the users summary used during normal installation
    #
    # @return [String]
    def users_proposal
      return no_user_summary unless user
      return imported_users_summary if imported_users?

      user_summary
    end

    # Returns the root user summary used during normal installation
    #
    # @return [String]
    def root_proposal
      password = root_user.password_content

      text = if password.to_s.empty?
        # TRANSLATORS: summary line: %{hs} and %{he} are the hyperlink start and end respectively.
        _("%{hs}Root Password%{he} not set")
      else
        # TRANSLATORS: summary line: %{hs} and %{he} are the hyperlink start and end respectively.
        _("%{hs}Root Password%{he} set")
      end

      format(text, hs: root_hyperlink, he: hyperlink_end)
    end

    # Returns the HTML hyperlink open tag for root event id
    #
    # @return [String]
    def root_hyperlink
      "<a href='#{ROOT_EVEN_ID}'>"
    end

    # Returns the HTML hyperlink open tag for user event id
    #
    # @return [String]
    def users_hyperlink
      "<a href='#{USERS_EVENT_ID}'>"
    end

    # Returns the HTML hyperlink close tag
    #
    # @return [String]
    def hyperlink_end
      "</a>"
    end

    # Text to display when there are no users configured
    #
    # @see #users_proposal
    # @return [String]
    def no_user_summary
      # TRANSLATORS: summary line: %{hs} and %{he} are the hyperlink start and end respectively.
      format(
        _("No %{hs}user%{he} configured"),
        hs: users_hyperlink,
        he: hyperlink_end
      )
    end

    # Text to display when users are being imported
    #
    # @see #users_proposal
    # @return [String]
    def imported_users_summary
      # TRANSLATORS: summary line,
      #   %{hs} and %{he} are the hyperlink start and end respectively.
      #   %{qty} will be replaced by the number of users
      format(
        n_(
          "%{hs}%{qty} user%{he} will be imported", "%{hs}%{qty} users%{he} will be imported",
          users.size
        ),
        hs:  users_hyperlink,
        he:  hyperlink_end,
        qty: users.size
      )
    end

    # Text for summarizing the user to be created
    #
    # @see #users_proposal
    # @return [String]
    def user_summary
      text = if user.name == user.full_name
        # TRANSLATORS: summary line,
        #   %{hs} and %{he} are the hyperlink start and end respectively.
        #   %{username} will be replaced by the user login name
        _("%{hs}User%{he} %{username} configured")
      else
        # TRANSLATORS: summary line,
        #   %{hs} and %{he} are the hyperlink start and end respectively.
        #   %{username} will be replaced by the user login name
        #   %{full_name} will be replaced by the user name
        _("%{hs}User%{he} %{full_name} (%{username}) configured")
      end

      format(
        text,
        hs:        users_hyperlink,
        he:        hyperlink_end,
        username:  user.name,
        full_name: user.full_name
      )
    end
  end
end
