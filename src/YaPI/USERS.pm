=head1 NAME

YaPI::USERS

=head1 PREFACE

This package is the public YaST2 API for Users/Groups management

=head1 SYNOPSIS

use YaPI::USERS

$error = UserAdd ($config_hash, $data_hash);

    Creates new user, described in $data_hash.
    Returns an error message if operation failed or empty string otherwise.

$error = UserModify ($config_hash, $data_hash);

    Modifies the data of given user.
    Returns an error message if operation failed or empty string otherwise.

$error = UserFeatureAdd ($config_hash);

    Adds a new feature (plugin) to the given user.
    Returns an error message if operation failed or empty string otherwise.

$error = UserFeatureDelete ($config_hash);

    Removes a feature (plugin) from the given user.
    Returns an error message if operation failed or empty string otherwise.

$error = UserDelete ($config_hash);

    Deletes an existing user.
    Returns an error message if operation failed or empty string otherwise.

$error = UserDisable ($config_hash);

    Disable user to log in.
    Returns an error message if operation failed or empty string otherwise.

$error = UserEnable ($config_hash);

    Enable disabled user to log in again.
    Returns an error message if operation failed or empty string otherwise.

$data_hash = UserGet ($config_hash);

    Returns data hash decribing user.

$users_hash = UsersGet ($config_hash);

    Returns hash of users. The resulting set is defined in $config hash.

$error = GroupAdd ($config_hash, $data_hash);

    Creates new group, described in $data_hash.
    Returns an error message if operation failed or empty string otherwise.

$error = GroupModify ($config_hash, $data_hash);

    Modifies the data of given group.
    Returns an error message if operation failed or empty string otherwise.

$error = GroupMemberAdd ($config_hash, $user_hash);

    Adds a new member (user) to the given group.
    Returns an error message if operation failed or empty string otherwise.

$error = GroupMemberDelete ($config_hash, $user_hash);

    Removes a member from the given group.
    Returns an error message if operation failed or empty string otherwise.

$error = GroupDelete ($config_hash);

    Deletes an existing group.
    Returns an error message if operation failed or empty string otherwise.

$data_hash = GroupGet ($config_hash);

    Returns data hash decribing group.

$groups_hash = GroupsGet ($config_hash);

    Returns hash of groups. The resulting set is defined in $config hash.

$groups_hash = GroupsGetByUser ($config_hash, $user_hash);

    Returns hash of groups given user is member of.
    The resulting set is defined in $config hash.


=head1 DESCRIPTION

=over 2

=cut

package YaPI::USERS;

use strict;
use YaST::YCP qw(Boolean);
use ycp;

# ------------------- imported modules
YaST::YCP::Import ("Ldap");
YaST::YCP::Import ("Users");
YaST::YCP::Import ("UsersLDAP");
# -------------------------------------

our %TYPEINFO;

# internal function - FIXME should go to some other file...
sub InitializeConfiguration {

    my $config = $_[0];

    if (defined $config->{"bind_dn"}) {
	Ldap->bind_dn ($config->{"bind_dn"});
    }
    if (defined $config->{"bind_pw"}) {
	Ldap->SetBindPassword ($config->{"bind_pw"});
    }
    if (defined $config->{"anonymous_bind"}) {
	Ldap->SetAnonymous ($config->{"anonymous_bind"});
    }
    if (defined $config->{"member_attribute"}) {
	Ldap->member_attribute ($config->{"member_attribute"});
    }

    if (defined $config->{"user_attributes"} &&
	ref ($config->{"user_attributes"}) eq "ARRAY") {
	UsersLDAP->SetUserAttributes ($config->{"user_attributes"});
    }
    if (defined $config->{"user_filter"}) {
	UsersLDAP->SetCurrentUserFilter ($config->{"user_filter"});
    }
    if (defined $config->{"user_base"}) {
	UsersLDAP->SetUserBase ($config->{"user_base"});
    }
    if (defined $config->{"user_scope"}) {
	UsersLDAP->SetUserScope ($config->{"user_scope"});
    }
    
    if (defined $config->{"group_attributes"} &&
	ref ($config->{"group_attributes"}) eq "ARRAY") {
	UsersLDAP->SetGrooupAttributes ($config->{"group_attributes"});
    }
    if (defined $config->{"group_base"}) {
	UsersLDAP->SetGroupBase ($config->{"group_base"});
    }
    if (defined $config->{"group_filter"}) {
	UsersLDAP->SetCurrentGroupFilter ($config->{"group_filter"});
    }
    if (defined $config->{"group_scope"}) {
	UsersLDAP->SetGroupScope ($config->{"group_scope"});
    }

    if (defined $config->{"plugins"} && ref ($config->{"plugins"}) eq "ARRAY") {
	UsersLDAP->SetUserPlugins ($config->{"plugins"});
    }
    if (defined $config->{"user_plugins"} &&
	ref ($config->{"user_plugins"}) eq "ARRAY") {
	UsersLDAP->SetUserPlugins ($config->{"user_plugins"});
    }
    if (defined $config->{"group_plugins"} &&
	ref ($config->{"group_plugins"}) eq "ARRAY") {
	UsersLDAP->SetGroupPlugins ($config->{"group_plugins"});
    }
    # ...

}

# helper function
# create the minimal set of user attributes we want to read from LDAP
sub SetNecessaryUserAttributes {

    my $more		= shift;
    my @necessary	=
	("uid", "uidnumber", "objectclass", UsersLDAP->GetUserNamingAttr ());
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
	("cn", "gidnumber", "objectclass", UsersLDAP->GetGroupNamingAttr ());
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
C<$error UserAdd ($config_hash, $data_hash);>

Creates new user. User attributes are described in $data_hash,
$config_hash describes special configuration data.

Returns an error message if operation failed or empty string otherwise.

EXAMPLE:

  my $config	= { "type"		=> "ldap",
		    "plugins"		=> [ "UsersPluginsLDAPAll" ],
		    "bind_dn"		=> "uid=admin,dc=example,dc=com",
  };
  my $data	= { "uid"		=> "ll",
		    "uidnumber"		=> 1111,
		    "userpassword"	=> "qqqqq"
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
	"password"	=> "userpassword",
	"home"		=> "homedirectory",
	"shell"		=> "loginshell",
	"fullname"	=> "cn",
	"gid"		=> "gidnumber",
	"groups"	=> "grouplist"
    };
    foreach my $key (keys %{$data}) {
	my $new_key	= $key;
	if (defined $new_keys->{$key}) {
 	    $key	= $new_keys->{$key};
	}
	my $value	= $data->{$key};
	# TODO check correctly boolean values... ("create_home", "encrypted")
	$user->{$new_key}	= $value;
    }

    Users->SetGUI (0);

    $ret = Users->Read ();
    if ($ret ne "") { return $ret; }

    # config map could contain: user type, plugins to use, ... (?)
    # before we read LDAP, we could find here e.g. bind password
    InitializeConfiguration ($config);

    my $type	= $config->{"type"} || "local";
    if ($type eq "ldap") {
	# this initializes LDAP with the default values and read the
	$ret	= UsersLDAP->ReadSettings ();
	if ($ret ne "") { return $ret; }

	# now rewrite default values with given values
	InitializeConfiguration ($config);

	SetNecessaryUserAttributes (["homedirectory"]);
	# finally read LDAP tree
	$ret	= Users->ReadLDAPSet ();
	if ($ret ne "") { return $ret; }
    }
    $user->{"type"}	= $type;

    Users->ResetCurrentUser ();
    
    Users->AddUser ($user);

    if ($type eq "ldap") {
	Users->SubstituteUserValues ();
    }
	
    $ret = Users->CheckUser ({});
    if ($ret ne "") {
	return $ret;
    }
    Users->CommitUser ();
    $ret = Users->Write ();
    return $ret;
}

=item *
C<$error UserModify ($config_hash, $data_hash);>

Modifies existing user. User attributes which should be changed
are described in $data_hash,
$config_hash describes special configuration data, especially user
identification.

Returns an error message if operation failed or empty string otherwise.

EXAMPLE:

  my $config	= { "type"		=> "ldap",
		    "uidnumber"		=> 500
  };
  my $data	= { "userpassword"	=> "wwwww"
  };
  # changes a password of LDAP user (identified with id)
  my $error	= UserModify ($config, $data);

  # change GID value of local user (identified with name)
  $error	= UserModify ({ "uid" => "hh" }, { "gidnumber" => 5555 });

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

    if ($type eq "ldap") {
	Users->SetReadLocal (0);
    }
    $error = Users->Read ();
    if ($error ne "") { return $error; }

    # config map could contain: user type, plugins to use, ... (?)
    # before we read LDAP, we could find here e.g. bind password
    InitializeConfiguration ($config);

    # 1. select user

    my $key	= "";
    if (defined $config->{"dn"} && $type eq "ldap") {
	$key	= "dn";
    }
    elsif (defined $config->{"uid"}) {
	$key	= "uid";
    }
    elsif (defined $config->{"uidnumber"}) {
	$key	= "uidnumber";
    }

    if ($type eq "ldap") {
	# this initializes LDAP with the default values and read the
	$error	= UsersLDAP->ReadSettings ();
	if ($error ne "") { return $error; }

	# now rewrite default values with given values
	InitializeConfiguration ($config);

	# If we want to change atributes, that should be unique
	# (uid/dn/uidnumber/home we must read everything to check
	# possible conflicts...
	my $read_all	= 0;
	if (defined $data->{"uid"} || defined $data->{"uidnumber"}) {
	    $read_all	= 1;
	}

	# search with proper filter (= one DN/uid/uidnumber)
	# should be sufficient in this case...
	if ($key eq "dn" && !$read_all) {
	    UsersLDAP->SetUserBase ($config->{$key});
	}
	elsif (!defined $config->{"user_filter"} && $key ne "" && !$read_all) {
	    my $filter	= "$key=".$config->{$key};
	    UsersLDAP->AddToCurrentUserFilter ($filter);
	}
	# Let's create the minimal list of neccessary attributes to get
	if (defined $data->{"homedirectory"}) {
	    # we must check possible directory conflicts...
	    SetNecessaryUserAttributes (["homedirectory"]);
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

    if ($key eq "uidnumber") {
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

    if (Users->EditUser ($data)) {
	$error = Users->CheckUser ({});
	if ($error eq "" && Users->CommitUser ()) {
	    $error = Users->Write ();
	}
    }
    else {
	# this text is surely somewhere...
	$error	= _("There is no such user.");
    }
	
    return $error;
}

=item *
C<$error UserFeatureAdd ($config_hash);>

Adds a new feature (plugin) to the given user.

Returns an error message if operation failed or empty string otherwise.

EXAMPLE:

  my $config	= { "type"		=> "ldap",
		    "plugins"		=> [ "UsersPluginsSambaAccount" ],
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

    if (!defined $config->{"plugins"} || ref ($config->{"plugins"}) ne "ARRAY"){
	return "no plugin defined";
    }
#FIXME 'plugins' should be merged with existing list ...
# not working currently...
    return $self->UserModify ($config, { "plugins" => $config->{"plugins"} });
}

=item *
C<$error UserFeatureDelete ($config_hash);>

Deletes a new feature (plugin) to the given user.

Returns an error message if operation failed or empty string otherwise.

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

    if (!defined $config->{"plugins"} || ref ($config->{"plugins"}) ne "ARRAY"){
	return "no plugin defined";
    }
    my @plugins_to_remove	= @{$config->{"plugins"}};

    return 
    $self->UserModify ($config, { "plugins_to_remove" => \@plugins_to_remove });
}


=item *
C<$error UserDelete ($config_hash);>

Deletes existing user. Identification of user selected for delete is
stored in $config_hash.

Returns an error message if operation failed or empty string otherwise.

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

    if ($type eq "ldap") {
	Users->SetReadLocal (0);
    }
    $error = Users->Read ();
    if ($error ne "") { return $error; }

    # config map could contain: user type, plugins to use, ... (?)
    # before we read LDAP, we could find here e.g. bind password
    InitializeConfiguration ($config);

    my $key	= "";
    if (defined $config->{"dn"} && $type eq "ldap") {
	$key	= "dn";
    }
    elsif (defined $config->{"uid"}) {
	$key	= "uid";
    }
    elsif (defined $config->{"uidnumber"}) {
	$key	= "uidnumber";
    }

    if ($type eq "ldap") {
	# this initializes LDAP with the default values and read the
	$error	= UsersLDAP->ReadSettings ();
	if ($error ne "") { return $error; }

	# now rewrite default values with given values
	InitializeConfiguration ($config);

	# search with proper filter (= one DN/uid/uidnumber)
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
	return _("It is not possible to delete a NIS user.");
    }

    if ($key eq "uidnumber") {
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
	$error 	= _("There is no such user.");
    }
    return $error;
}

=item *
C<$error UserDisable ($config_hash);>

Disables existing user to log in. Identification of user selected for delete is
stored in $config_hash.

Returns an error message if operation failed or empty string otherwise.

EXAMPLE:

  my $config	= { "type"		=> "ldap",
		    "uidnumber"		=> 500,
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

    return $self->UserModify ($config, { "disabled" => YaST::YCP::Boolean (1)});
}

=item *
C<$error UserEnable ($config_hash);>

Enables existing user to log in. Identification of user selected for delete is
stored in $config_hash.

Returns an error message if operation failed or empty string otherwise.

EXAMPLE:

  my $config	= { "type"		=> "ldap",
		    "uidnumber"		=> 500,
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

    return $self->UserModify ($config, { "enabled" => YaST::YCP::Boolean (1)});
}

=item *
C<$data_hash UserGet ($config_hash);>

Returns a map describing selected user.

EXAMPLE:

  my $config	= { "type"		=> "ldap",
		    "user_attributes"	=> [ "uid", "uidnumber", "cn" ],
		    "uidnumber"		=> 500
  };
  # searches for LDAP user with uidnumber 500 and returns the hash with given
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

    if ($type eq "ldap") {
	Users->SetReadLocal (0);
    }
    $error = Users->Read ();
    if ($error ne "") { return $error; }

    # config map could contain: user type, plugins to use, ... (?)
    # before we read LDAP, we could find here e.g. bind password
    InitializeConfiguration ($config);

    my $key	= "";
    if (defined $config->{"dn"} && $type eq "ldap") {
	$key	= "dn";
    }
    elsif (defined $config->{"uid"}) {
	$key	= "uid";
    }
    elsif (defined $config->{"uidnumber"}) {
	$key	= "uidnumber";
    }

    if ($type eq "ldap") {
	# this initializes LDAP with the default values and read the
	$error	= UsersLDAP->ReadSettings ();
	if ($error ne "") { return $ret; }

	# now rewrite default values with given values
	InitializeConfiguration ($config);

	# search with proper filter (= one DN/uid/uidnumber)
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

    if ($key eq "uidnumber") {
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
    return $ret;
}

=item *
C<$users_hash UsersGet ($config_hash);>

Returns a hash describing the set of users. By default, the hash is indexed
by UID number, unless statet otherwise in $config_hash.

EXAMPLE:

  my $config	= { "type"		=> "ldap",
		    "user_attributes"	=> [ "uid", "uidnumber", "cn" ],
		    "user_base"		=> "ou=people,dc=example,dc=com",
		    "user_scope"	=> YaST::YCP::Integer (2),
		    "user_filter"	=> [ "objectclass=posixAccount" ]
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
    my $error	= "";

    Users->SetGUI (0);

    my $type	= $config->{"type"} || "local";

    if ($type eq "ldap") {
	Users->SetReadLocal (0);
    }
    $error = Users->Read ();
    if ($error ne "") { return $error; }

    # config map could contain: user type, plugins to use, ... (?)
    # before we read LDAP, we could find here e.g. bind password
    InitializeConfiguration ($config);
    if ($type eq "ldap") {
	# this initializes LDAP with the default values and read the
	$error	= UsersLDAP->ReadSettings ();
	if ($error ne "") { return $ret; }

	# now rewrite default values with given values
	InitializeConfiguration ($config);

	# finally read LDAP tree contents
	# -- should be also filtered by InitializeConfiguration!
	$error	= Users->ReadLDAPSet ();
	if ($error ne "") { return $ret; }
	# TODO should be only 'ldapsearch', not ReadLDAPSet (it creates some
	# internal keys, which shouldn't be neccessary
    }
    elsif ($type eq "nis") {
	Users->ReadNewSet ($type);
    }
	
    my $index		= $config->{"index"} || "uidnumber";

    return Users->GetUsers ($index, $type);
}

=item *
C<$error GroupAdd ($config_hash, $data_hash);>

Creates new group. Group attributes are described in $data_hash,
$config_hash describes special configuration data.

Returns an error message if operation failed or empty string otherwise.

EXAMPLE:

  my $config	= { "type"		=> "ldap",
		    "plugins"		=> [ "GroupsPluginsLDAPAll" ],
		    "bind_dn"		=> "uid=admin,dc=example,dc=com",
		    "group_base"	=> "ou=groups,dc=example,dc=com"
  };
  my $data	= { "gidnumber"		=> 5555,
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
    my $ret	= "";

    Users->SetGUI (0);

    my $type	= $config->{"type"} || "local";

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
#FIXME
    return $ret;
}

=item *
C<$error GroupModify ($config_hash, $data_hash);>

Modifies existing group. Group attributes which should be changed
are described in $data_hash,
$config_hash describes special configuration data, especially group
identification.

Returns an error message if operation failed or empty string otherwise.

EXAMPLE

  # change GID value of local group (identified with name)
  my $error	= GroupModify ({ "cn" => "users" }, { "gidnumber" => 101 });

  my $config	= { "type"		=> "ldap",
		    "gidnumber"		=> 5555
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

    # config map could contain: group type, plugins to use, ... (?)
    # before we read LDAP, we could find here e.g. bind password
    InitializeConfiguration ($config);

    # 1. select group
    my $key	= "";
    if (defined $config->{"dn"} && $type eq "ldap") {
	$key	= "dn";
    }
    elsif (defined $config->{"cn"}) {
	$key	= "cn";
    }
    elsif (defined $config->{"gidnumber"}) {
	$key	= "gidnumber";
    }

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
	# this initializes LDAP with the default values and read the
	$error	= UsersLDAP->ReadSettings ();
	if ($error ne "") { return $error; }

	# now rewrite default values with given values
	InitializeConfiguration ($config);

	# If we want to atributes, that should be unique
	# (cn/dn/gidnumber/memebr we must read everything to check
	# possible conflicts...
	my $read_all	= 0;
	if (defined $data->{"cn"} || defined $data->{"gidnumber"} ||
	    defined $data->{$member_attr}) {
	    $read_all	= 1;
	}

	# search with proper filter (= one DN/uid/uidnumber)
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
	# (gidnumber is changed) <-> (user modification necessary)
	if (!defined $data->{"gidnumber"}) {
	    # -> so we don't need to read any user now...
	    UsersLDAP->SetCurrentUserFilter ("0=1");
	}
	SetNecessaryUserAttributes (["gidnumber"]);
	# ----------
	
	$error	= Users->ReadLDAPSet ();
	if ($error ne "") { return $error; }
    }
    elsif ($type eq "nis") {
	Users->ReadNewSet ($type);#FIXME not possible
    }

    if ($key eq "gidnumber") {
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

    if (Users->EditGroup ($data)) {
	$error = Users->CheckGroup ({});
	if ($error eq "" && Users->CommitGroup ()) {
	    $error = Users->Write ();
	}
    }
    else {
	# error message
	$error	= _("There is no such group.");
    }
    return $error;
}

=item *
C<$error GroupMemberAdd ($config_hash, $user_hash);>

Adds a new member to the given group. User is described in $user_hash,
group identification is passwd in $config_hash.

Returns an error message if operation failed or empty string otherwise.

EXAMPLE:

  my $config	= { "type"		=> "ldap",
		    "plugins"		=> [ "UsersPluginSambaAccount" ],
		    "bind_dn"		=> "uid=admin,dc=example,dc=com",
		    "gidnumber"		=> 5555
  };
  my $user	= { "uid"		=> "my_user",
		    "gecos"		=> [ "My new user in group 5555" ]
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
# FIXME
# 1. find the user
# 2. if exists, get his DN and call GroupModify
# (but 'member' must be merged, not rewritten
    return "";
}

=item *
C<$error GroupMemberDelete ($config_hash, $user_hash);>

Deletes a member from the group.

Returns an error message if operation failed or empty string otherwise.

EXAMPLE:

  my $config	= { "type"		=> "ldap",
		    "dn"		=> "cn=lgroup,dc=example,dc=com"
  };
  my $user	= { "uidnumber"		=> 1000 }

  # removes user with given uidnumber from group with given DN
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
	return _("No user specified.");
#TODO maybe user is specfied by filter...
    }
    
    my $type	= $config->{"type"} || "local";

    if ($type eq "ldap") {
	Users->SetReadLocal (0);
    }
    $error = Users->Read ();
    if ($error ne "") { return $error; }

    # config map could contain: user type, plugins to use, ... (?)
    # before we read LDAP, we could find here e.g. bind password
    InitializeConfiguration ($config);

    my $key	= "";
    if (defined $config->{"dn"} && $type eq "ldap") {
	$key	= "dn";
    }
    elsif (defined $config->{"cn"}) {
	$key	= "cn";
    }
    elsif (defined $config->{"gidnumber"}) {
	$key	= "gidnumber";
    }

    if ($type eq "ldap") {
	# this initializes LDAP with the default values and read the
	$error	= UsersLDAP->ReadSettings ();
	if ($error ne "") { return $error; }

	# now rewrite default values with given values
	InitializeConfiguration ($config);

	# search with proper filter (= one DN/uid/uidnumber)
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
	return _("It is not possible to modify a NIS group.");
    }

    if ($key eq "gidnumber") {
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
	return _("There is no such group.");
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
	elsif (defined $user->{"uidnumber"}) {
	    $usermap	= Users->GetUser ($user->{"uidnumber"}, $type);
	}
	if ($type eq "ldap") {
	    $user_id	= $usermap->{"dn"};
	    # TODO maybe there is ony one user loaded, but not specified by
	    # uid/uidnumber/dn... ->GetUserByAttribute...
	}
	else {
	    $user_id	= $usermap->{"uid"};
	}
    }
    if (!defined $user_id) {
	return _("User was not correctly specified.");
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
    if (Users->EditGroup ($data)) {
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

    if ($type eq "ldap") {
	Users->SetReadLocal (0);
    }
    $error = Users->Read ();
    if ($error ne "") { return $error; }

    # config map could contain: user type, plugins to use, ... (?)
    # before we read LDAP, we could find here e.g. bind password
    InitializeConfiguration ($config);

    my $key	= "";
    if (defined $config->{"dn"} && $type eq "ldap") {
	$key	= "dn";
    }
    elsif (defined $config->{"cn"}) {
	$key	= "cn";
    }
    elsif (defined $config->{"gidnumber"}) {
	$key	= "gidnumber";
    }
    
    if ($type eq "ldap") {
	# this initializes LDAP with the default values and read the
	$error	= UsersLDAP->ReadSettings ();
	if ($error ne "") { return $error; }

	# now rewrite default values with given values
	InitializeConfiguration ($config);

	# search with proper filter (= one DN/uid/uidnumber)
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
	if (defined $config->{"gidnumber"}) {
	    my $filter = "gidnumber=".$config->{"gidnumber"};
	    UsersLDAP->AddToCurrentUserFilter ($filter);
	    # TODO read gidnumber by ldapsearch if not given
	}
	SetNecessaryUserAttributes (["gidnumber"]);

	$error	= Users->ReadLDAPSet ();
	if ($error ne "") { return $error; }
    }
    elsif ($type eq "nis") {
	# error message
	return _("It is not possible to delete a NIS group.");
    }

    if ($key eq "gidnumber") {
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
	$error 	= _("There is no such group.");
    }
    return $error;
}

=item *
C<$data_hash GroupGet ($config_hash);>

Returns a map describing selected group.

EXAMPLE:

  my $config	= { "type"		=> "ldap",
		    "group_attributes"	=> [ "cn", "gidnumber", "member" ],
		    "gidnumber"		=> 500
  };
  # searches for LDAP group with gidnumber 500 and returns the hash
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

    if ($type eq "ldap") {
	Users->SetReadLocal (0);
    }
    $error = Users->Read ();
    if ($error ne "") { return $error; }

    # config map could contain: user type, plugins to use, ... (?)
    # before we read LDAP, we could find here e.g. bind password
    InitializeConfiguration ($config);

    my $key	= "";
    if (defined $config->{"dn"} && $type eq "ldap") {
	$key	= "dn";
    }
    elsif (defined $config->{"cn"}) {
	$key	= "cn";
    }
    elsif (defined $config->{"gidnumber"}) {
	$key	= "gidnumber";
    }

    if ($type eq "ldap") {
	# this initializes LDAP with the default values and read the
	$error	= UsersLDAP->ReadSettings ();
	if ($error ne "") { return $ret; }

	# now rewrite default values with given values
	InitializeConfiguration ($config);

	# search with proper filter (= one DN/uid/uidnumber)
	# should be sufficient in this case...
	if ($key eq "dn") {
	    UsersLDAP->SetGroupBase ($config->{$key});
	}
	elsif (!defined $config->{"group_filter"} && $key ne "") {
	    my $filter = "$key=".$config->{$key};
	    UsersLDAP->AddToCurrentGroupFilter ($filter);
	}
	# read only users 'affected' by our group number
	if (defined $config->{"gidnumber"}) {
	    my $filter = "gidnumber=".$config->{"gidnumber"};
	    UsersLDAP->AddToCurrentUserFilter ($filter);
	    # TODO read gidnumber by ldapsearch if not given
	}
	else {
	    # we don't need any users -> fake filter for faster searching
	    UsersLDAP->SetCurrentUserFilter ("0=1");
	}
	SetNecessaryUserAttributes (["gidnumber"]);

	$error	= Users->ReadLDAPSet ();
	if ($error ne "") { return $ret; }
    }
    elsif ($type eq "nis") {
	Users->ReadNewSet ($type);
    }

    if ($key eq "gidnumber") {
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

    return $ret;
}

=item *
C<$groups_hash GroupsGetByUser ($config_hash, $user_hash);>

Returns a hash describing the set of groups. By default, the hash is indexed
by GID number, unless statet otherwise in $config_hash.

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
    my $config	= $_[0];
    my $ret	= {};

    return $ret;
}

42;
