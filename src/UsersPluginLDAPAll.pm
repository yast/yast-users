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
textdomain("users");	# TODO own textdomain for new plugins

##--------------------------------------
##--------------------- global imports

YaST::YCP::Import ("SCR");

##--------------------------------------
##--------------------- global variables

# default object classes of LDAP users
my @user_object_class                  =
    ("top","posixAccount","shadowAccount", "inetOrgPerson");

# default object classes of LDAP groups
my @group_object_class                 =
    ( "top", "posixGroup", "groupOfNames");


##--------------------------------------

# All functions have 2 "any" parameters: this will probably mean
# 1st: configuration map (hash) - e.g. saying if we work with user or group
# 2nd: data map (hash) of user (group) to work with

# in 'config' map there is a info of this type:
# "what"		=> "user" / "group"
# "modified"		=> "added"/"edited"/"deleted"
# "enabled"		=> 1/ key not present
# "disabled"		=> 1/ key not present

# 'data' map contains the atrtributes of the user. It could also contain
# some keys, which Users module uses internaly (like 'groupname' for name of
# user's default group). Just ignore these values
    
##------------------------------------

# TODO check for Mode::config???
 

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
	    "Disable"
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


# return name of YCP client defining YCP GUI
BEGIN { $TYPEINFO{GUIClient} = ["function", "string", "any", "any"];}
sub GUIClient {

    my $self	= shift;
    return "users_plugin_ldap_all";
}

##------------------------------------
# Type of users and groups this plugin is restricted to.
# If this function doesn't exist, plugin is applied for all user (group) types.
BEGIN { $TYPEINFO{Restriction} = ["function",
    ["map", "string", "any"], "any", "any"];}
sub Restriction {

    my $self	= shift;
    # this plugin applies only for LDAP users and groups
    return { "ldap"	=> 1 };
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
    if (defined $data->{"objectClass"} && ref ($data->{"objectClass"}) eq "ARRAY") {
	@object_classes		= @{$data->{"objectClass"}};
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
	my $val	= $data->{$req};
	if (!defined $val || $val eq "" || 
	    (ref ($val) eq "ARRAY" && 
		((@{$val} == 0) || (@{$val} == 1 && $val->[0] eq "")))) {
	    # error popup (user forgot to fill in some attributes)
	    return sprintf (_("The attribute '%s' is required for this object according
to its LDAP configuration, but it is currently empty."), $req);
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

    my $list = $_[0];
    my $item = $_[1];

    if (!defined $list || ref ($list) ne "ARRAY") {
	return 0;
    }
    return grep (/^$item$/, @{$list} );
}

sub update_object_classes {

    my $config	= $_[0];
    my $data	= $_[1];

    # define the object class for new user/groupa
    my @orig_object_class	= ();
    if (defined $data->{"objectClass"} && ref $data->{"objectClass"} eq "ARRAY")
    {
	@orig_object_class	= @{$data->{"objectClass"}};
    }
    my @ocs			= @user_object_class;
    if (($config->{"what"} || "") eq "group") {
	@ocs			= @group_object_class;
    }
    foreach my $oc (@ocs) {
	if (!contains (\@orig_object_class, $oc)) {
	    push @orig_object_class, $oc;
	}
    }

    $data->{"objectClass"}	= \@orig_object_class;

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
    my $data	= $_[1];

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
    my $data	= $_[1];

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
    my $data	= $_[1];

    $data	= update_object_classes ($config, $data);

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
    my $data	= $_[1];

    y2internal ("Edit LDAPAll called");
    return $data;
}



# what should be done before user is finally written to LDAP
BEGIN { $TYPEINFO{WriteBefore} = ["function", "boolean", "any", "any"];}
sub WriteBefore {

    my $self	= shift;
    my $config	= $_[0];
    my $data	= $_[1];

    # this means what was done with a user: added/edited/deleted
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
