#! /usr/bin/perl -w
#
# UsersLDAP module:
# -- routines for handling LDAP users and groups
#

package UsersLDAP;

use strict;

use ycp;
use YaST::YCP qw(Boolean);

our %TYPEINFO;

# If YaST UI (Qt,ncurses) should be used
my $use_gui                     = 1;

# if LDAP user/group management is initialized
my $initialized 		= 0;

# DN saying where the user (group) configuration (defaults etc.) is stored
my $user_config_dn 		= "";
my $group_config_dn 		= "";

# configuration maps (stored on LDAP server)
my %user_config			= ();
my %group_config		= ();
my %user_template 		= ();
my %group_template 		= ();
my %user_defaults 		= ();
my %group_defaults 		= ();

# DN saying where are users (groups) located
my $user_base			= "";
my $group_base			= "";

# default filters for searching
my $default_user_filter		= "objectClass=posixAccount";
my $default_group_filter	= "objectClass=posixGroup";

# which attribute have groups for list of members
my $member_attribute		= "uniqueMember";

# current filters (must be empty on start):
my $user_filter 		= "";
my $group_filter 		= "";

# if filters were read (could be read without reading users and groups)
my $filters_read 		= 0;

# default shadow settings for LDAP users
my %shadow 			= ();

# other default settings (home, shell, etc.) for LDAP users
# (has the same structure as Users::useradd_defaults)
my %useradd_defaults		= ();

# some default values for LDAP users
my $default_groupname 		= "";
my $default_grouplist 		= "";

# password encryption for LDAP users
my $encryption			= "crypt";

# default object classes of LDAP users (read from Ldap module)
my @user_class 			=
    ("top","posixAccount","shadowAccount", "inetOrgPerson");

# default object classes of LDAP groups (read from Ldap module)
my @group_class 		=
    ( "top", "posixGroup", "groupOfUniqueNames");

# naming attrributes (to be used when creating DN)
my $user_naming_attr 		= "uid";
my $group_naming_attr 		= "cn";

# last uid/gid used
my $last_uid 			= 0;
my $last_gid 			= 0;

# max uid/gid allowed
my $max_uid 			= 60000;
my $max_gid 			= 60000;

# min uid/gid allowed
my $min_uid 			= 1000;
my $min_gid 			= 1000;

# user password lengt
my $min_pass_length		= 5;
my $max_pass_length		= 8;

# keys in user's map which are not saved anywhere, they are used for internal
# purposes only
my @user_internal_keys		=
    ("create_home", "grouplist", "groupname", "modified", "org_username",
     "org_uidNumber", "org_homeDirectory","org_user", "type", "org_groupname",
     "org_type", "what", "encrypted",
     "dn", "org_dn", "removed_grouplist", "delete_home", "addit_data");

my @group_internal_keys		=
    ("modified", "type", "more_users", "s_userlist", "encrypted", "org_type",
     "dn", "org_dn", "org_groupname", "org_gidNumber", "removed_userlist",
     "what");

# conversion table from parameter names used in yast (passwd-style) to
# correct LDAP schema atrributes
my %ldap_attrs_conversion	= (
    # user:
    "username"	=> "uid",
    # group:
    "groupname"	=> "cn"
);

# LDAP attrs -> yast inner values
my %ldap2yast_user_attrs	= (
    "uid"		=> "username"
);
    
my %ldap2yast_group_attrs	= (
    "cn"		=> "groupname"
);

# list of available plugin clients with features, enhabcing users module
my @available_plugins		= ();
 
##------------------------------------
##------------------- global imports

YaST::YCP::Import ("Ldap");
YaST::YCP::Import ("SCR");
YaST::YCP::Import ("UsersCache");
YaST::YCP::Import ("UsersPlugins");
YaST::YCP::Import ("UsersRoutines");
YaST::YCP::Import ("UsersUI");

##------------------------------------

sub contains {

    foreach my $key (@{$_[0]}) {
	if ($key eq $_[1]) { return 1; }
    }
    return 0;
}
##------------------------------------
# Checks if set of LDAP users is available
BEGIN { $TYPEINFO{ReadAvailable} = ["function", "boolean"];}
sub ReadAvailable {

    my $passwd_source = SCR::Read (".etc.nsswitch_conf.passwd");
    if (defined $passwd_source) {
	foreach my $source (split (/ /, $passwd_source)) {
	    if ($source eq "ldap") { return 1; }
	}
    }
    return 0;
}

##------------------------------------
# Checks if ldap server is set to localhost
# @param host adress of LDAP server
sub ReadServer {

    return ($_[0] eq "localhost" || $_[0] eq "127.0.0.1");
}

##------------------------------------
# Initializes LDAP connection and reads users and groups configuration
sub Initialize {

    Ldap::Read();
    Ldap::SetGUI ($use_gui);

    my $ldap_mesg = Ldap::LDAPInit ();
    if ($ldap_mesg ne "") {
	Ldap::LDAPErrorMessage ("init", $ldap_mesg);
	return 0;
    }
    if (!Ldap::anonymous () && !defined (Ldap::bind_pass ())) {
	y2error ("no password to LDAP - cannot bind!");
	return 0;
    }

    $ldap_mesg = Ldap::LDAPBind (Ldap::bind_pass ());
    if ($ldap_mesg ne "") {
	Ldap::LDAPErrorMessage ("init", $ldap_mesg);
	return 0;
    }
    $ldap_mesg = Ldap::InitSchema ();
    if ($ldap_mesg ne "") {
	Ldap::LDAPErrorMessage ("schema", $ldap_mesg);
	return 0;
    }

    $ldap_mesg = Ldap::ReadConfigModules ();
    if ($ldap_mesg ne "") {
	Ldap::LDAPErrorMessage ("read", $ldap_mesg);
	return 0;
    }

    my %modules = %{Ldap::GetConfigModules ()};
    while ( my ($dn, $config_module) = each %modules) {

	if (!defined $config_module->{"objectClass"}) {
	    next;
	}
	my $oc = $config_module->{"objectClass"};
	if (contains ($oc, "userConfiguration")) {
	    $user_config_dn	= $dn;
	    %user_config 	= %{$config_module};
	}
	if (contains ($oc, "groupConfiguration")) {
	    $group_config_dn	= $dn;
	    %group_config 	= %{$config_module};
	}
    };

    my @user_templates		= ();
    if (defined $user_config{"defaultTemplate"}) {
	@user_templates 	= @{$user_config{"defaultTemplate"}};
    }
    my @group_templates		= ();
    if (defined $group_config{"defaultTemplate"}) {
	@group_templates 	= @{$group_config{"defaultTemplate"}};
    }
    my $user_template_dn	= $user_templates[0] || "";
    my $group_template_dn	= $group_templates[0] || "";

    # read only one default template
    if ((@user_templates > 1 || @group_templates > 1) && $use_gui) {
	my %templ =
	    %{UsersUI::ChooseTemplates (\@user_templates, \@group_templates)};
	if (%templ) {
	    $user_template_dn	= $templ{"user"} || $user_template_dn;
	    $group_template_dn	= $templ{"group"} || $group_template_dn;
	}
    }
    %user_template = %{Ldap::ConvertDefaultValues (
	Ldap::GetLDAPEntry ($user_template_dn))};
    %group_template = %{Ldap::ConvertDefaultValues (
	Ldap::GetLDAPEntry ($group_template_dn))};

    $initialized = 1;
    return 1;
}


##------------------------------------
# Read user and group filter needed LDAP search
# Fiters are read from config modules stored in LDAP directory
BEGIN { $TYPEINFO{ReadFilters} = ["function", "boolean"];}
sub ReadFilters {

    my $init	= 1;

    if (!$initialized) {
	$init = Initialize ();
    }

    if (!$init) { return 0; }

    # get the default filters from config modules (already read)
    if (defined $user_config{"searchFilter"}) {
        $default_user_filter = @{$user_config{"searchFilter"}}[0];
    }
    if (defined $group_config{"searchFilter"}) {
        $default_group_filter = @{$group_config{"searchFilter"}}[0];
    }

    $filters_read = 1;
    return 1;
}

##------------------------------------
# Read settings from LDAP users and groups configuration
# ("config modules", configurable by ldap-client)
sub ReadSettings {

    my $init	= 1;

    if (!$filters_read) {
	$init = ReadFilters();
    }
    if (!$init) { return 0; }

    my %tmp_user_config		= %user_config;
    my %tmp_user_template	= %user_template;
    my %tmp_group_config	= %group_config;
    my %tmp_group_template	= %group_template;

    # every time take the first value from the list...
    if (defined $user_config{"defaultBase"}) {
	$user_base = $user_config{"defaultBase"}[0];
    }
    else {
	$user_base = Ldap::nss_base_passwd ();
    }
    if ($user_base eq "") {
	$user_base = Ldap::GetDomain();
    }

    if (defined $user_template{"defaultObjectClass"}) {
	@user_class = @{$user_template{"defaultObjectClass"}};
    }

    if (defined $group_config{"defaultBase"}) {
	$group_base = $group_config{"defaultBase"}[0];
    }
    else {
	$group_base = Ldap::nss_base_group ();
    }
    if ($group_base eq "") {
	$group_base = $user_base;
    }

    if (defined $group_template{"defaultObjectClass"}) {
	@group_class = @{$group_template{"defaultObjectClass"}};
	if (contains (\@group_class, "groupOfNames")) {
	    $member_attribute	= "member";
	}
	else {
	    $member_attribute	= "uniqueMember";
	}
	UsersCache::SetLDAPMemberAttribute ($member_attribute);
	# FIXME what about only posixGroup or anything else???
    }

    if (defined $user_template{"default_values"}) {
	%user_defaults = %{$user_template{"default_values"}};
    }

    if (defined $group_template{"default_values"}) {
	%group_defaults = %{$group_template{"default_values"}};
    }

    # default shadow (for new LDAP users)
    foreach my $key ("shadowWarning", "shadowInactive", "shadowExpire", "shadowMin", "shadowMax", "shadowFlag") {
	if (defined $user_defaults{$key}) {
	    $shadow{$key}	= $user_defaults{$key};
	}
	else {
	    $shadow{$key}	= "";
	}
    }
	
    if (defined $user_defaults{"homeDirectory"}) {
	$useradd_defaults{"home"}	= $user_defaults{"homeDirectory"};
    }
    if (defined $user_defaults{"gidNumber"}) {
	$useradd_defaults{"group"}	= $user_defaults{"gidNumber"};
    }
    if (defined $user_defaults{"loginShell"}) {
	$useradd_defaults{"shell"}	= $user_defaults{"loginShell"};
    }
    if (defined $user_config{"skelDir"}) {
	$useradd_defaults{"skel"}	= $user_config{"skelDir"}[0];
    }

    # set default secondary groups
    # Warning: there are DN's, but we want (?) only names...
    if (defined ($user_template{"secondaryGroup"})) {
	my @grouplist	= ();
	foreach my $dn (@{$user_template{"secondaryGroup"}}) {
	    push @grouplist, UsersCache::get_first ($dn);
	}
	$useradd_defaults{"groups"}	= join (",", @grouplist);
    };

    # password length (there is no check if it is correct for current hash)
    if (defined ($user_config{"minPasswordLength"})) {
	$min_pass_length	= $user_config{"minPasswordLength"}[0];
    }
    if (defined ($user_config{"maxPasswordLength"})) {
	$max_pass_length	= $user_config{"maxPasswordLength"}[0];
    }

    # last used Id
    if (defined ($user_config{"nextUniqueId"})) {
	$last_uid = $user_config{"nextUniqueId"}[0];
    }
    else {
	$last_uid = UsersCache::last_uid{"local"};
    }
    UsersCache::SetLastUID ($last_uid, "ldap");

    if (defined ($group_config{"nextUniqueId"})) {
	$last_gid = $group_config{"nextUniqueId"}[0];
    }
    else {
	$last_gid = UsersCache::last_gid{"local"};
    }
    UsersCache::SetLastGID ($last_gid, "ldap");

    # naming attributes
    if (defined ($user_template{"namingAttribute"})) {
        $user_naming_attr = $user_template{"namingAttribute"}[0];
    }
    if (defined ($group_template{"namingAttribute"})) {
        $group_naming_attr = $group_template{"namingAttribute"}[0];
    }

    # max id
    if (defined ($user_config{"maxUniqueId"})) {
	$max_uid	= $user_config{"maxUniqueId"}[0];
    }
    if (defined ($group_config{"maxUniqueId"})) {
	$max_gid	= $group_config{"maxUniqueId"}[0];
    }
    UsersCache::SetMaxUID ($max_uid, "ldap");
    UsersCache::SetMaxGID ($max_gid, "ldap");

    # min id
    if (defined ($user_config{"minUniqueId"})) {
	$min_uid	= $user_config{"minUniqueId"}[0];
    }
    if (defined ($group_config{"minUniqueId"})) {
	$min_gid	= $group_config{"minUniqueId"}[0];
    }
    UsersCache::SetMinUID ($min_uid, "ldap");
    UsersCache::SetMinGID ($min_gid, "ldap");

    if (defined ($user_config{"passwordHash"})) {
	$encryption 	= $user_config{"passwordHash"}[0];
    }
    else {
	$encryption	= Ldap::pam_password ();
    }
    if ($encryption eq "") {
	$encryption	= "crypt"; # same as "des"
    }
    return 1;
}


##------------------------------------
# do the LDAP search command for users and groups;
# check the search filters before
sub Read {

    my $ret = "";

    my $user_filter = $user_filter ne "" ? $user_filter: $default_user_filter;
    my $group_filter = $group_filter ne ""? $group_filter:$default_group_filter;

    # TODO use allowed/required attrs from config?
    # (if yes, objectClass must be in required!)
    # For now, we get all:
    my @user_attrs	= ();
    my @group_attrs 	= ();

    my %args = (
	"user_base"		=> $user_base,
	"group_base"		=> $group_base,
	"user_filter"		=> $user_filter,
	"group_filter"		=> $group_filter,
	"user_scope"		=> 2,# = sub - TODO configurable?
	"group_scope"		=> 2,
	"user_attrs"		=> @user_attrs,
	"group_attrs"		=> @group_attrs,
	"itemlists"		=> YaST::YCP::Boolean (1),
	"member_attribute"	=> $member_attribute
    );
    if (!SCR::Execute (".ldap.users.search", \%args)) {
	$ret = Ldap::LDAPError();
    }
    return $ret;
}

##------------------------------------
# initialize constants with the values from Users
BEGIN { $TYPEINFO{InitConstants} = ["function",
    "void",
    ["map", "string", "string" ]];
}
sub InitConstants {
    %useradd_defaults	= %{$_[0]};
}

###------------------------------------
## initialize list of plugins with the values from Users
#BEGIN { $TYPEINFO{InitPlugins} = ["function",
#    "void",
#    ["list", "string"]];
#}
#sub InitPlugins {
#    @available_plugins	= @{$_[0]};
#}

###------------------------------------
#BEGIN { $TYPEINFO{GetLoginDefaults} = ["function",
#    ["map", "string", "string"]];
#}
#sub GetLoginDefaults {
#    return \%useradd_defaults;
#}

##------------------------------------
BEGIN { $TYPEINFO{GetDefaultGrouplist} = ["function", "string"];}
sub GetDefaultGrouplist {
    return $useradd_defaults{"groups"};
}

##------------------------------------
BEGIN { $TYPEINFO{GetDefaultGID} = ["function", "integer"];}
sub GetDefaultGID {
    return $useradd_defaults{"group"};
}

##------------------------------------
BEGIN { $TYPEINFO{GetDefaultShell} = ["function", "string"]; }
sub GetDefaultShell {
    return $useradd_defaults{"shell"};
}

##------------------------------------
BEGIN { $TYPEINFO{GetDefaultHome} = ["function", "string"]; }
sub GetDefaultHome {
    return $useradd_defaults{"home"};
}

##------------------------------------
BEGIN { $TYPEINFO{GetMinPasswordLength} = ["function", "string"]; }
sub GetMinPasswordLength {
    return $min_pass_length;
}

##------------------------------------
BEGIN { $TYPEINFO{GetMaxPasswordLength} = ["function", "string"]; }
sub GetMaxPasswordLength {
    return $max_pass_length;
}

##------------------------------------
# return list of attributesm required for LDAP user
BEGIN { $TYPEINFO{GetUserRequiredAttributes} = ["function", ["list","string"]];}
sub GetUserRequiredAttributes {
    if (defined ($user_template{"requiredAttribute"})) {
	return @{$user_template{"requiredAttribute"}};
    }
    return ();
}

# return list of attributesm required for LDAP group
BEGIN {$TYPEINFO{GetGroupRequiredAttributes} = ["function", ["list","string"]];}
sub GetGroupRequiredAttributes {
    if (defined ($group_template{"requiredAttribute"})) {
	return @{$group_template{"requiredAttribute"}};
    }
    return ();
}

##------------------------------------
BEGIN { $TYPEINFO{GetDefaultShadow} = ["function",
    [ "map", "string", "string"]];
}
sub GetDefaultShadow {
    return \%shadow;
}

##------------------------------------
BEGIN { $TYPEINFO{GetUserClass} = ["function", ["list", "string"]];}
sub GetUserClass {
    return @user_class;
}

##------------------------------------
BEGIN { $TYPEINFO{GetUserDefaults} = ["function", ["map", "string","string"]];}
sub GetUserDefaults {
    return \%user_defaults;
}

##------------------------------------
BEGIN { $TYPEINFO{GetUserNamingAttr} = ["function", "string"];}
sub GetUserNamingAttr {
    return $user_naming_attr;
}

##------------------------------------
BEGIN { $TYPEINFO{GetUserBase} = ["function", "string"];}
sub GetUserBase {
    return $user_base;
}

##------------------------------------
BEGIN { $TYPEINFO{GetUserInternal} = ["function", ["list", "string"]];}
sub GetUserInternal {
    return @user_internal_keys;
}

##------------------------------------
BEGIN { $TYPEINFO{GetUserAttrsLDAP2YaST} = ["function",
    ["map", "string", "string"]];
}
sub GetUserAttrsLDAP2YaST {
    return \%ldap2yast_user_attrs;
}

##------------------------------------
BEGIN { $TYPEINFO{GetDefaultUserFilter} = ["function", "string"];}
sub GetDefaultUserFilter {
    return $default_user_filter;
}

##------------------------------------
BEGIN { $TYPEINFO{GetCurrentUserFilter} = ["function", "string"];}
sub GetCurrentUserFilter {
    return $user_filter;
}

##------------------------------------
BEGIN { $TYPEINFO{SetCurrentUserFilter} = ["function", "void", "string"];}
sub SetCurrentUserFilter {
    $user_filter = $_[0];
}


##------------------------------------
BEGIN { $TYPEINFO{GetGroupClass} = ["function", ["list", "string"]];}
sub GetGroupClass {
    return @group_class;
}

##------------------------------------
BEGIN { $TYPEINFO{GetGroupDefaults} = ["function", ["map", "string","string"]];}
sub GetGroupDefaults {
    return \%group_defaults;
}

##------------------------------------
BEGIN { $TYPEINFO{GetGroupNamingAttr} = ["function", "string"];}
sub GetGroupNamingAttr {
    return $group_naming_attr;
}

##------------------------------------
BEGIN { $TYPEINFO{GetGroupBase} = ["function", "string"];}
sub GetGroupBase {
    return $group_base;
}

##------------------------------------
BEGIN { $TYPEINFO{GetGroupInternal} = ["function", ["list", "string"]];}
sub GetGroupInternal {
    return @group_internal_keys;
}

##------------------------------------
BEGIN { $TYPEINFO{GetGroupAttrsLDAP2YaST} = ["function",
    ["map", "string", "string"]];
}
sub GetGroupAttrsLDAP2YaST {
    return \%ldap2yast_group_attrs;
}

##------------------------------------
BEGIN { $TYPEINFO{GetDefaultGroupFilter} = ["function", "string"];}
sub GetDefaultGroupFilter {
    return $default_group_filter;
}

##------------------------------------
BEGIN { $TYPEINFO{GetCurrentGroupFilter} = ["function", "string"];}
sub GetCurrentGroupFilter {
    return $group_filter;
}

##------------------------------------
BEGIN { $TYPEINFO{SetCurrentGroupFilter} = ["function", "void", "string"];}
sub SetCurrentGroupFilter {
    $group_filter = $_[0];
}

##------------------------------------
BEGIN { $TYPEINFO{SetFiltersRead} = ["function", "void", "boolean"];}
sub SetFiltersRead {
    $filters_read = $_[0];
}

##------------------------------------
BEGIN { $TYPEINFO{SetInitialized} = ["function", "void", "boolean"];}
sub SetInitialized {
    $initialized = $_[0];
}

##------------------------------------
BEGIN { $TYPEINFO{GetMemberAttribute} = ["function", "string"];}
sub GetMemberAttribute {
    return $member_attribute;
}

##------------------------------------
BEGIN { $TYPEINFO{GetEncryption} = ["function", "string"];}
sub GetEncryption {
    return $encryption;
}

# Creates DN of user
BEGIN { $TYPEINFO{CreateUserDN} = ["function",
    "string",
    ["map", "string", "any"]];
}
sub CreateUserDN {

    my $user		= $_[0];
    my $dn_attr		= $user_naming_attr;
    my $user_attr	= $dn_attr;
    if (defined $ldap2yast_user_attrs{$dn_attr}) {
	$user_attr	= $ldap2yast_user_attrs{$dn_attr};
    }
    if (!defined $user->{$user_attr} || $user->{$user_attr} eq "") {
	return undef;
    }
    return sprintf ("%s=%s,%s", $dn_attr, $user->{$user_attr}, $user_base);
}

##------------------------------------
BEGIN { $TYPEINFO{CreateGroupDN} = ["function",
    "string",
    ["map", "string", "any"]];
}
sub CreateGroupDN {

    my $group		= $_[0];
    my $dn_attr		= $group_naming_attr;
    my $group_attr	= $dn_attr;
    if (defined $ldap2yast_group_attrs{$dn_attr}) {
	$group_attr	= $ldap2yast_group_attrs{$dn_attr};
    }
    if (!defined $group->{$group_attr} || $group->{$group_attr} eq "") {
	return undef;
    }
    return sprintf ("%s=%s,%s", $dn_attr, $group->{$group_attr}, $group_base);
}

##------------------------------------ 
# Take the object (user or group) and substitute the values of arguments with
# default values (marked in object template). Translates attribute names from
# LDAP types to internal yast-names.
# @param what "user" or "group"
# @param data map of already gathered keys and values
# @example map of default values contains pair "homeDirectory": "/home/%uid"
# -> value of "home" is set to "/home/" + username
# @return new data map with substituted values
BEGIN { $TYPEINFO{SubstituteValues} = ["function",
    ["map", "string", "any" ],
    "string", ["map", "string", "any" ]];
}
sub SubstituteValues {
    
    my $what	= $_[0];
    my $data	= $_[1];
    my %ret	= %{$data};

    my @internal	= ($what eq "user") ?
	@user_internal_keys : @group_internal_keys;

    my %defaults	= ($what eq "user") ? %user_defaults : %group_defaults;

    # 'value' of 'attr' should be changed
    foreach my $attr (keys %{$data}) {

	my $value	= $data->{$attr};
	my $svalue 	= "";

	if (!defined $value || ref ($value) eq "HASH") {
	    next;
	}
	if (ref ($value) eq "ARRAY") {
	    $svalue = $value->[0];
	}
	else {
	    $svalue = $value;
	}
	# substitute only when current value is empty or contains "%"
	if (contains (\@internal, $attr) ||
	    ($svalue ne "" && !($svalue =~ m/%/))) {
	    next;
	}

	# translate attribute names from LDAP to yast-type
	my $ldap_attr = $ldap_attrs_conversion{$attr} || $attr;
	my $val = $defaults{$ldap_attr};

	if (defined ($val) && $val =~ m/%/) {
	    my @parts	= split (/%/, $val);
	    my $result	= $parts[0];
	    my $i	= 1;
	    while ($i < @parts) {
		my $part	= $parts[$i];
		my $replaced 	= 0;
		# find a contens of substitution (filled in current user/group)
		foreach my $at (sort keys %{$data}) {
		    my $v = $data->{$at};
		    if (!defined $v || contains (\@internal, $at) || $replaced){
			next;
		    }
		    if (ref ($v) eq "HASH") {
			next;
		    }
		    my $sv	= $v;
		    if (ref ($v) eq "ARRAY") {
			$sv = $v->[0];
		    }
		    my $a	= $ldap_attrs_conversion{$at} || $at;
		    if (substr ($part, 0, length ($a)) eq $a) {
			$result	= $result.$sv.substr ($part, length ($a));
			$replaced = 1;
		    }
		}
		if (!$replaced) {
		    $result	= $result."%".$part;
		}
		$i ++;
	    }
	    if ($result ne $svalue) {
		y2milestone ("attribute '$attr' changed from '$svalue' to '$result'");
		$ret{$attr}	= $result;
	    }
	}
    }
    return \%ret;
}


##------------------------------------
# Convert internal map describing user or group to map that could be passed to
# ldap-agent (remove internal keys, rename attributes etc.)
# @param map of user or group
# @return converted map
sub ConvertMap {

    my $data		= $_[0];
    my %ret		= ();
    my @attributes	= Ldap::GetObjectAttributes ($data->{"objectClass"});
    my @internal	= @user_internal_keys;
    if (!defined $data->{"uidNumber"}) {
	@internal	= @group_internal_keys;
    }

    foreach my $key (keys %{$data}) {
	my $val	= $data->{$key};
	if (contains (\@internal, $key)) {
	    next;
	}
	if ($key eq "userPassword") {
	    if  (contains (["x","*","!"], $val)) {
		next;
	    }
	    my $enc	= lc ($encryption);
	    if ($enc ne "clear" && !($val =~ m/^{$enc}/)) {
		$val = sprintf ("{%s}%s", lc ($encryption), $val);
	    }
	}
	# check if the attributes are allowed by objectClass
	my $attr = $ldap_attrs_conversion{$key} || $key;
	if (!contains (\@attributes, $attr)) {
	    y2warning ("Attribute '$attr' is not allowed by schema");
	    next;
	}
	if ($key eq $member_attribute && ref ($val) eq "HASH") {
	    my @lval	= ();
	    foreach my $u (keys %{$val}) {
		push @lval, $u;
	    }
	    $val = \@lval;
	}
	$ret{$attr}	= $val;
    }
    return \%ret;
}

##------------------------------------
# Writing modified LDAP users with
# @param ldap_users map of all ldap users
# @param server true if this machine is file for LDAP
# @return empty map on success, map with error message and code otherwise
BEGIN { $TYPEINFO{WriteUsers} = ["function",
    "string",
    ["map", "string", "any"]];
}
sub WriteUsers {

    my %ret		= ();
    my $dn_attr 	= $user_naming_attr;
    my $last_id 	= $last_uid;
    my $users		= $_[0];
    
    # if ldap home directiories are on this machine
    my $server		= Ldap::file_server ();

    foreach my $uid (keys %{$users}) {

	my $user		= $users->{$uid};

        my $action      = $user->{"modified"};
        if (!defined ($action) || defined ($ret{"msg"})) {
            next; 
	}
        my $home	= $user->{"homeDirectory"} || "";
        my $org_home	= $user->{"org_user"}{"homeDirectory"} || $home;
        my $gid		= $user->{"gidNumber"} || GetDefaultGID ();
	my $create_home	= $user->{"create_home"} || YaST::YCP::Boolean (0);
	my $delete_home	= $user->{"delete_home"} || YaST::YCP::Boolean (0);

	# old DN stored from ldap-search (removed in Convert)
	my $dn		= $user->{"dn"}	|| "";
	my $org_dn	= $user->{"org_user"}{"dn"} || $dn;
	my @obj_classes	= @{$user->{"objectClass"}};
	if (@obj_classes == 0) {
	    @obj_classes= @user_class;
	}
	# check allowed object classes
	my @ocs		= ();
	foreach my $oc (@obj_classes) {
	    if (Ldap::ObjectClassExists ($oc)) {
		push @ocs, $oc;
	    }
	}
	$user->{"objectClass"}	= \@ocs;
	$user			= ConvertMap ($user);
	my $rdn			= "$dn_attr=".$user->{$dn_attr};
	my $new_dn		= "$rdn,$user_base";
	my %arg_map		= (
	    "dn"	=> $org_dn ne "" ? $org_dn : $new_dn
	);

	# ----------- now call the "before-write" plugin function for this user
	my @plugin_args		= ();
	push @plugin_args, "BeforeWrite";
	push @plugin_args, $user;
	UsersPlugins::Apply ("BeforeWrite", $user); #TODO params

	# --------------------------------------------------------------------
        if ($action eq "added") {
	    if (! SCR::Write (".ldap.add", \%arg_map, $user)) {
		%ret	= %{Ldap::LDAPErrorMap ()};
	    }
            # on server, we can modify homes
            else {
		if ($uid > $last_id) {
		    $last_id = $uid;
		}
		if ($server) {
		    if ($create_home->value) {
			UsersRoutines::CreateHome ($useradd_defaults{"skel"}, $home);
		    }
		    UsersRoutines::ChownHome ($uid, $gid, $home);
		}
	    }
        }
        elsif ($action eq "deleted") {
	    if (! SCR::Write (".ldap.delete", \%arg_map)) {
		%ret = %{Ldap::LDAPErrorMap ()};
	    }
            elsif ($server && $delete_home->value) {
                UsersRoutines::DeleteHome ($home);
            }
        }
        elsif ($action eq "edited") {
	    # if there are some attributes with empty values, agent should
	    # care of them - it will either:
	    # 1. delete the attribute (if there was a value before) or
	    # 2. ignore given attribute (when it doesn't exist)
	    $arg_map{"check_attrs"}	= YaST::YCP::Boolean (1);

	    if (lc ($dn) ne lc ($org_dn)) {
		$arg_map{"rdn"}		= $rdn;
		$arg_map{"new_dn"}	= $dn;
	    }
	    if (! SCR::Write (".ldap.modify", \%arg_map, $user)) {
		%ret = %{Ldap::LDAPErrorMap ()};
	    }
	    else {
		if ($uid > $last_id) {
		    $last_id = $uid;
		}
		if ($server && $home ne $org_home) {
		    if ($create_home->value) {
			UsersRoutines::MoveHome ($org_home, $home);
		    }
		    UsersRoutines::ChownHome ($uid, $gid, $home);
		}
            }
        }
	# ----------- now call the "write" plugin function for this user
	if (!defined $ret{"msg"}) {
	    @plugin_args		= ();
	    push @plugin_args, "Write";
	    push @plugin_args, $user;
	    UsersPlugins::Apply ("Write", $user); #TODO params
	}
	# --------------------------------------------------------------------
    }
    if ($last_id != $last_uid && $user_config_dn ne "")  {
	# set nextUniqueId in user config module
	$user_config{"nextUniqueId"}	= [ $last_id ];
	my %modules	= (
	    $user_config_dn => {
		"modified"	=> "edited"
	    }
	);
	$modules{$user_config_dn}{"nextUniqueId"} =$user_config{"nextUniqueId"};
        %ret = %{Ldap::WriteToLDAP (\%modules)};
    }
    if (%ret) {
	return $ret{"msg"};
    }
    return "";
}

##------------------------------------
# Writing modified LDAP groups
# @param ldap_groups map of all ldap groups
# @return empty map on success, map with error message and code otherwise
BEGIN { $TYPEINFO{WriteGroups} = ["function",
    "string",
    ["map", "string", "any"]];
}
sub WriteGroups {

    my %ret		= ();
    my $dn_attr 	= $group_naming_attr;
    my $last_id 	= $last_gid;
    my $groups		= $_[0];

    foreach my $gid (keys %{$groups}) {

	my $group		= $groups->{$gid};

        my $action      = $group->{"modified"};
        if (!defined ($action) || defined ($ret{"msg"})) {
            next; 
	}
	my %new_group	= ();
	my $dn		= $group->{"dn"}	|| "";
	my $org_dn	= $group->{"org_dn"} 	|| $dn;
	my @obj_classes	= @{$group->{"objectClass"}};
	if (@obj_classes == 0) {
	    @obj_classes= @group_class;
	}
	my %o_classes	= ();
	foreach my $oc (@obj_classes) {
	    $o_classes{$oc}	= 1;
	}

	my $group_oc	= "groupOfUniqueNames";
	if ($member_attribute eq "Member") {
	    $group_oc	= "groupOfNames";
	}

	# if there is no member of the group, group must be changed
	# to namedObject
	if ((!defined $group->{$member_attribute} ||
	     !%{$group->{$member_attribute}})
	    && defined $o_classes{$group_oc})
	{
	    if ($action eq "added" || $action eq "edited") {
		delete $o_classes{$group_oc};
		$o_classes{"namedObject"}	= 1;
	    }
	    if ($action eq "edited") {
		# delete old group and create new with altered objectClass
		%new_group	= %{$group};
		$action		= "deleted";
	    }
	}
	# we are adding users to empty group (=namedObject):
	# group must be changed to groupOfUniqueNames
	elsif (%{$group->{$member_attribute}} && $action eq "edited" &&
	       !defined $o_classes{$group_oc})
	{
	    # delete old group...
	    $action		= "deleted";
	    # ... and create new one with altered objectClass
	    delete $o_classes{"namedObject"};
	    $o_classes{$group_oc}	= 1;
	    %new_group			= %{$group};
	}
	my @ocs		= ();
	foreach my $oc (keys %o_classes) {
	    if (Ldap::ObjectClassExists ($oc)) {
		push @ocs, $oc;
	    }
	}
	$group->{"objectClass"}	= \@ocs;
	$group			= ConvertMap ($group);

	my $rdn			= "$dn_attr=".$group->{$dn_attr};
	my $new_dn		= "$rdn,$group_base";
	my %arg_map		= (
	    "dn"	=> $org_dn ne "" ? $org_dn : $new_dn
	);

        if ($action eq "added") {
	    if (!SCR::Write (".ldap.add", \%arg_map, $group)) {
		%ret 		= %{Ldap::LDAPErrorMap ()};
	    }
	    elsif ($gid > $last_id) {
		$last_id	= $gid;
	    }
        }
        elsif ($action eq "deleted") {
	    if (!SCR::Write (".ldap.delete", \%arg_map)) {
		%ret 		= %{Ldap::LDAPErrorMap ()};
	    }
        }
        elsif ($action eq "edited") {

	    $arg_map{"check_attrs"}	= YaST::YCP::Boolean (1);

	    if (lc ($dn) ne lc ($org_dn)) {
		$arg_map{"rdn"}		= $rdn;
		$arg_map{"new_dn"}	= $dn;
	    }

	    if (!SCR::Write (".ldap.modify", \%arg_map, $group)) {
		%ret 		= %{Ldap::LDAPErrorMap ()};
	    }
	    elsif ($gid > $last_id) {
		$last_id	= $gid;
	    }
        }
	if (%new_group && !%ret) {
	    # now add new group with modified objectClass
	    if (lc ($dn) ne lc ($org_dn)) {
		$arg_map{"dn"}	= $dn;
	    }
	    $new_group{"objectClass"}	= \@ocs;
	    if (!SCR::Write (".ldap.add", \%arg_map, ConvertMap (\%new_group))){
		%ret 		= %{Ldap::LDAPErrorMap ()};
	    }
	    elsif ($gid > $last_id) {
		$last_id = $gid;
	    }
	}
    }
    if ($last_id != $last_gid && $group_config_dn ne "")  {
	# set nextUniqueId in group config module
	$group_config{"nextUniqueId"}	= [ $last_id ];
	my %modules	= (
	    $group_config_dn => {
		"modified"	=> "edited"
	    }
	);
	$modules{$group_config_dn}{"nextUniqueId"} = $group_config{"nextUniqueId"};
        %ret = %{Ldap::WriteToLDAP (\%modules)};
    }

    if (%ret) {
	UsersCache::DebugMap (\%ret);
	return $ret{"msg"};
    }
    return "";
}

BEGIN { $TYPEINFO{SetGUI} = ["function", "void", "boolean"];}
sub SetGUI {
    $use_gui = $_[0];
}

1
# EOF
