#! /usr/bin/perl -w
#
# Example of plugin module
# This is the API part of UsersPluginLDAPAll plugin - configuration of
# all user/group LDAP attributes
#

package UsersPluginLDAPAll;

use strict;

use ycp;
use YaST::YCP;

our %TYPEINFO;

use Locale::gettext;
use POSIX ();

POSIX::setlocale(LC_MESSAGES, "");
textdomain("users");

##--------------------------------------
##--------------------- global imports

YaST::YCP::Import ("SCR");

##--------------------------------------
##--------------------- global variables

# default object classes of LDAP users
my @user_object_class                  =
    ("top","posixaccount","shadowaccount", "inetorgperson");

# default object classes of LDAP groups
my @group_object_class                 =
    ( "top", "posixgroup", "groupofnames");


##--------------------------------------

# All functions have 2 "any" parameters: this will probably mean
# 1st: configuration map (hash) - e.g. saying if we work with user or group
# 2nd: data map (hash) of user (group) to work with

# in 'config' map there is a info of this type:
# "what"		=> "user" / "group"
# "modified"		=> "added"/"edited"/"deleted"
# "enabled"		=> 1/ key not present
# "disabled"		=> 1/ key not present
# "plugins_to_remove"	=> list of plugins which has to be removed 

# 'data' map contains the atrtributes of the user. It could also contain
# some keys, which Users module uses internaly (like 'groupname' for name of
# user's default group). Just ignore these values
    
##------------------------------------


# return names of provided functions
BEGIN { $TYPEINFO{Interface} = ["function", ["list", "string"], "any", "any"];}
sub Interface {

    my $self		= shift;
    my @interface 	= (
	    "GUIClient",
	    "Check",
	    "Name",
	    "Summary",
	    "Restriction",
	    "WriteBefore",
	    "Write",
	    "AddBefore",
	    "Add",
	    "EditBefore",
	    "Edit",
	    "Interface",
	    "Disable",
	    "PluginPresent",
#	    "InternalAttributes",
    );
    return \@interface;
}

# return plugin name, used for GUI (translated)
BEGIN { $TYPEINFO{Name} = ["function", "string", "any", "any"];}
sub Name {

    my $self		= shift;
    # plugin name
    return _("LDAP Attributes");
}

# return plugin summary
BEGIN { $TYPEINFO{Summary} = ["function", "string", "any", "any"];}
sub Summary {

    my $self	= shift;
    my $what	= "user";
    # summary
    my $ret 	= _("Edit remaining attributes of LDAP user");

    if (defined $_[0]->{"what"} && $_[0]->{"what"} eq "group") {
	$ret 	= _("Edit remaining attributes of LDAP group");
    }
    return $ret;
}

# return plugin internal attributes (which shouldn't be shown to user)
BEGIN { $TYPEINFO{InternalAttributes} = ["function",
    [ "list", "string" ], "any", "any"];
}
sub InternalAttributes {

    my $self	= shift;
    my @ret 	= ();

    if (defined $_[0]->{"what"} && $_[0]->{"what"} eq "group") {
	@ret 	= ();
    }
    return \@ret;
}

# checks the current data map of user/group (2nd parameter) and returns
# true if given user (group) has our plugin
BEGIN { $TYPEINFO{PluginPresent} = ["function", "boolean", "any", "any"];}
sub PluginPresent {

    my $self	= shift;

    # Yes, all LDAP users/groups have this plugin as default
    # (and this plugin is used only for LDAP objects, see Restriction function)
    return 1;
}



# return name of YCP client defining YCP GUI
BEGIN { $TYPEINFO{GUIClient} = ["function", "string", "any", "any"];}
sub GUIClient {

    my $self	= shift;
    return "users_plugin_ldap_all";
}

##------------------------------------
# Type of objects this plugin is restricted to.
# It defines:
#	1. type of objects which it should be applied to (ldap/nis/local/system)
#	2. type of objects at all (user/group)
# If this function doesn't exist, plugin is applied for all users of all types
BEGIN { $TYPEINFO{Restriction} = ["function",
    ["map", "string", "any"], "any", "any"];}
sub Restriction {

    my $self	= shift;
    return {
	    # This plugin applies only for LDAP entries,
	    "ldap"	=> 1,
	    # both for users and groups:
	    "user"	=> 1,
	    "group"	=> 1
    };
}


##------------------------------------
# check if all required atributes of LDAP entry are present
# parameter is (whole) map of entry (user/group)
# return error message
BEGIN { $TYPEINFO{Check} = ["function",
    "string",
    "any",
    "any"];
}
sub Check {

    my $self	= shift;
    my $config	= $_[0];
    my $data	= $_[1];
    
    # attribute conversion
    my @required_attrs		= ();
    my @object_classes		= ();
    if (defined $data->{"objectclass"} && ref ($data->{"objectclass"}) eq "ARRAY") {
	@object_classes		= @{$data->{"objectclass"}};
    }

    # get the attributes required for entry's object classes
    foreach my $class (@object_classes) {
	my $object_class = SCR->Read (".ldap.schema.oc", {"name"=> $class});
	if (!defined $object_class || ref ($object_class) ne "HASH" ||
	    ! %{$object_class}) { next; }
	my $req = $object_class->{"must"};
	if (defined $req && ref ($req) eq "ARRAY") {
	    foreach my $r (@{$req}) {
		push @required_attrs, $r;
	    }
	}
    }

    # check the presence of required attributes
    foreach my $req (@required_attrs) {
	my $attr	= lc ($req);
	my $val		= $data->{$attr};
	if (!defined $val || $val eq "" || 
	    (ref ($val) eq "ARRAY" && 
		((@{$val} == 0) || (@{$val} == 1 && $val->[0] eq "")))) {
	    # error popup (user forgot to fill in some attributes)
	    return sprintf (_("The attribute '%s' is required for this object according
to its LDAP configuration, but it is currently empty."), $attr);
	}
    }
    return "";
}

# this will be called at the beggining of Users::Edit
BEGIN { $TYPEINFO{Disable} = ["function",
    ["map", "string", "any"],
    "any", "any"];
}
sub Disable {

    my $self	= shift;
    my $config	= $_[0];
    my $data	= $_[1];

    y2internal ("Disable LDAPAll called");
    return $data;
}


sub contains {
    my ( $list, $key, $ignorecase ) = @_;
    if ( $ignorecase ) {
        if ( grep /^$key$/i, @{$list} ) {
            return 1;
        }
    } else {
        if ( grep /^$key$/, @{$list} ) {
            return 1;
        }
    }
    return 0;
}

sub update_object_classes {

    my $config	= $_[0];
    my $data	= $_[1];

    # define the object class for new user/groupa
    my @orig_object_class	= ();
    if (defined $data->{"objectclass"} && ref $data->{"objectclass"} eq "ARRAY")
    {
	@orig_object_class	= @{$data->{"objectclass"}};
    }
    my @ocs			= @user_object_class;
    if (($config->{"what"} || "") eq "group") {
	@ocs			= @group_object_class;
    }
    foreach my $oc (@ocs) {
	if (!contains (\@orig_object_class, $oc, 1)) {
	    push @orig_object_class, $oc;
	}
    }

    $data->{"objectclass"}	= \@orig_object_class;

    return $data;
}

# this will be called at the beggining of Users::Add
# Could be called multiple times for one user/group!
BEGIN { $TYPEINFO{AddBefore} = ["function",
    ["map", "string", "any"],
    "any", "any"];
}
sub AddBefore {

    my $self	= shift;
    my $config	= $_[0];
    my $data	= $_[1]; # only new data that will be copied to current user map

    $data	= update_object_classes ($config, $data);

    y2internal ("AddBefore LDAPAll called");
    return $data;
}


# This will be called just after Users::Add - the data map probably contains
# the values which we could use to create new ones
# Could be called multiple times for one user/group!
BEGIN { $TYPEINFO{Add} = ["function", ["map", "string", "any"], "any", "any"];}
sub Add {

    my $self	= shift;
    my $config	= $_[0];
    my $data	= $_[1]; # the whole map of current user/group after Users::Edit
    y2internal ("Add LDAPAll called");
    return $data;
}

# this will be called at the beggining of Users::Edit
BEGIN { $TYPEINFO{EditBefore} = ["function",
    ["map", "string", "any"],
    "any", "any"];
}
sub EditBefore {

    my $self	= shift;
    my $config	= $_[0];
    my $data	= $_[1]; # only new data that will be copied to current user map
    # data of original user/group are saved as a submap of $config
    # data with key "org_data"

    # in $data hash, there could be "plugins_to_remove": list of plugins which
    # has to be removed from the user

    y2internal ("EditBefore LDAPAll called");
    return $data;
}

# this will be called just after Users::Edit
BEGIN { $TYPEINFO{Edit} = ["function",
    ["map", "string", "any"],
    "any", "any"];
}
sub Edit {

    my $self	= shift;
    my $config	= $_[0];
    my $data	= $_[1]; # the whole map of current user/group after Users::Edit

    # in $data hash, there could be "plugins_to_remove": list of plugins which
    # has to be removed from the user

    y2internal ("Edit LDAPAll called");
    return $data;
}



# what should be done before user is finally written to LDAP
BEGIN { $TYPEINFO{WriteBefore} = ["function", "boolean", "any", "any"];}
sub WriteBefore {

    my $self	= shift;
    my $config	= $_[0];
    my $data	= $_[1];

    # this means what was done with a user/group: added/edited/deleted
    my $action = $config->{"modified"} || "";
    
    y2internal ("WriteBefore LDAPAll called");
    return;
}

# what should be done after user is finally written to LDAP
BEGIN { $TYPEINFO{Write} = ["function", "boolean", "any", "any"];}
sub Write {

    my $self	= shift;
    my $config	= $_[0];
    my $data	= $_[1];

    # this means what was done with a user: added/edited/deleted
    my $action = $config->{"modified"} || "";
    y2internal ("Write LDAPAll called");
    return;
}
1
# EOF
