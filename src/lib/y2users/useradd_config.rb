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

module Y2Users
  # Class to represent the configuration of useradd
  #
  # Most attributes correspond to the so-called default values managed by "useradd -D" and
  # traditionally stored at /etc/default/useradd, but there can be exceptions. For example, the
  # attribute "umask" is handled by this class because it was originally a regular useradd
  # default value. If in doubt, check the documentation of each attribute.
  #
  # Attributes can be nil to indicate the value is unknown or irrelevant. That can happen if the
  # UseraddConfig object is constructed from an AutoYaST profile.
  #
  # When creating users in the target system, the configuration is written into that system in
  # advance to make it available for useradd. Note that only the attributes listed at
  # {.writable_attributes} will be actually persisted to the target system at that point. That is,
  # those are the only default values that can really be changed in the corresponding UseraddConfig
  # object to affect how the users are created and, thus, are the only ones with defined setters.
  #
  # As a software design decision, attributes that correspond to a key at /etc/default/useradd are
  # writable only if they can be changed via "adduser -D". For example, "skel" is not writable
  # because the support to adjust its value via "adduser -D" was removed at some point during the
  # useradd lifecycle (it was possible to adjust it in version 3.x but not in 4.x).
  #
  # Many of the attributes in this class have their counterpart in the <user_defaults> section of
  # the AutoYaST profile. But note there is not a 1:1 relationship because some of the attributes
  # from the profile simply don't have an equivalent setter in this class, so (Auto)YaST cannot
  # change the default value to affect the useradd behavior (eg. "skel").
  #
  # Moreover, there are two attributes from that AutoYaST section that don't even have a counterpart
  # in the useradd configuration: "groups" and "no_groups". The corresponding key GROUPS was dropped
  # from the useradd configuration with no substitute. Even if the GROUPS key is present in
  # /etc/default/useradd, its value will be completely ignored by useradd and by YaST.
  #
  # The "groups", "no_groups" and "skel" attributes from the profile may still be honored by
  # AutoYaST when creating users by any other mechanism other than UseraddConfig.
  class UseraddConfig
    class << self
      # Names of the attributes that can be persisted to the configuration of the system and thus
      # can be used to really modify the default useradd behavior
      #
      # Only attributes in this list have a public setter
      #
      # @return [Array<Symbol>]
      def writable_attributes
        @writable_attributes.dup
      end

    private

      # Internal class method to define the setter for a writable attribute
      # @param [String] name of the attribute
      # @!macro [attach] attr_setter
      #   @!attribute [w] $1
      def attr_setter(name)
        @writable_attributes ||= []
        @writable_attributes << name.to_sym

        attr_writer name
      end
    end

    # Constructor
    #
    # @param attrs [Hash{Symbol => Object}] values of the attributes, including non-writtable ones
    #   (which makes possible for some readers to set the initial value of all attributes)
    def initialize(attrs = {})
      @group = attrs[:group]
      @home = attrs[:home]
      @umask = attrs[:umask]
      @expiration = attrs[:expiration]
      @inactivity_period = attrs[:inactivity_period]
      @skel = attrs[:skel]
      @usrskel = attrs[:usrskel]
      @shell = attrs[:shell]
      @create_mail_spool = attrs[:create_mail_spool]
    end

    # Group name or numeric id of the initial group for a new user, if no group is specified
    #
    # @note This is only relevant if the USERGROUPS_ENAB variable in set to "no" in login.defs.
    #
    # This attribute corresponds to the GROUP key handled by "useradd -D"
    #
    # @return [String, nil]
    attr_reader :group
    attr_setter :group

    # This value is used as prefix to calculate the home directory for a new user, if no home
    # directory has been specified
    #
    # This string is concatenated with the account name to define the home directory.
    #
    # This attribute corresponds to the HOME key handled by "useradd -D"
    #
    # @return [String, nil]
    attr_reader :home
    attr_setter :home

    # The file mode mask used to create new home directories, if HOME_MODE is not specified in
    # login.defs
    #
    # @note This is only relevant for the creation of the user if HOME_MODE is not set. Otherwise,
    # the mode specified there will be used and this mask will be ignored by useradd and YaST.
    #
    # If both this and HOME_MODE are set to nil, useradd will use a fallback mask (tipically 022).
    #
    # This attribute corresponds to the UMASK variable in login.defs (see Yast::ShadowConfig).
    # In the past this was read from the UMASK key handled by "useradd -D", but such value has been
    # ignored by useradd for years, although YaST kept using it (instead of the value at login.defs)
    # for some additional time.
    #
    # @return [String, nil]
    attr_reader :umask
    attr_setter :umask

    # Password expiration date to use when creating a user, if none was set
    #
    # Represented as a string with the format "YYYY-MM-DD". An empty string means user passwords
    # will be created without expiration date.
    #
    # This attribute corresponds to the EXPIRATION key handled by "useradd -D"
    #
    # @return [String, nil]
    attr_reader :expiration
    attr_setter :expiration

    # Inactivity period to set when creating a user, if none was set
    #
    # A value of -1 means no inactivity period will be set.
    #
    # This attribute corresponds to the INACTIVE key handled by "useradd -D"
    #
    # @return [Integer, nil]
    attr_reader :inactivity_period
    attr_setter :inactivity_period

    # Login shell to set for a newly created user, if none was specified
    #
    # This attribute corresponds to the SHELL key handled by "useradd -D"
    #
    # @return [String, nil]
    attr_reader :shell
    attr_setter :shell

    # Skeleton directory from which the files will be copied when creating a home directory for
    # a new user
    #
    # This attribute corresponds to the SKEL key read (but not written) by "useradd -D"
    #
    # @see #usrskel
    #
    # @return [String, nil]
    attr_reader :skel

    # Extra directory from which some files are copied by useradd in an undocumented way
    # when creating a home directory for a new user
    #
    # This attribute corresponds to the undocumented USRSKEL key read by "useradd -D".
    #
    # @see #skel
    #
    # @return [String, nil]
    attr_reader :usrskel

    # Whether a mail spool should be created for every new user
    #
    # This attribute corresponds to the CREATE_MAIL_SPOOL key read by "useradd -D"
    #
    # @return [Boolean, nil]
    attr_reader :create_mail_spool
  end
end
