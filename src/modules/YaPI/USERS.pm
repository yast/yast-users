# ------------------------------------------------------------------------------
# Copyright (c) 2006-2012 Novell, Inc. All Rights Reserved.
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------
#

=head1 NAME

YaPI::USERS

=head1 PREFACE

This package is the public YaST2 API for Users/Groups management

=head1 SYNOPSIS

use YaPI::USERS

$error = UserAdd ($config_hash, $data_hash)

    Creates new user, described in $data_hash.
    Returns an error message if operation failed or empty string otherwise.

$error = UserModify ($config_hash, $data_hash)

    Modifies the data of given user.
    Returns an error message if operation failed or empty string otherwise.

$error = UserFeatureAdd ($config_hash)

    Adds a new feature (plugin) to the given user.
    Returns an error message if operation failed or empty string otherwise.

$error = UserFeatureDelete ($config_hash)

    Removes a feature (plugin) from the given user.
    Returns an error message if operation failed or empty string otherwise.

$error = UserDelete ($config_hash)

    Deletes an existing user.
    Returns an error message if operation failed or empty string otherwise.

$error = UserDisable ($config_hash)

    Disable user to log in.
    Returns an error message if operation failed or empty string otherwise.

$error = UserEnable ($config_hash)

    Enable disabled user to log in again.
    Returns an error message if operation failed or empty string otherwise.

$data_hash = UserGet ($config_hash)

    Returns data hash decribing user.

$users_hash = UsersGet ($config_hash)

    Returns hash of users. The resulting set is defined in $config hash.

$error = GroupAdd ($config_hash, $data_hash)

    Creates new group, described in $data_hash.
    Returns an error message if operation failed or empty string otherwise.

$error = GroupModify ($config_hash, $data_hash)

    Modifies the data of given group.
    Returns an error message if operation failed or empty string otherwise.

$error = GroupMemberAdd ($config_hash, $user_hash)

    Adds a new member (user) to the given group.
    Returns an error message if operation failed or empty string otherwise.

$error = GroupMemberDelete ($config_hash, $user_hash)

    Removes a member from the given group.
    Returns an error message if operation failed or empty string otherwise.

$error = GroupDelete ($config_hash)

    Deletes an existing group.
    Returns an error message if operation failed or empty string otherwise.

$data_hash = GroupGet ($config_hash)

    Returns data hash decribing group.

$groups_hash = GroupsGet ($config_hash)

    Returns hash of groups. The resulting set is defined in $config hash.

$groups_hash = GroupsGetByUser ($config_hash, $user_hash)

    Returns hash of groups given user is member of.
    The resulting set is defined in $config hash.


=head1 DESCRIPTION

=over 2

=cut

package YaPI::USERS;

use strict;
use YaST::YCP qw(:LOGGING);
use YaPI;
use Data::Dumper;

textdomain ("users");


# ------------------- imported modules
YaST::YCP::Import ("Ldap");
YaST::YCP::Import ("Users");
YaST::YCP::Import ("UsersCache");
YaST::YCP::Import ("UsersPasswd");
YaST::YCP::Import ("UsersLDAP");
YaST::YCP::Import ("UsersSimple");
# -------------------------------------

our $VERSION		= '1.0.0';
our @CAPABILITIES 	= ('SLES9');
our %TYPEINFO;


# -------------------------------------
sub InitializeLdapConfiguration {

    my $config = $_[0];

    if (defined $config->{"bind_dn"}) {
	Ldap->bind_dn ($config->{"bind_dn"});
    }

    if (defined $config->{"bind_pw"}) {
	Ldap->SetBindPassword ($config->{"bind_pw"});
    }
    else {
	Ldap->SetBindPassword (undef);
    }

    if (defined $config->{"anonymous_bind"}) {
	Ldap->SetAnonymous ($config->{"anonymous_bind"});
    }
    else {
	Ldap->SetAnonymous (0);
    }

    # this could replace the settings read from Ldap::member_attribute
    if (defined $config->{"member_attribute"}) {
	Ldap->member_attribute ($config->{"member_attribute"});
    }
}

# -------------------------------------
sub InitializeUsersLdapConfiguration {

    my $config = shift;

    if (defined $config->{"user_attributes"} &&
	ref ($config->{"user_attributes"}) eq "ARRAY") {
	UsersLDAP->SetUserAttributes ($config->{"user_attributes"});
    }
    else {
	UsersLDAP->SetUserAttributes ([]);
    }

    if (defined $config->{"user_filter"}) {
	UsersLDAP->SetCurrentUserFilter ($config->{"user_filter"});
    }
    else {
	UsersLDAP->SetCurrentUserFilter (UsersLDAP->GetDefaultUserFilter ());
    }

    # this could replace the settings saved in LDAP config ("suseDefaultBase")
    if (defined $config->{"user_base"}) {
	UsersLDAP->SetUserBase ($config->{"user_base"});
    }

    if (defined $config->{"user_scope"}) {
	UsersLDAP->SetUserScope ($config->{"user_scope"});
    }
    else {
	UsersLDAP->SetUserScope (2);
    }
    
    if (defined $config->{"group_attributes"} &&
	ref ($config->{"group_attributes"}) eq "ARRAY") {
	UsersLDAP->SetGroupAttributes ($config->{"group_attributes"});
    }
    else {
	UsersLDAP->SetGroupAttributes ([]);
    }

    if (defined $config->{"group_base"}) {
	UsersLDAP->SetGroupBase ($config->{"group_base"});
    }

    if (defined $config->{"group_filter"}) {
	UsersLDAP->SetCurrentGroupFilter ($config->{"group_filter"});
    }
    else {
	UsersLDAP->SetCurrentGroupFilter (UsersLDAP->GetDefaultGroupFilter ());
    }

	
    if (defined $config->{"group_scope"}) {
	UsersLDAP->SetGroupScope ($config->{"group_scope"});
    }
    else {
	UsersLDAP->SetGroupScope (2);
    }

    if (defined $config->{"plugins"} && ref ($config->{"plugins"}) eq "ARRAY") {
	UsersLDAP->SetUserPlugins ($config->{"plugins"});
    }
    else {
	UsersLDAP->SetUserPlugins (["UsersPluginLDAPAll"]);
    }

    if (defined $config->{"user_plugins"} &&
	ref ($config->{"user_plugins"}) eq "ARRAY") {
	UsersLDAP->SetUserPlugins ($config->{"user_plugins"});
    }
    elsif (!defined $config->{"plugins"}) {
	UsersLDAP->SetUserPlugins (["UsersPluginLDAPAll"]);
    }

    if (defined $config->{"group_plugins"} &&
	ref ($config->{"group_plugins"}) eq "ARRAY") {
	UsersLDAP->SetGroupPlugins ($config->{"group_plugins"});
    }
    else {
	UsersLDAP->SetGroupPlugins (["UsersPluginLDAPAll"]);
    }
}

# helper function
# create the minimal set of user attributes we want to read from LDAP
sub SetNecessaryUserAttributes {

    my $more		= shift;
    my @necessary	=
	("uid", "uidNumber", "objectClass", UsersLDAP->GetUserNamingAttr ());
    my $current		= UsersLDAP->GetUserAttributes ();
    my %attributes	= ();
    foreach my $a (@$current) {
	$attributes{$a}	= 1;
    }
    foreach my $a (@necessary) {
	$attributes{$a}	= 1;
    }
    foreach my $a (@$more) {
	$attributes{$a} = 1;
    }
    my @final		= sort keys %attributes;
    UsersLDAP->SetUserAttributes (\@final);
}

# helper function
# create the minimal set of group attributes we want to read from LDAP
sub SetNecessaryGroupAttributes {

    my $more		= shift;
    my @necessary	=
	("cn", "gidNumber", "objectClass", UsersLDAP->GetGroupNamingAttr ());
    my $current		= UsersLDAP->GetGroupAttributes ();
    my %attributes	= ();
    foreach my $a (@$current) {
	$attributes{$a}	= 1;
    }
    foreach my $a (@necessary) {
	$attributes{$a}	= 1;
    }
    foreach my $a (@$more) {
	$attributes{$a} = 1;
    }
    my @final		= sort keys %attributes;
    UsersLDAP->SetGroupAttributes (\@final);
}

=item *
C<$error = UserAdd ($config_hash, $data_hash)>

Creates new user. User attributes are described in $data_hash,
$config_hash describes special configuration data.

Returns an error message if operation failed or empty string otherwise.


PARAMETERS:

    Possible parameters for $config hash:

    "type"	Type of user (string). Possible values:
		"local","system","ldap","nis". ("nis" is not available
		for adding)


    Specific parameters of $config hash, related to LDAP users (all keys
    are optional, there should exist reasonable default values based on
    current LDAP configuration):

    "bind_dn"	
		DN of LDAP administrator, used to bind to LDAP server
		(string)
		
    "bind_pw"	
		Password for LDAP administrator (string)
		
    "anonymous_bind"
    
		If this key is present, there will be done created an
		anonymous connection to LDAP server (if it is allowed).
		
    "member_attribute"
		Name of LDAP attribute, defining the membership in LDAP
		groups (possible values: "member", "uniquemember"). The
		default value is in /etc/ldap.conf (nss_map_attribute).

    "user_attributes"
		List of attributes to be returned by an LDAP search for
		user (list of strings). If empty, all non-empty
		attributes will be returned as a result of search.

    "user_filter"
		Filter for restricting LDAP searches (string).
		The default value is stored as "suseSearchFilter" in 
		LDAP configuration.

    "user_base"
		DN of LDAP base where the users are stored (string). By
		default, the value of "suseDefaultBase" stored in LDAP
		configuration is used.

    "user_scope"
		The scope used for LDAP searches for users. Possible
		values are 0 (base), 1(one), 2(sub). Default is 2.
    
    "plugins"
		List of plugins which should be applied for user
		(list of strings). General plugin for LDAP users,
		("UsersPluginLDAPAll") is always available, others are
		part of modules which has to be installed before their
		usage (yast2-samba-server, yast2-mail-server).

    "user_plugins"
		Same as "plugins".

    Values mentioned above are common for all $config hashes in the
    functions for handling user. Additionally, there is a special value
    which is defined only for UserAdd:

    "create_home"
		If this is set to 0, the home directory for new user
		won't be created.
		


    Possible parameters for $data hash:

    "uid"		Login name
    "cn"		Full name
    "userPassword"	User's password
    "homeDirectory"	Users's home directory
    "loginShell"	User's login shell
    "gidNumber"		GID of user's default group
    "groupname"		name of user's default group; YaST itself will look for GID
    "grouplist" 	Hash (of type { <group_name> => 1 }) with groups
			this user should be member of.
    "shadowinactive"	Days after password expires that account is disabled
    "shadowexpire"	Days since Jan 1, 1970 that account is disabled
    "shadowwarning"     Days before password is to expire that user is warned
    "shadowmin"         Days before password may be changed
    "shadowmax"         Days after which password must be changed
    "shadowflag"        (last value at line in /etc/shadow)
    "shadowlastchange"  Days since Jan 1, 1970 that password was last changed

    <ldap_attribute>	For LDAP users, any attribute supported by
			users's object class can be here.


EXAMPLE:

  my $config	= { "type"		=> "ldap",
		    "plugins"		=> [ "UsersPluginLDAPAll" ],
		    "bind_dn"		=> "uid=admin,dc=example,dc=com",
  };
  my $data	= { "uid"		=> "ll",
		    "uidNumber"		=> 1111,
		    "userPassword"	=> "qqqqq"
		    "givenName"		=> "l",
		    "cn"		=> [ "ll" ]
		    "description"	=> [ "first", "second" ],
  };
  # create new LDAP user
  my $error	= UserAdd ($config, $data);

  # create new local user 'hh'; use all available defaults
  UserAdd ({}, { "uid"	=> "hh" });

NOTE

  You can see on example that LDAP attributes could be passed either
  as list of value or as strings, which is just the same case as a list
  with one value.
 

=cut

BEGIN{$TYPEINFO{UserAdd} = ["function",
    "string",
    [ "map", "string", "any" ],
    [ "map", "string", "any" ]];
}
sub UserAdd {

    my $self	= shift;
    my $config	= $_[0];
    my $data	= $_[1];
    my $user	= {};
    my $ret	= "";

    # this translation table should not be neccessary...
    my $new_keys	= {
	"username"	=> "uid",
	"password"	=> "userPassword",
	"home"		=> "homeDirectory",
	"shell"		=> "loginShell",
	"fullname"	=> "cn",
	"gid"		=> "gidNumber",
	"groups"	=> "grouplist"
    };
    if (defined $config->{"create_home"} && !defined $data->{"create_home"}) {
	$data->{"create_home"}	= $config->{"create_home"};
    }
    foreach my $key (keys %{$data}) {
	my $new_key	= $key;
	if (defined $new_keys->{$key}) {
 	    $key	= $new_keys->{$key};
	}
	my $value	= $data->{$key};
	if ($key eq "create_home" && ref $data->{$key} ne "YaST::YCP::Boolean"){
	    $value	= YaST::YCP::Boolean ($data->{$key});
	}
	$user->{$new_key}	= $value;
    }

    Users->SetGUI (0);

    $ret = Users->Read ();
    if ($ret ne "") { return $ret; }

    my $type	= $config->{"type"} || "local";
    if ($type eq "ldap") {

	# first, read settings from Ldap.ycp (e.g. /etc/ldap.conf)
	UsersLDAP->ReadLdap ();

	# before we read LDAP, we could find here bind password, bind DN etc.
	InitializeLdapConfiguration ($config);

	# this initializes the connection and reads the settings stored in LDAP
	$ret	= UsersLDAP->ReadSettings ();
	if ($ret ne "") { return $ret; }

	# now rewrite default values (read from LDAP) with given values
	InitializeUsersLdapConfiguration ($config);

	SetNecessaryUserAttributes (["homeDirectory"]);
	# read only users ID's (because we need to create new one -> TODO
	# update UsersCache->NextFreeUID)
	if (defined $config->{"fast_ldap"}) {
	    UsersLDAP->SetUserAttributes (["uidNumber"]);
	}
	# finally read LDAP tree
	$ret	= Users->ReadLDAPSet ();
	if ($ret ne "") { return $ret; }
    }
    $user->{"type"}	= $type;

    Users->ResetCurrentUser ();

    # if groupname was specified and not gidNumber, find the GID
    if (($user->{"groupname"} || "") && ! defined $user->{"gidNumber"}) {

	my $group = Users->GetGroupByName ($user->{"groupname"} || "", "");
	$user->{"gidNumber"} = $group->{"gidNumber"} if (defined $group->{"gidNumber"});
    }
    
    $ret = Users->AddUser ($user);
    if ($ret ne "") { return $ret; }

    if ($type eq "ldap") {
	Users->SubstituteUserValues ();
    }
	
    $ret = Users->CheckUser ({});
    if ($ret ne "") {
	return $ret;
    }
    # EXPERIMENTAL MODE: do not read LDAP users before adding, but check
    # possible conflicts with multiple search calls
    if ($type eq "ldap" && defined $config->{"fast_ldap"}) {
	# do the searches for uid and homeDirectory
	$user	= Users->GetCurrentUser ();
	my $res = SCR->Read (".ldap.search", {
	    "base_dn"	=> UsersLDAP->GetUserBase (),
	    "scope"	=> YaST::YCP::Integer (2),
	    "filter"	=> "uid=".$user->{"uid"},
	    "attrs"	=> [ "uid" ]
	});
	if (defined $res && ref ($res) eq "ARRAY" && @{$res} > 0) {
	    # error message
	    return __("There is a conflict between the entered
user name and an existing user name.
Try another one.");
	}
	$res = SCR->Read (".ldap.search", {
	    "base_dn"	=> UsersLDAP->GetUserBase (),
	    "scope"	=> YaST::YCP::Integer (2),
	    "filter"	=> "homeDirectory=".$user->{"homeDirectory"},
	    "attrs"	=> [ "homeDirectory" ]
	});
	if (defined $res && ref ($res) eq "ARRAY" && @{$res} > 0) {
	    # error message
	    return __("The home directory is used from another user.
Please try again.");
	}
    }
    if (Users->CommitUser ()) {
	$ret = Users->Write ();
    }
    return $ret;
}

=item *
C<$error = UserModify ($config_hash, $data_hash)>

Modifies existing user. User attributes which should be changed
are described in $data_hash,
$config_hash describes special configuration data, especially user
identification.

Returns an error message if operation failed or empty string otherwise.

PARAMETERS:

    Special values for $config hash: additinally to the values always
    available (see L<UserAdd>), $config must contains one of the key
    used to identify the user which should be modified:

    "dn"	Distinguished name (DN) - only for LDAP user
    "uid"	User name (which is value of "uid" for LDAP user)
    "uidNumber"	UID number ("uidNumber" value for LDAP user)

    For values in $data hash, see L<UserAdd>.


EXAMPLE:

  my $config	= { "type"		=> "ldap",
		    "uidNumber"		=> 500
  };
  my $data	= { "userPassword"	=> "wwwww"
  };
  # changes a password of LDAP user (identified with id)
  my $error	= UserModify ($config, $data);

  # change GID value of local user (identified with name)
  $error	= UserModify ({ "uid" => "hh" }, { "gidNumber" => 5555 });

=cut

BEGIN{$TYPEINFO{UserModify} = ["function",
    "string",
    [ "map", "string", "any" ],
    [ "map", "string", "any" ]];
}
sub UserModify {

    my $self	= shift;
    my $config	= $_[0];
    my $data	= $_[1];
    my $error	= "";

    Users->SetGUI (0);

    my $type	= $config->{"type"} || "local";

    Users->SetReadLocal ($type ne "ldap");

    $error = Users->Read ();
    if ($error ne "") { return $error; }

    # 1. select user

    my $key	= "";
    if (defined $config->{"dn"} && $type eq "ldap") {
	$key	= "dn";
    }
    elsif (defined $config->{"uid"}) {
	$key	= "uid";
    }
    elsif (defined $config->{"uidNumber"}) {
	$key	= "uidNumber";
    }

    if ($type eq "ldap") {

	# initialize LDAP (more comments in UserAdd)
	UsersLDAP->ReadLdap ();
	InitializeLdapConfiguration ($config);
	$error	= UsersLDAP->ReadSettings ();
	if ($error ne "") { return $error; }
	InitializeUsersLdapConfiguration ($config);

	# If we want to change atributes, that should be unique
	# (uid/dn/uidNumber/home we must read everything to check
	# possible conflicts...
	my $read_all	= 0;
	if (defined $data->{"uid"} || defined $data->{"uidNumber"}) {
	    $read_all	= 1;
	}

	# search with proper filter (= one DN/uid/uidNumber)
	# should be sufficient in this case...
	if ($key eq "dn" && !$read_all) {
	    UsersLDAP->SetUserBase ($config->{$key});
	}
	elsif (!defined $config->{"user_filter"} && $key ne "" && !$read_all) {
	    my $filter	= "$key=".$config->{$key};
	    UsersLDAP->AddToCurrentUserFilter ($filter);
	}
	# Let's create the minimal list of neccessary attributes to get
	if (defined $data->{"homeDirectory"}) {
	    # we must check possible directory conflicts...
	    SetNecessaryUserAttributes (["homeDirectory"]);
	}
	else {
	    SetNecessaryUserAttributes ([]);
	}
	
	$error	= Users->ReadLDAPSet ();
	if ($error ne "") { return $error; }
    }
    elsif ($type eq "nis") {
	Users->ReadNewSet ($type);
    }
    if ($key eq "uidNumber") {
	Users->SelectUser ($config->{$key}, $type);
    }
    elsif ($key ne "") {
	Users->SelectUserByName ($config->{$key}, $type);
    }

    # 'dn' has to be passed in $data map so it could be changed
    # FIXME it is currently not possible to move entry deeper in the tree
    # -> allow setting 'dn' in data map!
    if ($type eq "ldap" && !defined $data->{"dn"}) {
	my $user	= Users->GetCurrentUser ();
	$data->{"dn"}	= $user->{"dn"};
    }

    # if groupname was specified and not gidNumber, find the GID
    if (($data->{"groupname"} || "") && ! defined $data->{"gidNumber"}) {
	my $group = Users->GetGroupByName ($data->{"groupname"} || "", "");
	$data->{"gidNumber"} = $group->{"gidNumber"} if (defined $group->{"gidNumber"});
    }

    $error = Users->EditUser ($data);
    if ($error eq "") {
	$error = Users->CheckUser ({});
	if ($error eq "" && Users->CommitUser ()) {
	    $error = Users->Write ();
	}
    }

    return $error;
}

=item *
C<$error UserFeatureAdd ($config_hash);>

Adds a new feature (plugin) to the given user.

Returns an error message if operation failed or empty string otherwise.

PARAMETERS:

    $config hash can contain data always available (see L<UserAdd>)
    and the data used for user identification (see L<UserModify>).
    Additionally, it has to contain the value for

    "plugins"		List of plugins which should be added to the user.


EXAMPLE:

  my $config	= { "type"		=> "ldap",
		    "plugins"		=> [ "UsersPluginSambaAccount" ],
		    "bind_dn"		=> "uid=admin,dc=example,dc=com",
		    "uid"		=> "ll"
  };
  # adds 'SambaAccount' plugin to the user
  my $error	= UserFeatureAdd ($config);

=cut

BEGIN{$TYPEINFO{UserFeatureAdd} = ["function",
    "string",
    [ "map", "string", "any" ]];
}
sub UserFeatureAdd {

    my $self	= shift;
    my $config	= shift;
    my $error	= "";

    if (!defined $config->{"plugins"} || ref ($config->{"plugins"}) ne "ARRAY"
	|| @{$config->{"plugins"}} < 1) {
	# error message
	return __("No plug-in was defined");
    }

    # Most is just copied from UserModify
    Users->SetGUI (0);

    my $type	= $config->{"type"} || "local";

    Users->SetReadLocal ($type ne "ldap");
    $error = Users->Read ();
    if ($error ne "") { return $error; }

    # 1. select user

    my $key	= "";
    if (defined $config->{"dn"} && $type eq "ldap") {
	$key	= "dn";
    }
    elsif (defined $config->{"uid"}) {
	$key	= "uid";
    }
    elsif (defined $config->{"uidNumber"}) {
	$key	= "uidNumber";
    }

    if ($type eq "ldap") {

	# initialize LDAP (more comments in UserAdd)
	UsersLDAP->ReadLdap ();
	InitializeLdapConfiguration ($config);
	$error	= UsersLDAP->ReadSettings ();
	if ($error ne "") { return $error; }
	InitializeUsersLdapConfiguration ($config);

	# search with proper filter (= one DN/uid/uidNumber)
	# should be sufficient in this case...
	if ($key eq "dn") {
	    UsersLDAP->SetUserBase ($config->{$key});
	}
	elsif (!defined $config->{"user_filter"} && $key ne "") {
	    my $filter	= "$key=".$config->{$key};
	    UsersLDAP->AddToCurrentUserFilter ($filter);
	}
	# TODO it is possible that for the plugin we need some (unknown)
	# user attributes...
	if (!defined $config->{"user_attributes"}) {
	    UsersLDAP->SetUserAttributes ([]);
	}
	
	$error	= Users->ReadLDAPSet ();
	if ($error ne "") { return $error; }
    }
    elsif ($type eq "nis") {
	# error message
	return __("It is not possible to edit a NIS user.");
    }

    if ($key eq "uidNumber") {
	Users->SelectUser ($config->{$key}, $type);
    }
    elsif ($key ne "") {
	Users->SelectUserByName ($config->{$key}, $type);
    }

    foreach my $plugin (@{$config->{"plugins"}}) {
	$error = Users->AddUserPlugin ($plugin);
    }

    if ($error eq "") {
	$error = Users->CheckUser ({});
	if ($error eq "" && Users->CommitUser ()) {
	    $error = Users->Write ();
	}
    }
    return $error;
}

=item *
C<$error UserFeatureDelete ($config_hash);>

Deletes a new feature (plugin) to the given user.

Returns an error message if operation failed or empty string otherwise.


PARAMETERS:

    See L<UserFeatureAdd>.
    "plugins" 	contains the list of plugins to be removed.

EXAMPLE:

  my $config	= { "type"		=> "ldap",
		    "plugins"		=> [
			"UsersPluginSambaAccount",
			"UsersPluginMail"
		    ],
		    "uid"		=> "ll"
  };
  # removes 'SambaAccount' and 'Mail' plugin from the user 
  my $error	= UserFeatureDelete ($config);

=cut

BEGIN{$TYPEINFO{UserFeatureDelete} = ["function",
    "string",
    [ "map", "string", "any" ]];
}
sub UserFeatureDelete {

    my $self	= shift;
    my $config	= shift;
    my $error	= "";

    if (!defined $config->{"plugins"} || ref ($config->{"plugins"}) ne "ARRAY"
	|| @{$config->{"plugins"}} < 1) {
	# error message
	return __("No plug-in was defined");
    }

    # Most is just copied from UserModify
    Users->SetGUI (0);

    my $type	= $config->{"type"} || "local";

    Users->SetReadLocal ($type ne "ldap");
    $error = Users->Read ();
    if ($error ne "") { return $error; }

    # 1. select user

    my $key	= "";
    if (defined $config->{"dn"} && $type eq "ldap") {
	$key	= "dn";
    }
    elsif (defined $config->{"uid"}) {
	$key	= "uid";
    }
    elsif (defined $config->{"uidNumber"}) {
	$key	= "uidNumber";
    }

    if ($type eq "ldap") {

	# initialize LDAP (more comments in UserAdd)
	UsersLDAP->ReadLdap ();
	InitializeLdapConfiguration ($config);
	$error	= UsersLDAP->ReadSettings ();
	if ($error ne "") { return $error; }
	InitializeUsersLdapConfiguration ($config);

	# search with proper filter (= one DN/uid/uidNumber)
	# should be sufficient in this case...
	if ($key eq "dn") {
	    UsersLDAP->SetUserBase ($config->{$key});
	}
	elsif (!defined $config->{"user_filter"} && $key ne "") {
	    my $filter	= "$key=".$config->{$key};
	    UsersLDAP->AddToCurrentUserFilter ($filter);
	}
	# TODO it is possible that for the plugin we need some (unknown)
	# user attributes...
	if (!defined $config->{"user_attributes"}) {
	    UsersLDAP->SetUserAttributes ([]);
	}
	
	$error	= Users->ReadLDAPSet ();
	if ($error ne "") { return $error; }
    }
    elsif ($type eq "nis") {
	# error message
	return __("It is not possible to edit a NIS user.");
    }

    if ($key eq "uidNumber") {
	Users->SelectUser ($config->{$key}, $type);
    }
    elsif ($key ne "") {
	Users->SelectUserByName ($config->{$key}, $type);
    }

    $error = Users->EditUser ({});# we will need to create org_user map

    if ($error ne "") { return $error; }

    foreach my $plugin (@{$config->{"plugins"}}) {
	$error = Users->RemoveUserPlugin ($plugin);
    }

    if ($error eq "") {
	$error = Users->CheckUser ({});
	if ($error eq "" && Users->CommitUser ()) {
	    $error = Users->Write ();
	}
    }
    return $error;
}


=item *
C<$error UserDelete ($config_hash);>

Deletes existing user. Identification of user selected for delete is
stored in $config_hash.

Returns an error message if operation failed or empty string otherwise.


PARAMETERS:

    For general values of $config hash, see L<UserAdd>.
    For parameters necessary to identify the user, see L<UserModify>.
    Additinally, there is special parameter for

    "delete_home"	Integer: For 1, home directory of selected user
			will be deleted. Default value is 0 (false).


EXAMPLE:

  my $config	= { "type"		=> "ldap",
		    "dn"		=> "uid=ll,dc=example,dc=com",
		    "delete_home"	=> YaST::YCP::Boolean (1)
  };
  # deletes LDAP user together with its home directory
  my $error	= UserDelete ($config);

  $error	= UserDelete ({ "uid" => "hh", "type" => "local" });

=cut

BEGIN{$TYPEINFO{UserDelete} = ["function",
    "string",
    [ "map", "string", "any" ]];
}
sub UserDelete {

    my $self	= shift;
    my $config	= $_[0];
    my $error	= "";

    Users->SetGUI (0);

    my $type	= $config->{"type"} || "local";

    Users->SetReadLocal ($type ne "ldap");
    $error = Users->Read ();
    if ($error ne "") { return $error; }

    my $key	= "";
    if (defined $config->{"dn"} && $type eq "ldap") {
	$key	= "dn";
    }
    elsif (defined $config->{"uid"}) {
	$key	= "uid";
    }
    elsif (defined $config->{"uidNumber"}) {
	$key	= "uidNumber";
    }

    if ($type eq "ldap") {

	# initialize LDAP (more comments in UserAdd)
	UsersLDAP->ReadLdap ();
	InitializeLdapConfiguration ($config);
	$error	= UsersLDAP->ReadSettings ();
	if ($error ne "") { return $error; }
	InitializeUsersLdapConfiguration ($config);

	# search with proper filter (= one DN/uid/uidNumber)
	# should be sufficient in this case...
	if ($key eq "dn") {
	    UsersLDAP->SetUserBase ($config->{$key});
	}
	elsif (!defined $config->{"user_filter"} && $key ne "") {
	    my $filter = "$key=".$config->{$key};
	    UsersLDAP->AddToCurrentUserFilter ($filter);
	}
	
	$error	= Users->ReadLDAPSet ();
	if ($error ne "") { return $error; }
    }
    elsif ($type eq "nis") {
	# error message
	return __("It is not possible to delete a NIS user.");
    }

    if ($key eq "uidNumber") {
	Users->SelectUser ($config->{$key}, $type);
    }
    elsif ($key ne "") {
	Users->SelectUserByName ($config->{$key}, $type);
    }

    my $delete_home	= $config->{"delete_home"} || 0;

    if (Users->DeleteUser ($delete_home)) {
	if (Users->CommitUser ()) {
	    $error = Users->Write ();
	}
    }
    else {
	# error message
	$error 	= __("There is no such user.");
    }
    return $error;
}

=item *
C<$error UserDisable ($config_hash);>

Disables existing user to log in. Identification of user selected for delete is
stored in $config_hash.

Returns an error message if operation failed or empty string otherwise.


PARAMETERS:

    For general values of $config hash, see L<UserAdd>.
    For parameters necessary to identify the user, see L<UserModify>.


EXAMPLE:

  my $config	= { "type"		=> "ldap",
		    "uidNumber"		=> 500,
  };
  # disables LDAP user (as it is defined its plugins)
  my $error	= UserDisable ($config);

=cut

BEGIN{$TYPEINFO{UserDisable} = ["function",
    "string",
    [ "map", "string", "any" ]];
}
sub UserDisable {

    my $self	= shift;
    my $config	= $_[0];

    my @attributes	= ();
    if (defined $config->{"user_attributes"} &&
	ref ($config->{"user_attributes"}) eq "ARRAY") {
	@attributes	= @{$config->{"user_attributes"}};
    }
    if (! grep /^userPassword$/i, @attributes) {
	push @attributes, "userPassword";
    }
    $config->{"user_attributes"}	= \@attributes;

    return $self->UserModify ($config, { "disabled" => YaST::YCP::Boolean (1)});
}

=item *
C<$error UserEnable ($config_hash);>

Enables existing user to log in. Identification of user selected for delete is
stored in $config_hash.

Returns an error message if operation failed or empty string otherwise.


PARAMETERS:

    For general values of $config hash, see L<UserAdd>.
    For parameters necessary to identify the user, see L<UserModify>.


EXAMPLE:

  my $config	= { "type"		=> "ldap",
		    "uidNumber"		=> 500,
  };
  # enables LDAP user (in a default way, defined for LDAP users)
  my $error	= UserEnable ($config);

=cut

BEGIN{$TYPEINFO{UserEnable} = ["function",
    "string",
    [ "map", "string", "any" ]];
}
sub UserEnable {

    my $self	= shift;
    my $config	= $_[0];

    my @attributes	= ();
    if (defined $config->{"user_attributes"} &&
	ref ($config->{"user_attributes"}) eq "ARRAY") {
	@attributes	= @{$config->{"user_attributes"}};
    }
    if (! grep /^userPassword$/i, @attributes) {
	push @attributes, "userPassword";
    }
    $config->{"user_attributes"}	= \@attributes;

    return $self->UserModify ($config, { "enabled" => YaST::YCP::Boolean (1)});
}

=item *
C<$data_hash UserGet ($config_hash);>

Returns a map describing selected user.


PARAMETERS:

    For general values of $config hash, see L<UserAdd>.
    For parameters necessary to identify the user, see L<UserModify>.


EXAMPLE:

  my $config	= { "type"		=> "ldap",
		    "user_attributes"	=> [ "uid", "uidNumber", "cn" ],
		    "uidNumber"		=> 500
  };
  # searches for LDAP user with uidNumber 500 and returns the hash with given
  # attributes
  
  my $user	= UserGet ($config);

  $config	= { "type"		=> "ldap",
		    "uid"		=> "my_user",
		    "user_base"		=> "ou=people,dc=example,dc=com",
		    "bind_dn"		=> "uid=admin,dc=example,dc=com",
  };
  # searches for LDAP user with uid "my_user" in given search base and
  # returns the hash with all user's non-empty attributes
  $user		= UserGet ($config);

=cut

BEGIN{$TYPEINFO{UserGet} = ["function",
    [ "map", "string", "any" ],
    [ "map", "string", "any" ]];
}
sub UserGet {

    my $self	= shift;
    my $config	= $_[0];
    my $ret	= {};
    my $error	= "";

   
    Users->SetGUI (0);

    my $type	= $config->{"type"} || "local";

    Users->SetReadLocal ($type ne "ldap");
    $error = Users->Read ();
    if ($error ne "") { return $error; }

    my $key	= "";
    if (defined $config->{"dn"} && $type eq "ldap") {
	$key	= "dn";
    }
    elsif (defined $config->{"uid"}) {
	$key	= "uid";
    }
    elsif (defined $config->{"uidNumber"}) {
	$key	= "uidNumber";
    }

    if ($type eq "ldap") {

	# initialize LDAP (more comments in UserAdd)
	UsersLDAP->ReadLdap ();
	InitializeLdapConfiguration ($config);
	$error	= UsersLDAP->ReadSettings ();
	if ($error ne "") { return $error; }
	InitializeUsersLdapConfiguration ($config);

	# search with proper filter (= one DN/uid/uidNumber)
	# should be sufficient in this case...
	if ($key eq "dn") {
	    UsersLDAP->SetUserBase ($config->{$key});
	}
	elsif (!defined $config->{"user_filter"} && $key ne "") {
	    my $filter = "$key=".$config->{$key};
	    UsersLDAP->AddToCurrentUserFilter ($filter);
	}
	
	$error	= Users->ReadLDAPSet ();
	if ($error ne "") { return $ret; }
    }
    elsif ($type eq "nis") {
	Users->ReadNewSet ($type);
    }

    if ($key eq "uidNumber") {
	$ret	= Users->GetUser ($config->{$key}, $type);
    }
    elsif ($key ne "") {
	$ret	= Users->GetUserByName ($config->{$key}, $type);
    }
    elsif ($type eq "ldap") {
	# only for LDAP, when filter was given, but no key...
	my $users	= Users->GetUsers ("dn", $type);
	if (ref ($users) eq "HASH" && %{$users}) {
	    my @users	= sort values (%{$users});
	    if (@users > 1) {
		y2warning ("There are more users satisfying the input conditions");
	    }
	    if (@users > 0 && ref ($users[0]) eq "HASH") {
		$ret = $users[0];
	    }
	}
    }
    # return only requested attributes...
    if (($type eq "local" || $type eq "system") && $config->{"user_attributes"}) {
	my $attrs	= {};
	foreach my $key (@{$config->{"user_attributes"}}) {
	    $attrs->{$key}	= 1;
	}
	foreach my $key (keys %{$ret}) {
	    delete $ret->{$key} if !$attrs->{$key};
	}
    }
    return $ret;
}

=item *
C<$users_hash = UsersGet ($config_hash);>

Returns a hash describing the set of users. By default, the hash is indexed
by UID number, unless statet otherwise in $config_hash.


PARAMETERS:

    For general values of $config hash, see L<UserAdd>.
    Additionally, there is a special key

    "index"	The name of the key, which should be used as a index
		in the return hash.


EXAMPLE:

  my $config	= { "type"		=> "ldap",
		    "user_attributes"	=> [ "uid", "uidNumber", "cn" ],
		    "user_base"		=> "ou=people,dc=example,dc=com",
		    "user_scope"	=> YaST::YCP::Integer (2),
		    "user_filter"	=> [ "objectClass=posixAccount" ]
		    "index"		=> "dn"
  };
  # searches for LDAP users in given search base and returns the hash
  # indexed by DN's with the hash values containing users with given attributes
  my $users	= UsersGet ($config);

=cut

BEGIN{$TYPEINFO{UsersGet} = ["function",
    [ "map", "any", "any" ],
    [ "map", "string", "any" ]];
}
sub UsersGet {

    my $self	= shift;
    my $config	= $_[0];
    my $ret	= {};

    Users->SetGUI (0);

    my $type	= $config->{"type"} || "local";

    Users->SetReadLocal ($type ne "ldap");
    if (Users->Read ()) { return $ret; }

    if ($type eq "ldap") {

	# initialize LDAP (more comments in UserAdd)
	UsersLDAP->ReadLdap ();
	InitializeLdapConfiguration ($config);
	if (UsersLDAP->ReadSettings ()) { return $ret; }
	InitializeUsersLdapConfiguration ($config);

	# finally read LDAP tree contents
	# -- should be also filtered by InitializeConfiguration!
	if (Users->ReadLDAPSet ()) { return $ret; }
	# TODO should be only 'ldapsearch', not ReadLDAPSet (it creates some
	# internal keys, which shouldn't be neccessary
    }
    elsif ($type eq "nis") {
	Users->ReadNewSet ($type);
    }
	
    my $index		= $config->{"index"} || "uidNumber";

    $ret	= Users->GetUsers ($index, $type);

    # return only requested attributes...
    if (($type eq "local" || $type eq "system") && $config->{"user_attributes"}) {
	my $attrs	= {};
	foreach my $key (@{$config->{"user_attributes"}}) {
	    $attrs->{$key}	= 1;
	}
	foreach my $user (values %{$ret}) {
	    foreach my $key (keys %{$user}) {
		delete $user->{$key} if !$attrs->{$key};
	    }
	}
    }
    return $ret;
}

=item *
C<$error GroupAdd ($config_hash, $data_hash);>

Creates new group. Group attributes are described in $data_hash,
$config_hash describes special configuration data.

Returns an error message if operation failed or empty string otherwise.


PARAMETERS:


    Possible parameters for $config hash:

    "type"	Type of group (string). Possible values:
		"local","system","ldap","nis". ("nis" is not available
		for adding)


    Specific parameters of $config hash, related to LDAP groups (all keys
    are optional, there should exist reasonable default values based on
    current LDAP configuration):

    "bind_dn"	
		DN of LDAP administrator, used to bind to LDAP server
		(string)
		
    "bind_pw"	
		Password for LDAP administrator (string)
		
    "anonymous_bind"
    
		If this key is present, there will be done created an
		anonymous connection to LDAP server (if it is allowed).
		
    "member_attribute"
		Name of LDAP attribute, defining the membership in LDAP
		groups (possible values: "member", "uniquemember"). The
		default value is in /etc/ldap.conf (nss_map_attribute).

    
    "group_attributes"
		List of attributes to be returned by an LDAP search for
		group (list of strings). If empty, all non-empty
		attributes will be returned as a result of search.

    "group_base"
		DN of LDAP base where the groups are stored (string). By
		default, the value of "suseDefaultBase" stored in LDAP
		configuration is used.

    "group_filter"
		Filter for restricting LDAP searches (string).
		The default value is stored as "suseSearchFilter" in 
		LDAP configuration.

    "group_scope"
		The scope used for LDAP searches for groups. Possible
		values are 0 (base), 1(one), 2(sub). Default is 2.


    "group_plugins"
		List of plugins which should be applied for group
		(list of strings). General plugin for LDAP groups,
		("UsersPluginLDAPAll") is always available, others are
		part of modules which has to be installed before their
		usage (yast2-samba-server, yast2-mail-server).



    Possible parameters for $data hash:

    "gidNumber"		GID number of the group
    "cn"		Group name
    "userPassword"	Password for the group.
    "userlist"		Hash (of type { <username> => 1 }) with
			the users that should be members of this group.
			Optionally, this could be also the list of
			user names.

    <member_attribute>	For LDAP groups, correct member attribute (
			"member"/"uniquemember") has to be used instead
			of "userlist". It could be list of user names or
			hash with DN's of the members.

    <ldap_attribute>	Any LDAP attribute supported by groups's object class



EXAMPLE:

  my $config	= { "type"		=> "ldap",
		    "group_plugins"	=> [ "GroupsPluginsLDAPAll" ],
		    "bind_dn"		=> "uid=admin,dc=example,dc=com",
		    "group_base"	=> "ou=groups,dc=example,dc=com"
  };
  my $data	= { "gidNumber"		=> 5555,
		    "cn"		=> "lgroup",
		    "member"		=> {
			"uid=test,ou=people,dc=example,dc=com"	=> 1,
			"uid=ll,ou=people,dc=example,dc=com"	=> 1
		    }
  };
  # create new LDAP group

  my $error	= GroupAdd ($config, $data);

  # create new system group 
  GroupAdd ({ "type" => "system" }, {
	"cn"		=> "ggg",
	"userlist"	=> {
	    "root"	=> 1,
	    "hh"	=> 1
	}
  );

=cut

BEGIN{$TYPEINFO{GroupAdd} = ["function",
    "string",
    [ "map", "string", "any" ],
    [ "map", "string", "any" ]];
}
sub GroupAdd {

    my $self	= shift;
    my $config	= $_[0];
    my $data	= $_[1];
    my $error	= "";

    Users->SetGUI (0);

    my $type	= $config->{"type"} || "local";

    # convert 'member' from list to hash if necessary
    my $member_attr	= UsersLDAP->GetMemberAttribute ();
    if ($type ne "ldap") {
	$member_attr	= "userlist";
    }
    if (defined $data->{$member_attr} && ref($data->{$member_attr}) eq "ARRAY"){
	my @userlist		= @{$data->{$member_attr}};
	$data->{$member_attr}	= {};
	foreach my $u (@userlist) {
	    $data->{$member_attr}{$u}	= 1;
	}
    }
    if (!defined $data->{$member_attr}) {
	$data->{$member_attr}   = {};
    }

    $error = Users->Read ();
    if ($error ne "") { return $error; }

    if ($type eq "ldap") {

	# initialize LDAP (more comments in UserAdd)
	UsersLDAP->ReadLdap ();
	InitializeLdapConfiguration ($config);
	$error	= UsersLDAP->ReadSettings ();
	if ($error ne "") { return $error; }
	InitializeUsersLdapConfiguration ($config);

	SetNecessaryGroupAttributes ([]);

	# do not read users at all...
	UsersLDAP->SetCurrentUserFilter ("0=1");

	# finally read LDAP tree
	$error	= Users->ReadLDAPSet ();
	if ($error ne "") { return $error; }
    }
    $data->{"type"}	= $type;

    Users->ResetCurrentGroup ();
    
    $error = Users->AddGroup ($data);
    if ($error ne "") { return $error; }

    if ($type eq "ldap") {
	Users->SubstituteGroupValues ();
    }
	
    $error = Users->CheckGroup ({});
    if ($error ne "") {
	return $error;
    }
    if (Users->CommitGroup ()) {
	$error = Users->Write ();
    }

    return $error;
}

=item *
C<$error GroupModify ($config_hash, $data_hash);>

Modifies existing group. Group attributes which should be changed
are described in $data_hash,
$config_hash describes special configuration data, especially group
identification.

Returns an error message if operation failed or empty string otherwise.


PARAMETERS:

    For general values of $config hash, see L<GroupAdd>.
    Additinally, $config must contain one of the key used to identify
    the group which should be modified:

    "dn"	Distingueshed name (only for of LDAP group)
    "cn"	Group name (or value of "cn" attribute for LDAP group).
    "gidNumber"	GID number (value of "gidNumber" for LDAP group).


EXAMPLE

  # change GID value of local group (identified with name)
  my $error	= GroupModify ({ "cn" => "users" }, { "gidNumber" => 101 });

  my $config	= { "type"		=> "ldap",
		    "gidNumber"		=> 5555
  };
  my $data	= { "member"		=> [
			"uid=test,ou=people,dc=example,dc=com",
			"uid=ll,ou=people,dc=example,dc=com",
			"uid=admin,dc=example,dc=com"
		    ]
  };
  # changes a member attribute of LDAP group (identified with id)
  $error	= GroupModify ($config, $data);

    
NOTE

  You can see on example that "member" attribute could be passed either
  as an array (which could one expect for LDAP attribute) or as hash,
  (which is used by YaST for internal representation) as shown in example
  for GroupAdd () function. YaST always takes care of it and does the
  necessary conversions.

=cut

BEGIN{$TYPEINFO{GroupModify} = ["function",
    "string",
    [ "map", "string", "any" ],
    [ "map", "string", "any" ]];
}
sub GroupModify {

    my $self	= shift;
    my $config	= $_[0];
    my $data	= $_[1];
    my $error	= "";

    Users->SetGUI (0);

    my $type	= $config->{"type"} || "local";

    $error = Users->Read ();
    if ($error ne "") { return $error; }

    # 1. select group
    my $key	= "";
    if (defined $config->{"dn"} && $type eq "ldap") {
	$key	= "dn";
    }
    elsif (defined $config->{"cn"}) {
	$key	= "cn";
    }
    elsif (defined $config->{"gidNumber"}) {
	$key	= "gidNumber";
    }

    # convert 'member' from list to hash if necessary
    my $member_attr	= UsersLDAP->GetMemberAttribute ();
    if ($type ne "ldap") {
	$member_attr	= "userlist";
    }
    if (defined $data->{$member_attr} && ref($data->{$member_attr}) eq "ARRAY"){
	my @userlist		= @{$data->{$member_attr}};
	$data->{$member_attr}	= ();
	foreach my $u (@userlist) {
	    $data->{$member_attr}{$u}	= 1;
	}
    }

    if ($type eq "ldap") {

	# initialize LDAP (more comments in UserAdd)
	UsersLDAP->ReadLdap ();
	InitializeLdapConfiguration ($config);
	$error	= UsersLDAP->ReadSettings ();
	if ($error ne "") { return $error; }
	InitializeUsersLdapConfiguration ($config);

	# If we want to atributes, that should be unique
	# (cn/dn/gidNumber/memebr we must read everything to check
	# possible conflicts...
	my $read_all	= 0;
	if (defined $data->{"cn"} || defined $data->{"gidNumber"} ||
	    defined $data->{$member_attr}) {
	    $read_all	= 1;
	}

	# search with proper filter (= one DN/uid/uidNumber)
	# should be sufficient in this case...
	if ($key eq "dn" && !$read_all) {
	    UsersLDAP->SetGroupBase ($config->{$key});
	}
	elsif (!defined $config->{"group_filter"} && $key ne "" && !$read_all) {
	    my $filter	= "$key=".$config->{$key};
	    UsersLDAP->AddToCurrentGroupFilter ($filter);
	}
	# Let's create the minimal list of neccessary attributes to get
	SetNecessaryGroupAttributes ([ $member_attr ]);
	# (if member_attr wouldn't be included, it will be counted as empty...

	# -----------------------------------------------------
	# let's limit also user data which we need to read
	# (gidNumber is changed) <-> (user modification necessary)
	if (!defined $data->{"gidNumber"}) {
	    # -> so we don't need to read any user now...
	    UsersLDAP->SetCurrentUserFilter ("0=1");
	}
	SetNecessaryUserAttributes (["gidNumber"]);
	# ----------
	
	$error	= Users->ReadLDAPSet ();
	if ($error ne "") { return $error; }
    }
    elsif ($type eq "nis") {
	# error message
	return __("It is not possible to modify a NIS group.");
    }

    if ($key eq "gidNumber") {
	Users->SelectGroup ($config->{$key}, $type);
    }
    elsif ($key ne "") {
	Users->SelectGroupByName ($config->{$key}, $type);
    }
    # 'dn' has to be passed in $data map so it could be changed
    # FIXME it is currently not possible to move entry deeper in the tree
    # -> allow setting 'dn' in data map!
    if ($type eq "ldap" && !defined $data->{"dn"}) {
	my $group	= Users->GetCurrentGroup ();
	$data->{"dn"}	= $group->{"dn"};
    }

    $error = Users->EditGroup ($data);
    if ($error eq "") {
	$error = Users->CheckGroup ({});
	if ($error eq "" && Users->CommitGroup ()) {
	    $error = Users->Write ();
	}
    }
    return $error;
}

=item *
C<$error GroupMemberAdd ($config_hash, $user_hash);>

Adds a new member to the given group. User is described in $user_hash,
group identification is passwd in $config_hash. User must exist.

Returns an error message if operation failed or empty string otherwise.


PARAMETERS:

    For general values of $config hash, see L<GroupAdd>.
    For parameters necessary to identify the group, see L<GroupModify>.
    $user_hash must include the information necessary to identify the
    user. This has to be one of these keys:

    "dn"	Distinguished name (DN) [only for LDAP users]
    "uid"	User name (which is "uid" attribute for LDAP user)
    "uidNumber"	UID (which is "uidNumber" attribute for LDAP user)


EXAMPLE:

  my $config	= { "type"		=> "ldap",
		    "bind_dn"		=> "uid=admin,dc=example,dc=com",
		    "gidNumber"		=> 5555
  };
  my $user	= { "uid"		=> "my_user" }
  };

  my $error	= GroupMemberAdd ($config, $user);

=cut

BEGIN{$TYPEINFO{GroupMemberAdd} = ["function",
    "string",
    [ "map", "string", "any" ],
    [ "map", "string", "any" ]];
}
sub GroupMemberAdd {

    my $self	= shift;
    my $config	= shift;
    my $user	= shift;
    my $error	= "";

    Users->SetGUI (0);

    if (!defined $user || ref ($user) ne "HASH" || ! %$user) {
	# error message
	return __("No user was specified.");
    }
    
    my $type	= $config->{"type"} || "local";

    Users->SetReadLocal ($type ne "ldap");
    $error = Users->Read ();
    if ($error ne "") { return $error; }

    my $key	= "";
    if (defined $config->{"dn"} && $type eq "ldap") {
	$key	= "dn";
    }
    elsif (defined $config->{"cn"}) {
	$key	= "cn";
    }
    elsif (defined $config->{"gidNumber"}) {
	$key	= "gidNumber";
    }

    if ($type eq "ldap") {

	# initialize LDAP (more comments in UserAdd)
	UsersLDAP->ReadLdap ();
	InitializeLdapConfiguration ($config);
	$error	= UsersLDAP->ReadSettings ();
	if ($error ne "") { return $error; }
	InitializeUsersLdapConfiguration ($config);

	# search with proper filter (= one DN/uid/uidNumber)
	# should be sufficient in this case...
	if ($key eq "dn") {
	    UsersLDAP->SetGroupBase ($config->{$key});
	}
	elsif (!defined $config->{"group_filter"} && $key ne "") {
	    my $filter = "$key=".$config->{$key};
	    UsersLDAP->AddToCurrentGroupFilter ($filter);
	}
	
	# find the specified user if dn was not given
	if (defined $user->{"dn"}) {
	    UsersLDAP->SetCurrentUserFilter ("0=1");
	    UsersLDAP->SetUserBase ($user->{"dn"});
	}
	else {
	    foreach my $u_key (keys %$user) {
		my $filter	= "$u_key=".$user->{$u_key};
		UsersLDAP->AddToCurrentUserFilter ($filter);
	    }
	}

	$error	= Users->ReadLDAPSet ();
	if ($error ne "") { return $error; }
    }
    elsif ($type eq "nis") {
	# error message
	return __("It is not possible to modify a NIS group.");
    }

    if ($key eq "gidNumber") {
	Users->SelectGroup ($config->{$key}, $type);
    }
    elsif ($key eq "cn") {
	Users->SelectGroupByName ($config->{$key}, $type);
    }
    elsif ($key eq "dn") {
	Users->SelectGroupByDN ($config->{$key}, $type);
    }
    my $group 	= Users->GetCurrentGroup ();
    if (!defined $group || ! %{$group}) {
	# error message
	return __("There is no such group.");
    }
    # get the user which should be removed from the group
    my $user_id 	= $user->{"dn"};
    if ($type ne "ldap") {
	$user_id	= $user->{"uid"};
    }
    if (!defined $user_id) {
	my $usermap	= ();
	if (defined $user->{"uid"}) {
	    $usermap	= Users->GetUserByName ($user->{"uid"}, $type);
	}
	elsif (defined $user->{"uidNumber"}) {
	    $usermap	= Users->GetUser ($user->{"uidNumber"}, $type);
	}
	if ($type eq "ldap") {
	    $user_id	= $usermap->{"dn"};
	    # TODO maybe there is ony one user loaded, but not specified by
	    # uid/uidNumber/dn... ->GetUserByAttribute...
	}
	else {
	    $user_id	= $usermap->{"uid"};
	}
    }
    if (!defined $user_id) {
	# error message
	return __("User was not correctly specified.");
    }

    my $member_attr	= UsersLDAP->GetMemberAttribute ();
    if ($type ne "ldap") {
	$member_attr	= "userlist";
    }
    my $data	= {
	$member_attr	=> $group->{$member_attr}
    };
    $data->{$member_attr}{$user_id}	= 1;

    $error = Users->EditGroup ($data);
    if ($error eq "") {
	$error = Users->CheckGroup ({});
	if ($error eq "" && Users->CommitGroup ()) {
	    $error = Users->Write ();
	}
    }
    return $error;
}

=item *
C<$error GroupMemberDelete ($config_hash, $user_hash);>

Deletes a member from the group.

Returns an error message if operation failed or empty string otherwise.

PARAMETERS:

    For general values of $config hash, see L<GroupAdd>.
    For parameters necessary to identify the group, see L<GroupModify>.
    $user_hash must include the information necessary to identify the
    user - see L<GroupMemberAdd>


EXAMPLE:

  my $config	= { "type"		=> "ldap",
		    "dn"		=> "cn=lgroup,dc=example,dc=com"
  };
  my $user	= { "uidNumber"		=> 1000 }

  # removes user with given uidNumber from group with given DN
  my $error	= GroupMemberDelete ($config, $user);

=cut

BEGIN{$TYPEINFO{GroupMemberDelete} = ["function",
    "string",
    [ "map", "string", "any" ],
    [ "map", "string", "any" ]
    ];
}
sub GroupMemberDelete {

    my $self	= shift;
    my $config	= shift;
    my $user	= shift;
    my $error	= "";

    Users->SetGUI (0);

    if (!defined $user || ref ($user) ne "HASH" || ! %$user) {
	# error message
	return __("No user was specified.");
    }
    
    my $type	= $config->{"type"} || "local";

    Users->SetReadLocal ($type ne "ldap");
    $error = Users->Read ();
    if ($error ne "") { return $error; }

    my $key	= "";
    if (defined $config->{"dn"} && $type eq "ldap") {
	$key	= "dn";
    }
    elsif (defined $config->{"cn"}) {
	$key	= "cn";
    }
    elsif (defined $config->{"gidNumber"}) {
	$key	= "gidNumber";
    }

    if ($type eq "ldap") {

	# initialize LDAP (more comments in UserAdd)
	UsersLDAP->ReadLdap ();
	InitializeLdapConfiguration ($config);
	$error	= UsersLDAP->ReadSettings ();
	if ($error ne "") { return $error; }
	InitializeUsersLdapConfiguration ($config);

	# search with proper filter (= one DN/uid/uidNumber)
	# should be sufficient in this case...
	if ($key eq "dn") {
	    UsersLDAP->SetGroupBase ($config->{$key});
	}
	elsif (!defined $config->{"group_filter"} && $key ne "") {
	    my $filter = "$key=".$config->{$key};
	    UsersLDAP->AddToCurrentGroupFilter ($filter);
	}
	
	# find the specified user if dn was not given
	if (defined $user->{"dn"}) {
	    UsersLDAP->SetCurrentUserFilter ("0=1");
	    UsersLDAP->SetUserBase ($user->{"dn"});
	}
	else {
	    foreach my $u_key (keys %$user) {
		my $filter	= "$u_key=".$user->{$u_key};
		UsersLDAP->AddToCurrentUserFilter ($filter);
	    }
	}

	$error	= Users->ReadLDAPSet ();
	if ($error ne "") { return $error; }
    }
    elsif ($type eq "nis") {
	# error message
	return __("It is not possible to modify a NIS group.");
    }

    if ($key eq "gidNumber") {
	Users->SelectGroup ($config->{$key}, $type);
    }
    elsif ($key eq "cn") {
	Users->SelectGroupByName ($config->{$key}, $type);
    }
    elsif ($key eq "dn") {
	Users->SelectGroupByDN ($config->{$key}, $type);
    }
    my $group 	= Users->GetCurrentGroup ();
    if (!defined $group || ! %{$group}) {
	# error message
	return __("There is no such group.");
    }
    # get the user which should be removed from the group
    my $user_id 	= $user->{"dn"};
    if ($type ne "ldap") {
	$user_id	= $user->{"uid"};
    }
    if (!defined $user_id) {
	my $usermap	= ();
	if (defined $user->{"uid"}) {
	    $usermap	= Users->GetUserByName ($user->{"uid"}, $type);
	}
	elsif (defined $user->{"uidNumber"}) {
	    $usermap	= Users->GetUser ($user->{"uidNumber"}, $type);
	}
	if ($type eq "ldap") {
	    $user_id	= $usermap->{"dn"};
	    # TODO maybe there is ony one user loaded, but not specified by
	    # uid/uidNumber/dn... ->GetUserByAttribute...
	}
	else {
	    $user_id	= $usermap->{"uid"};
	}
    }
    if (!defined $user_id) {
	# error message
	return __("User was not correctly specified.");
    }

    my $member_attr	= UsersLDAP->GetMemberAttribute ();
    if ($type ne "ldap") {
	$member_attr	= "userlist";
    }
    my $data	= {
	$member_attr	=> $group->{$member_attr}
    };

    if (defined $data->{$member_attr}{$user_id}) {
	delete $data->{$member_attr}{$user_id};
    }
    $error = Users->EditGroup ($data);
    #TODO beware, org_group is not correcty initialized... but it doesn't hurt
    #currently, because we do not check the change against org_group... 
    if ($error eq "") {
	$error = Users->CheckGroup ({});
	if ($error eq "" && Users->CommitGroup ()) {
	    $error = Users->Write ();
	}
    }
    return $error;
}


=item *
C<$error GroupDelete ($config_hash);>

Deletes existing group. Identification of group is stored in $config_hash.

Returns an error message if operation failed or empty string otherwise.


PARAMETERS:

    For general values of $config hash, see L<GroupAdd>.
    For parameters necessary to identify the group, see L<GroupModify>.

 
EXAMPLE:

  my $config	= { "type"		=> "local",
		    "uid"		=> "users"
  };
  my $error	= GroupDelete ($config);

=cut

BEGIN{$TYPEINFO{GroupDelete} = ["function",
    "string",
    [ "map", "string", "any" ]];
}
sub GroupDelete {

    my $self	= shift;
    my $config	= $_[0];
    my $error	= "";

    Users->SetGUI (0);

    my $type	= $config->{"type"} || "local";

    Users->SetReadLocal ($type ne "ldap");
    $error = Users->Read ();
    if ($error ne "") { return $error; }

    my $key	= "";
    if (defined $config->{"dn"} && $type eq "ldap") {
	$key	= "dn";
    }
    elsif (defined $config->{"cn"}) {
	$key	= "cn";
    }
    elsif (defined $config->{"gidNumber"}) {
	$key	= "gidNumber";
    }
    
    if ($type eq "ldap") {

	# initialize LDAP (more comments in UserAdd)
	UsersLDAP->ReadLdap ();
	InitializeLdapConfiguration ($config);
	$error	= UsersLDAP->ReadSettings ();
	if ($error ne "") { return $error; }
	InitializeUsersLdapConfiguration ($config);

	# search with proper filter (= one DN/uid/uidNumber)
	# should be sufficient in this case...
	if ($key eq "dn") {
	    UsersLDAP->SetGroupBase ($config->{$key});
	}
	elsif (!defined $config->{"group_filter"} && $key ne "") {
	    my $filter = "$key=".$config->{$key};
	    UsersLDAP->AddToCurrentGroupFilter ($filter);
	}
	# we must read users to check if group is not default group for someone

	# read only users 'affected' by our group number
	if (defined $config->{"gidNumber"}) {
	    my $filter = "gidNumber=".$config->{"gidNumber"};
	    UsersLDAP->AddToCurrentUserFilter ($filter);
	    # TODO read gidNumber by ldapsearch if not given
	}
	SetNecessaryUserAttributes (["gidNumber"]);

	$error	= Users->ReadLDAPSet ();
	if ($error ne "") { return $error; }
    }
    elsif ($type eq "nis") {
	# error message
	return __("It is not possible to delete a NIS group.");
    }

    if ($key eq "gidNumber") {
	Users->SelectGroup ($config->{$key}, $type);
    }
    elsif ($key eq "cn") {
	Users->SelectGroupByName ($config->{$key}, $type);
    }
    elsif ($key eq "dn") {
	Users->SelectGroupByDN ($config->{$key}, $type);
    }

    # do not delete non-empty group!
    # (TODO we could enable it with some 'force_delete' flag?)
    $error	= Users->CheckGroupForDelete ({});
    if ($error ne "") { return $error; }

    if (Users->DeleteGroup ()) {
	if (Users->CommitGroup ()) {
	    $error = Users->Write ();
	}
    }
    else {
	# error message
	$error 	= __("There is no such group.");
    }
    return $error;
}

=item *
C<$data_hash GroupGet ($config_hash);>

Returns a map describing selected group.


PARAMETERS:

    For general values of $config hash, see L<GroupAdd>.
    For parameters necessary to identify the group, see L<GroupModify>.

 
EXAMPLE:

  my $config	= { "type"		=> "ldap",
		    "group_attributes"	=> [ "cn", "gidNumber", "member" ],
		    "gidNumber"		=> 500
  };
  # searches for LDAP group with gidNumber 500 and returns the hash
  # with given attributes
  my $group	= GroupGet ($config);

=cut

BEGIN{$TYPEINFO{GroupGet} = ["function",
    [ "map", "string", "any" ],
    [ "map", "string", "any" ]];
}
sub GroupGet {

    my $self	= shift;
    my $config	= $_[0];
    my $ret	= {};
    my $error	= "";

    Users->SetGUI (0);

    my $type	= $config->{"type"} || "local";

    Users->SetReadLocal ($type ne "ldap");
    $error = Users->Read ();
    if ($error ne "") { return $error; }

    my $key	= "";
    if (defined $config->{"dn"} && $type eq "ldap") {
	$key	= "dn";
    }
    elsif (defined $config->{"cn"}) {
	$key	= "cn";
    }
    elsif (defined $config->{"gidNumber"}) {
	$key	= "gidNumber";
    }

    if ($type eq "ldap") {

	# initialize LDAP (more comments in UserAdd)
	UsersLDAP->ReadLdap ();
	InitializeLdapConfiguration ($config);
	$error	= UsersLDAP->ReadSettings ();
	if ($error ne "") { return $error; }
	InitializeUsersLdapConfiguration ($config);

	# search with proper filter (= one DN/uid/uidNumber)
	# should be sufficient in this case...
	if ($key eq "dn") {
	    UsersLDAP->SetGroupBase ($config->{$key});
	}
	elsif (!defined $config->{"group_filter"} && $key ne "") {
	    my $filter = "$key=".$config->{$key};
	    UsersLDAP->AddToCurrentGroupFilter ($filter);
	}
	# read only users 'affected' by our group number
	if (defined $config->{"gidNumber"}) {
	    my $filter = "gidNumber=".$config->{"gidNumber"};
	    UsersLDAP->AddToCurrentUserFilter ($filter);
	    # TODO read gidNumber by ldapsearch if not given
	}
	else {
	    # we don't need any users -> fake filter for faster searching
	    UsersLDAP->SetCurrentUserFilter ("0=1");
	}
	SetNecessaryUserAttributes (["gidNumber"]);

	$error	= Users->ReadLDAPSet ();
	if ($error ne "") { return $ret; }
    }
    elsif ($type eq "nis") {
	Users->ReadNewSet ($type);
    }

    if ($key eq "gidNumber") {
	$ret	= Users->GetGroup ($config->{$key}, $type);
    }
    elsif ($key eq "cn") {
	$ret	= Users->GetGroupByName ($config->{$key}, $type);
    }
    elsif ($key eq "dn") {
	$ret	= Users->GetGroupByDN ($config->{$key}, $type);
    }
    elsif ($type eq "ldap") {
	# only for LDAP, when filter was given, but no key...
	my $groups	= Users->GetGroups ("dn", $type);
	if (ref ($groups) eq "HASH" && %{$groups}) {
	    my @groups	= sort values (%{$groups});
	    if (@groups > 1) {
		y2warning ("There are more groups satisfying the input conditions");
	    }
	    if (@groups > 0 && ref ($groups[0]) eq "HASH") {
		$ret = $groups[0];
	    }
	}
    }
    return $ret;
}

=item *
C<$groups_hash GroupsGet ($config_hash);>

Returns a hash describing the set of groups. By default, the hash is indexed
by GID number, unless statet otherwise in $config_hash.


PARAMETERS:

    For general values of $config hash, see L<GroupAdd>.
    Additionally, there is a special key

    "index"	The name of the key, which should be used as a index
		in the return hash (default value is "gidNumber").


EXAMPLE:

  # searches for LDAP groups in default base and returns the hash
  # indexed by GID's with the hash values containing groups with all
  # non-empty attributes
  my $groups	= GroupsGet ({ "type" => "ldap" });

  # returns hash with all NIS groups
  $groups	= GroupsGet ({ "type" => "nis" });

=cut

BEGIN{$TYPEINFO{GroupsGet} = ["function",
    [ "map", "string", "any" ],
    [ "map", "string", "any" ]];
}
sub GroupsGet {

    my $self	= shift;
    my $config	= $_[0];
    my $ret	= {};
    my $error	= "";

    Users->SetGUI (0);

    my $type	= $config->{"type"} || "local";

    Users->SetReadLocal ($type ne "ldap");
    if (Users->Read ()) { return $ret; }

    if ($type eq "ldap") {

	# initialize LDAP (more comments in UserAdd)
	UsersLDAP->ReadLdap ();
	InitializeLdapConfiguration ($config);
	if (UsersLDAP->ReadSettings ()) {
	    return $ret;
	}
	InitializeUsersLdapConfiguration ($config);

	if (!defined $config->{"user_filter"}) {
	    # we don't need any users -> fake filter for faster searching
	    UsersLDAP->SetCurrentUserFilter ("0=1");
	}
	# finally read LDAP tree contents
	# -- should be also filtered by InitializeConfiguration!
	if (Users->ReadLDAPSet ()) {
	    return $ret;
	}
    }
    elsif ($type eq "nis") {
	Users->ReadNewSet ($type);
    }
	
    my $index		= $config->{"index"} || "gidNumber";

    return Users->GetGroups ($index, $type);
}

=item *
C<$groups_hash GroupsGetByUser ($config_hash, $user_hash);>

Returns a hash describing the set of groups. By default, the hash is indexed
by GID number, unless stated differently in $config_hash.


PARAMETERS:

    For general values of $config hash, see L<GroupAdd>.
    $user_hash must include the information necessary to identify the
    user - see L<GroupMemberAdd>.
    Additionally, there is a special key

    "index"	The name of the key, which should be used as a index
		in the return hash.


EXAMPLE:

  my $config	= { "type"	=> "ldap",
		    "index"	=> "dn"
		    "group_scope"	=> YaST::YCP::Integer (2),
  };
  my $user	= { "dn"	=> "uid=ll,ou=people,dc=example,dc=com" };

  # searches for LDAP groups in default base and returns the hash
  # indexed by DN's with the hash values containing groups with all
  # non-empty attributes
  my $groups	= GroupsGetByUser ($config, $user);

=cut

BEGIN{$TYPEINFO{GroupsGetByUser} = ["function",
    [ "map", "string", "any" ],
    [ "map", "string", "any" ],
    [ "map", "string", "any" ]];
}
sub GroupsGetByUser {

    my $self	= shift;
    my $config	= shift;
    my $user	= shift;
    my $ret	= {};

    Users->SetGUI (0);

    if (!defined $user || ref ($user) ne "HASH" || ! %$user) {
	# error message
	my $error 	= __("No user was specified.");
	y2warning ($error);
	return {};
    }
    
    my $type	= $config->{"type"} || "";# no type = search local&system groups

    Users->SetReadLocal ($type ne "ldap");
    if (Users->Read ()) { return $ret; }

    if ($type eq "ldap") {

	# initialize LDAP (more comments in UserAdd)
	UsersLDAP->ReadLdap ();
	InitializeLdapConfiguration ($config);
	if (UsersLDAP->ReadSettings ()) { return $ret; }
	InitializeUsersLdapConfiguration ($config);

	my $member_attr     = UsersLDAP->GetMemberAttribute ();
	
	# search the group with user's dn as a filter
	my $user_dn	= "";
	if (defined $user->{"dn"}) {
	    $user_dn	= $user->{"dn"};
	}
	else {
	    my $filter = UsersLDAP->GetCurrentUserFilter ();
	    if ($filter eq "") {
		$filter	= UsersLDAP->GetDefaultUserFilter ();
	    }
	    UsersLDAP->SetCurrentUserFilter ($filter);
	    foreach my $u_key (keys %$user) {
		my $filter	= "$u_key=".$user->{$u_key};
		UsersLDAP->AddToCurrentUserFilter ($filter);
	    }
	    $filter = UsersLDAP->GetCurrentUserFilter ();
	    my $res = SCR->Read (".ldap.search", {
		"base_dn"	=> UsersLDAP->GetUserBase (),
		"scope"		=> YaST::YCP::Integer (2),
		"filter"	=> $filter,
		"include_dn"	=> 1,
		"attrs"		=> UsersLDAP->GetUserAttributes ()
	    });
	    if (!defined $res || ref ($res) ne "ARRAY" || @{$res} == 0) {
		return $ret;
	    }
	    if (@{$res} > 1) {
		# error message
		my $error = __("There are multiple users satisfying the input conditions.");
		y2warning ($error);
		return $ret;
	    }
	    if (defined $res->[0]->{"dn"}) {
		$user_dn	=  $res->[0]->{"dn"};
	    }
	}
	UsersLDAP->AddToCurrentGroupFilter ("$member_attr=$user_dn");
	UsersLDAP->SetCurrentUserFilter ("0=1");

	if (Users->ReadLDAPSet ()) { return $ret; }
    }
    elsif ($type eq "nis") {
	Users->ReadNewSet ($type);
    }

    # index to search the output
    my $index		= $config->{"index"} || "gidNumber";

    if ($type ne "ldap") {
	# get the specified user

	if (!defined $user->{"uid"} && !defined $user->{"uidNumber"}) {
	    # error message
	    my $error = __("User was not correctly specified.");
	    y2warning ($error);
	    return {};
	}
	my $user_id	= $user->{"uid"};
	my $usermap	= {};
	my $user_type	= $user->{"type"} || $type;
	if (defined $user_id) {
	    $usermap	= Users->GetUserByName ($user->{"uid"}, $user_type);
	}
	else {
	    $usermap	= Users->GetUser ($user->{"uidNumber"}, $user_type);
	}
	if (!defined $usermap || ref ($usermap) ne "HASH" || !%{$usermap}) {
	    # error message
	    my $error 	= __("There is no such user.");
	    y2warning ($error);
	    return {};
	}
	# now check its grouplist entry...
	if (defined $usermap->{"grouplist"}) {
	    foreach my $cn (keys %{$usermap->{"grouplist"}}) {
		my $group	= Users->GetGroupByName ($cn, $type);
		if (defined $group->{$index}) {
		    $ret->{$group->{$index}}	= $group;
		}
	    }
	}
    }
    else {
	$ret = Users->GetGroups ($index, $type);
    }
    return $ret;
}

# Read various default values. The argument map defines what should be returned
# in the return map
BEGIN{$TYPEINFO{Read} = ["function",
    [ "map", "string", "any" ],
    [ "map", "string", "any" ]];
}
sub Read {

    my $self	= shift;
    my $args	= shift;
    my $ret	= {};

    Users->SetGUI (0);

    my $user_type	= $args->{"user_type"} || "local";

    if ($args->{"login_defaults"} || 0) {
	Users->ReadLoginDefaults ();
	$ret->{"login_defaults"}	= Users->GetLoginDefaults ();
    }
    # return password length limitation for given user ('local' by default)
    if ($args->{"password_length"} || 0) {
	Users->ReadSystemDefaults (1);
	$ret->{"pw_min"}	= UsersSimple->GetMinPasswordLength ($user_type);
	$ret->{"pw_max"}	= UsersSimple->GetMaxPasswordLength ($user_type);
    }

    if ($args->{"uid_limits"} || 0) {
	Users->ReadSystemDefaults (0);
	my %configuration 	= (
	    "max_system_uid"	=> UsersCache->GetMaxUID ("system"),
	    "max_system_gid"	=> UsersCache->GetMaxGID ("system")
	);
	UsersPasswd->Read (\%configuration); # for filling last UID...

	UsersCache->SetLastUID (UsersPasswd->GetLastUID ($user_type), $user_type);
	$ret->{"uid_min"}	= UsersCache->GetMinUID ($user_type);
	$ret->{"uid_max"}	= UsersCache->GetMaxUID ($user_type);
	$ret->{"uid_next"}	= UsersCache->NextFreeUID ();
    }
    if ($args->{"all_shells"} || 0) {
	Users->ReadAllShells ();
	$ret->{"all_shells"}	= Users->AllShells ();
    }
    return $ret;
}

42;
