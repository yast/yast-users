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

##------------------------------------
##------------------- global imports

YaST::YCP::Import ("UsersLDAP");

##------------------------------------

# All functions have 2 "any" parameters: this will probably mean
# 1st: configuration map (hash) - e.g. saying if we work with user or group
# 2nd: data map (hash) of user (group) to work with


# return names of provided functions
BEGIN { $TYPEINFO{Interface} = ["function", ["list", "string"], "any", "any"];}
sub Interface {

    return (
	    "GUIClient",
	    "Check",
	    "Name",
	    "Summary",
	    "Restriction",
	    "WriteBefore",
	    "Write"
    );
}

# return plugin name, used for GUI (translated)
BEGIN { $TYPEINFO{Name} = ["function", "string", "any", "any"];}
sub Name {

    # plugin name
    return _("LDAP Attributes");
}

# return plugin summary
BEGIN { $TYPEINFO{Summary} = ["function", "string", "any", "any"];}
sub Summary {

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

    return "users_plugin_ldap_all";
}

##------------------------------------
# Type of users and groups this plugin is restricted to.
# If this function doesn't exist, plugin is applied for all user (group) types.
BEGIN { $TYPEINFO{Restriction} = ["function",
    ["map", "string", "any"], "any", "any"];}
sub Restriction {

    return { "ldap"	=> 1 };
}


##------------------------------------
# check if all required atributes of LDAP entry are present
# parameter is (whole) map of entry (user/group)
# return error message
BEGIN { $TYPEINFO{Check} = ["function",
    "string",
#    ["map", "string", "any"]];
    "any",
    "any"];
}
sub Check {

    my $config	= $_[0];
    my $data	= $_[1];
    my $what	= "user";
    
    if (defined $config->{"what"}) {
	$what	= $config->{"what"};
    }
    
    # attribute conversion
    my $ldap2yast_attrs		= UsersLDAP::GetUserAttrsLDAP2YaST ();
    my @required_attrs		= UsersLDAP::GetUserRequiredAttributes ();
    if ($what eq "group") {
	$ldap2yast_attrs	= UsersLDAP::GetGroupAttrsLDAP2YaST ();
	@required_attrs		= UsersLDAP::GetGroupRequiredAttributes ();
    }

# TODO required attributes should be checked against current objectClass
    foreach my $req (@required_attrs) {
	my $a	= $ldap2yast_attrs->{$req} || $req;
	my $val	= $data->{$a};
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

# ???
# fill the map and return new one?
BEGIN { $TYPEINFO{Edit} = ["function", ["map", "string", "any"], "any", "any"];}
sub Edit {

    # TODO should it be called at the beggining or at the end of Users::Edit?
    y2internal ("Edit LDAPAll called");
    return;
}

BEGIN { $TYPEINFO{Add} = ["function", ["map", "string", "any"], "any", "any"];}
sub Add {

    # TODO should it be called at the beggining or at the end of Users::Edit?
    # add some goud defaults...
    y2internal ("Add LDAPAll called");
    return;
}



# what should be done before user is finally written to LDAP
BEGIN { $TYPEINFO{WriteBefore} = ["function", "boolean", "any", "any"];}
sub WriteBefore {

    y2internal ("WriteBefore LDAPAll called");
    return;
}

# what should be done after user is finally written to LDAP
BEGIN { $TYPEINFO{Write} = ["function", "boolean", "any", "any"];}
sub Write {

    y2internal ("Write LDAPAll called");
    return;
}
1
# EOF
