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

YaST::YCP::Import ("Users");

our %TYPEINFO;


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

return "";
    my %new_keys	= {
	"username"	=> "uid",
	"password"	=> "userPassword",
	"home"		=> "homeDirectory",
	"shell"		=> "loginShell",
	"fullname"	=> "cn",
	"gid"		=> "gidNumber",
#	"uid"		=> "uidNumber",#FIXME could conflict with other 'uid'!
	"groups"	=> "grouplist"
    };
    foreach my $key (keys %{$data}) {
	my $new_key	= $key;
	if (defined $new_keys->{$key}) {
 	    $key	= $new_keys->{$key};
	}
	my $value	= $data->{$key};
	# TODO check correctly boolean values... ("create_home", "encrypted")
#	if (new_key == "gidNumber")
#	{
#	    # TODO check group existence!
#	    if (!UsersCache::GIDExists (tointeger ((string)value)))
#		return;
#	}
	$user->{$new_key}	= $value;
    }

    # FIXME do not read local users if not necessary? (LDAP...)
    Users->Read ();

    # config map could contain: user type, plugins to use, ... (?)
    my $type	= $config->{"type"} || "local";
    if ($type eq "ldap") {
	# 1. init ldap agent
	# 2. read ldap users (not all!)
	# 3. set the values from config map
    }
    $user{"type"}	= $type;

    Users->AddUser ($user);

    my $ret = Users->CheckUser ({});
    if ($ret ne "") {
	return $ret;
    }
    Users->CommitUser ();
    if (!Users->Write ()) {
	y2internal ("error");
    }
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
    my $ret	= "";
    my $user	= {};

    #TODO
    return $ret;
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
    return "";
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
    return "";
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
    my $ret	= "";

    #TODO
    return $ret;
}

=item *
C<$error UserDisable ($config_hash);>

Disables existing user to log in. Identification of user selected for delete is
stored in $config_hash.

Returns an error message if operation failed or empty string otherwise.

EXAMPLE:

  my $config	= { "type"		=> "ldap",
		    "uidNumber"		=> 500,
		    "plugins"		=> [ "UsersPluginsSambaAccount" ]
  };
  # disables LDAP user (as it is defined in given plugin)
  my $error	= UserDisable ($config);

=cut

BEGIN{$TYPEINFO{UserDisable} = ["function",
    "string",
    [ "map", "string", "any" ]];
}
sub UserDisable {

    my $self	= shift;
    my $config	= $_[0];
    my $ret	= "";

    #TODO
    return $ret;
}

=item *
C<$error UserEnable ($config_hash);>

Enables existing user to log in. Identification of user selected for delete is
stored in $config_hash.

Returns an error message if operation failed or empty string otherwise.

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
    my $ret	= "";

    #TODO
    return $ret;
}

=item *
C<$data_hash UserGet ($config_hash);>

Returns a map describing selected user.

EXAMPLE:

  my $config	= { "type"		=> "ldap",
		    "attributes"	=> [ "uid", "uidNumber", "cn" ],
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

    return $ret;
}

=item *
C<$users_hash UsersGet ($config_hash);>

Returns a hash describing the set of users. By default, the hash is indexed
by UID number, unless statet otherwise in $config_hash.

EXAMPLE:

  my $config	= { "type"		=> "ldap",
		    "attributes"	=> [ "uid", "uidNumber", "cn" ],
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
    [ "map", "string", "any" ],
    [ "map", "string", "any" ]];
}
sub UsersGet {

    my $self	= shift;
    my $config	= $_[0];
    my $ret	= {};

    return $ret;
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
    my $group	= {};
    my $ret	= "";
    # TODO
    # TODO conver 'member' from list to hash if necessary
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
    my $ret	= "";
    my $group	= {};

    #TODO
    return $ret;
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
		    "gidNumber"		=> 5555
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
    return "";
}

=item *
C<$error GroupMemberDelete ($config_hash, $user_hash);>

Deletes a memebr from the group.

Returns an error message if operation failed or empty string otherwise.

EXAMPLE:

  my $config	= { "type"		=> "ldap",
		    "dn"		=> "cn=lgroup,dc=example,dc=com"
  };
  my $user	= { "uidNumber"		=> 1000 }

  # removes user with given uidNumber from group with given DN
  my $error	= GroupMemberDelete ($config, $data);

=cut

BEGIN{$TYPEINFO{GroupMemberDelete} = ["function",
    "string",
    [ "map", "string", "any" ]];
}
sub GroupMemberDelete {

    my $self	= shift;
    return "";
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
    my $ret	= "";

    #TODO
    return $ret;
}

=item *
C<$data_hash GroupGet ($config_hash);>

Returns a map describing selected group.

EXAMPLE:

  my $config	= { "type"		=> "ldap",
		    "attributes"	=> [ "cn", "gidNumber", "member" ],
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
