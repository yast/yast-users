#! /usr/bin/perl -w
#
# UsersLDAP module:
# -- routines for handling LDAP users and groups
#

package UsersLDAP;

use strict;

use YaST::YCP qw(:LOGGING);
use YaPI;
use Data::Dumper;

textdomain ("users");

our %TYPEINFO;

# If YaST UI (Qt,ncurses) should be used
my $use_gui                     = 1;

# if LDAP user/group management is initialized
my $initialized 		= 0;

# if settings from Ldap module were already read
my $ldap_read 			= 0;

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
my $default_user_filter		= "objectclass=posixaccount";
my $default_group_filter	= "objectclass=posixgroup";

# which attribute have groups for list of members
my $member_attribute		= "member";

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
    ("top","posixaccount","shadowaccount", "inetorgperson");

# default object classes of LDAP groups (read from Ldap module)
my @group_class 		=
    ( "top", "posixgroup", "groupofnames");

# attributes for LDAP search; if empty, all non-empty attrs will be returned
my @user_attributes		= ();
my @group_attributes		= ();

# plugin used as defaults for LDAP users
my @default_user_plugins	= ( "UsersPluginLDAPAll" );

# plugin used as defaults for LDAP groups
my @default_group_plugins	= ( "UsersPluginLDAPAll" );

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

# Umask which is used for creating new home directories. (/etc/login.defs)
my $umask			= "022";

# keys in user's map which are not saved anywhere, they are used for internal
# purposes only
my @user_internal_keys		=
    ("create_home", "grouplist", "groupname", "modified", "org_username",
     "org_uid", "plugins", "text_userpassword", "current_text_userpassword",
     "plugins_to_remove",
     "org_uidnumber", "org_homedirectory","org_user", "type", "org_groupname",
     "org_type", "what", "encrypted", "no_skeleton", "disabled", "enabled",
     "dn", "org_dn", "removed_grouplist", "delete_home", "addit_data",
     "warning_message", "warning_message_ID", "confirmed_warnings", "home_mode",
     "crypted_home_size");

my @group_internal_keys		=
    ("modified", "type", "more_users", "s_userlist", "encrypted", "org_type",
     "dn", "org_dn", "org_groupname", "org_gidnumber", "removed_userlist",
     "what", "org_cn", "plugins", "plugins_to_remove", "org_group",
     "warning_message", "warning_message_ID", "confirmed_warnings");


# defualt scope for searching, set it by SetUserScope
my $user_scope			= YaST::YCP::Integer (2);
my $group_scope			= YaST::YCP::Integer (2);

# store the 'usage' flag of LDAP attribute
my $attribute_usage	= {};
 
##------------------------------------
##------------------- global imports

YaST::YCP::Import ("Ldap");
YaST::YCP::Import ("Mode");
YaST::YCP::Import ("Popup");
YaST::YCP::Import ("SCR");
YaST::YCP::Import ("Stage");
YaST::YCP::Import ("UsersCache");
YaST::YCP::Import ("UsersPlugins");
YaST::YCP::Import ("UsersRoutines");
YaST::YCP::Import ("UsersUI");

##------------------------------------

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
##------------------------------------
# Checks if set of LDAP users is available
BEGIN { $TYPEINFO{ReadAvailable} = ["function", "boolean"];}
sub ReadAvailable {

    my $self 		= shift;
    my $compat		= 0;
    my $passwd_source = SCR->Read (".etc.nsswitch_conf.passwd");
    if (defined $passwd_source) {
	foreach my $source (split (/ /, $passwd_source)) {
	    if ($source eq "ldap") { return 1; }
	    if ($source eq "compat") { $compat = 1; }
	}
    }
    if ($compat) {
	$passwd_source = SCR->Read (".etc.nsswitch_conf.passwd_compat");
	if (defined $passwd_source) {
	    foreach my $source (split (/ /, $passwd_source)) {
		if ($source eq "ldap") { return 1; }
	    }
	}
    }
    return 0;
}

# read all necessary settings from Ldap module
BEGIN { $TYPEINFO{ReadLdap} =  ["function", "boolean"];}
sub ReadLdap {

    $ldap_read	= Ldap->Read();
    return $ldap_read;
}

##------------------------------------
# Initializes LDAP connection and reads users and groups configuration
# return value is error message
sub Initialize {

    if (!$ldap_read) {
	ReadLdap ();
    }
    Ldap->SetGUI ($use_gui);

    my $ldap_mesg = Ldap->LDAPInitWithTLSCheck ({});
    if ($ldap_mesg ne "") {
	Ldap->LDAPErrorMessage ("init", $ldap_mesg);
	return $ldap_mesg;
    }
    if (!Ldap->anonymous () && !defined (Ldap->bind_pass ())) {
	y2error ("no password to LDAP - cannot bind!");
	# error message
	return __("No password for LDAP was entered.");
    }

    $ldap_mesg = Ldap->LDAPBind (Ldap->bind_pass ());
    if ($ldap_mesg ne "") {
	Ldap->LDAPErrorMessage ("init", $ldap_mesg);
	Ldap->SetBindPassword (undef);
	return $ldap_mesg;
    }
    $ldap_mesg = Ldap->InitSchema ();
    if ($ldap_mesg ne "") {
	Ldap->LDAPErrorMessage ("schema", $ldap_mesg);
	return $ldap_mesg;
    }

    $ldap_mesg = Ldap->ReadConfigModules ();
    if ($ldap_mesg ne "") {
	Ldap->LDAPErrorMessage ("read", $ldap_mesg);
	return $ldap_mesg;
    }

    my %modules = %{Ldap->GetConfigModules ()};
    while ( my ($dn, $config_module) = each %modules) {

	if (!defined $config_module->{"objectclass"}) {
	    next;
	}
	my $oc = $config_module->{"objectclass"};
	if (contains ($oc, "suseuserconfiguration", 1) ) {
	    $user_config_dn	= $dn;
	    %user_config 	= %{$config_module};
	}
	if (contains ($oc, "susegroupconfiguration", 1) ) {
	    $group_config_dn	= $dn;
	    %group_config 	= %{$config_module};
	}
    };

    my @user_templates		= ();
    if (defined $user_config{"susedefaulttemplate"}) {
	@user_templates 	= @{$user_config{"susedefaulttemplate"}};
    }
    my @group_templates		= ();
    if (defined $group_config{"susedefaulttemplate"}) {
	@group_templates 	= @{$group_config{"susedefaulttemplate"}};
    }
    my $user_template_dn	= $user_templates[0] || "";
    my $group_template_dn	= $group_templates[0] || "";

    # read only one default template
    if ((@user_templates > 1 || @group_templates > 1) && $use_gui) {
	my %templ =
	    %{UsersUI->ChooseTemplates (\@user_templates, \@group_templates)};
	if (%templ) {
	    $user_template_dn	= $templ{"user"} || $user_template_dn;
	    $group_template_dn	= $templ{"group"} || $group_template_dn;
	}
    }
    %user_template = %{Ldap->ConvertDefaultValues (
	Ldap->GetLDAPEntry ($user_template_dn))};
    %group_template = %{Ldap->ConvertDefaultValues (
	Ldap->GetLDAPEntry ($group_template_dn))};

    $initialized = 1;
    return "";
}


##------------------------------------
# Read user and group filter needed LDAP search
# Fiters are read from config modules stored in LDAP directory
BEGIN { $TYPEINFO{ReadFilters} = ["function", "string"];}
sub ReadFilters {

    my $self	= shift;
    my $init	= "";

    if (!$initialized) {
	$init = Initialize ();
    }

    if ($init ne "") { return $init; }

    # get the default filters from config modules (already read)
    if (defined $user_config{"susesearchfilter"}[0]) {
        $default_user_filter = @{$user_config{"susesearchfilter"}}[0];
    }
    if (defined $group_config{"susesearchfilter"}[0]) {
        $default_group_filter = @{$group_config{"susesearchfilter"}}[0];
    }

    $filters_read = 1;
    return $init;
}

##------------------------------------
# Read settings from LDAP users and groups configuration
# ("config modules", configurable by ldap-client)
BEGIN { $TYPEINFO{ReadSettings} = ["function", "string"];}
sub ReadSettings {

    my $self	= shift;
    my $init	= "";

    if (!$filters_read) {
	$init = $self->ReadFilters();
    }
    if ($init ne "") { return $init; }

    my %tmp_user_config		= %user_config;
    my %tmp_user_template	= %user_template;
    my %tmp_group_config	= %group_config;
    my %tmp_group_template	= %group_template;

    # every time take the first value from the list...
    if (defined $user_config{"susedefaultbase"}[0]) {
	$user_base = $user_config{"susedefaultbase"}[0];
	# ask to create if not present
	my $base_map	= Ldap->GetLDAPEntry ($user_base);
	if (ref ($base_map) eq "HASH" && !%$base_map) {

	    my $dn	= $user_base;
	    $user_base 	= Ldap->GetDomain();
	    if (!$use_gui || Stage->cont() ||
		# popup question, %s is string argument
		Popup->YesNo (sprintf (__("No entry with DN '%s'
exists on the LDAP server. Create it now?"), $dn)))
	    {
		if (Ldap->ParentExists ($dn) && Ldap->WriteLDAP ( {
		    $dn	=> {
			"objectclass"	=> [ "top", "organizationalunit"],
			"modified"	=> "added",
			"ou"		=> UsersCache->get_first ($dn)
		    }})) {
		    $user_base = $dn;
		}
	    }
	}
    }
    if ($user_base eq "") {
	$user_base = Ldap->GetDomain();
    }

    if (defined $group_config{"susedefaultbase"}[0]) {
	$group_base = $group_config{"susedefaultbase"}[0];
	my $base_map	= Ldap->GetLDAPEntry ($group_base);
	if (ref ($base_map) eq "HASH" && !%$base_map) {
	    my $dn	= $group_base;
	    $group_base 	= Ldap->GetDomain();
	    if (!$use_gui || Stage->cont() ||
		# popup question, %s is string argument
		Popup->YesNo (sprintf (__("No entry with DN '%s'
exists on the LDAP server. Create it now?"), $dn)))
	    {
		if (Ldap->ParentExists ($dn) && Ldap->WriteLDAP ( {
		    $dn	=> {
			"objectclass"	=> [ "top", "organizationalunit"],
			"modified"	=> "added",
			"ou"		=> UsersCache->get_first ($dn)
		    }})) {
		    $group_base = $dn;
		}
	    }
	}
    }
    if ($group_base eq "") {
	$group_base = $user_base;
    }

    $member_attribute	= Ldap->member_attribute ();
    if (defined $user_template{"suseplugin"}) {
	@default_user_plugins = @{$user_template{"suseplugin"}};
    }

    if (defined $group_template{"suseplugin"}) {
	@default_group_plugins = @{$group_template{"suseplugin"}};
    }

    if (defined $user_template{"default_values"}) {
	%user_defaults = %{$user_template{"default_values"}};
    }

    if (defined $group_template{"default_values"}) {
	%group_defaults = %{$group_template{"default_values"}};
    }

    # default shadow for new LDAP users
    foreach my $key ("shadowwarning", "shadowinactive", "shadowexpire", "shadowmin", "shadowmax", "shadowflag") {
	if (defined $user_defaults{$key}) {
	    $shadow{$key}	= $user_defaults{$key};
	}
    }
	
    if (defined $user_defaults{"homedirectory"}) {
	$useradd_defaults{"home"}	= $user_defaults{"homedirectory"};
    }
    if (defined $user_defaults{"gidnumber"}) {
	$useradd_defaults{"group"}	= $user_defaults{"gidnumber"};
    }
    if (defined $user_defaults{"loginshell"}) {
	$useradd_defaults{"shell"}	= $user_defaults{"loginshell"};
    }
    if (defined $user_config{"suseskeldir"}[0]) {
	$useradd_defaults{"skel"}	= $user_config{"suseskeldir"}[0];
    }
    # set default secondary groups
    # Warning: there are DN's, but we want (?) only names...
    if (defined ($user_template{"susesecondarygroup"})) {
	my @grouplist	= ();
	foreach my $dn (@{$user_template{"susesecondarygroup"}}) {
	    push @grouplist, UsersCache->get_first ($dn);
	}
	$useradd_defaults{"groups"}	= join (",", @grouplist);
    };

    # password length (there is no check if it is correct for current hash)
    if (defined ($user_config{"suseminpasswordlength"}[0])) {
	$min_pass_length	= $user_config{"suseminpasswordlength"}[0];
    }
    if (defined ($user_config{"susemaxpasswordlength"}[0])) {
	$max_pass_length	= $user_config{"susemaxpasswordlength"}[0];
    }

    # last used Id
    if (defined ($user_config{"susenextuniqueid"}[0])) {
	$last_uid = $user_config{"susenextuniqueid"}[0];
    }
    else {
	$last_uid = UsersCache->GetLastUID ("local");
    }
    UsersCache->SetLastUID ($last_uid, "ldap");

    if (defined ($group_config{"susenextuniqueid"}[0])) {
	$last_gid = $group_config{"susenextuniqueid"}[0];
    }
    else {
	$last_gid = UsersCache->GetLastGID ("local");
    }
    UsersCache->SetLastGID ($last_gid, "ldap");

    # naming attributes
    if (defined ($user_template{"susenamingattribute"}[0])) {
        $user_naming_attr = $user_template{"susenamingattribute"}[0];
    }
    if (defined ($group_template{"susenamingattribute"}[0])) {
        $group_naming_attr = $group_template{"susenamingattribute"}[0];
    }

    # max id
    if (defined ($user_config{"susemaxuniqueid"}[0])) {
	$max_uid	= $user_config{"susemaxuniqueid"}[0];
    }
    if (defined ($group_config{"susemaxuniqueid"}[0])) {
	$max_gid	= $group_config{"susemaxuniqueid"}[0];
    }
    UsersCache->SetMaxUID ($max_uid, "ldap");
    UsersCache->SetMaxGID ($max_gid, "ldap");

    # min id
    if (defined ($user_config{"suseminuniqueid"}[0])) {
	$min_uid	= $user_config{"suseminuniqueid"}[0];
    }
    if (defined ($group_config{"suseminuniqueid"}[0])) {
	$min_gid	= $group_config{"suseminuniqueid"}[0];
    }
    UsersCache->SetMinUID ($min_uid, "ldap");
    UsersCache->SetMinGID ($min_gid, "ldap");

    if (defined ($user_config{"susepasswordhash"}[0])) {
	$encryption 	= $user_config{"susepasswordhash"}[0];
    }
    else {
	$encryption	= Ldap->pam_password ();
    }
    if ($encryption eq "") {
	$encryption	= "crypt"; # same as "des"
    }
    return $init;
}


##------------------------------------
# do the LDAP search command for users and groups;
# check the search filters before
BEGIN { $TYPEINFO{Read} = ["function", "string"];}
sub Read {

    my $self 	= shift;
    my $ret	= "";

    my $user_filter = $user_filter ne "" ? $user_filter: $default_user_filter;
    my $group_filter = $group_filter ne ""? $group_filter:$default_group_filter;

    my $user_attrs	= \@user_attributes;
    if (@$user_attrs < 1) {
	$user_attrs	= [ "uid", "uidnumber", "gidnumber", "gecos", "cn", "homedirectory", "userpassword" ];
	y2milestone ("minimal set of user attrs to read: ", @$user_attrs);
    }
    my $group_attrs 	= \@group_attributes;

    my %args = (
	"user_base"		=> $user_base,
	"group_base"		=> $group_base,
	"user_filter"		=> $user_filter,
	"group_filter"		=> $group_filter,
	"user_scope"		=> $user_scope,
	"group_scope"		=> $group_scope,
	"user_attrs"		=> $user_attrs,
	"group_attrs"		=> $group_attrs,
	"member_attribute"	=> $member_attribute
    );
    if (!SCR->Execute (".ldap.users.search", \%args)) {
	$ret = Ldap->LDAPError();
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
    my $self 		= shift;
    my $local_defaults	= shift;
    if ($local_defaults && ref ($local_defaults) eq "HASH") {
	foreach my $key (keys %$local_defaults) {
	    $useradd_defaults{$key}	= $local_defaults->{$key};
	}
	# do not use local groups as secondary groups here (#38987)
	if (defined $local_defaults->{"groups"}) {
	    $useradd_defaults{"groups"}	= "";
	}    
    }
}


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
BEGIN { $TYPEINFO{GetMinPasswordLength} = ["function", "integer"]; }
sub GetMinPasswordLength {
    return $min_pass_length;
}

##------------------------------------
BEGIN { $TYPEINFO{GetMaxPasswordLength} = ["function", "integer"]; }
sub GetMaxPasswordLength {
    return $max_pass_length;
}

##------------------------------------
BEGIN { $TYPEINFO{SetDefaultShadow} = ["function", "void",
    [ "map", "string", "string"]];
}
sub SetDefaultShadow {
    my $self		= shift;
    my $shadow_map	= shift;

    if (ref ($shadow_map) ne "HASH") {
	return;
    }
    foreach my $k (keys %$shadow_map) {
	if (defined ($shadow_map->{$k}) && $shadow_map->{$k} ne "") {
	    $shadow{$k}	= $shadow_map->{$k};
	}
    }
}

##------------------------------------
BEGIN { $TYPEINFO{SetUmask} = ["function", "void", "string"];}
sub SetUmask {

    my $self    = shift;
    my $u	= shift;
    if (defined ($u) && $u ne "") {
	$umask	= $u;
    }
}

##------------------------------------
BEGIN { $TYPEINFO{GetDefaultShadow} = ["function",
    [ "map", "string", "string"]];
}
sub GetDefaultShadow {
    return \%shadow;
}

##------------------------------------
BEGIN { $TYPEINFO{GetUserPlugins} = ["function", ["list", "string"]];}
sub GetUserPlugins {
    return \@default_user_plugins;
}

##------------------------------------
BEGIN { $TYPEINFO{SetUserPlugins} = ["function", "void", ["list", "string"]];}
sub SetUserPlugins {
    my $self	= shift;
    if (ref ($_[0]) eq "ARRAY") {
	@default_user_plugins	= @{$_[0]};
    }
}

##------------------------------------
BEGIN { $TYPEINFO{GetUserAttributes} = ["function", ["list", "string"]];}
sub GetUserAttributes {
    return \@user_attributes;
}

##------------------------------------
BEGIN { $TYPEINFO{SetUserAttributes} = ["function", "void",["list", "string"]];}
sub SetUserAttributes {
    my $self	= shift;
    if (ref ($_[0]) eq "ARRAY") {
	@user_attributes	= @{$_[0]};
    }
}

##------------------------------------
BEGIN { $TYPEINFO{GetGroupAttributes} = ["function", ["list", "string"]];}
sub GetGroupAttributes {
    return \@group_attributes;
}

##------------------------------------
BEGIN { $TYPEINFO{SetGroupAttributes} = ["function", "void",["list","string"]];}
sub SetGroupAttributes {
    my $self	= shift;
    if (ref ($_[0]) eq "ARRAY") {
	@group_attributes	= @{$_[0]};
    }
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
BEGIN { $TYPEINFO{SetUserBase} = ["function", "void", "string"];}
sub SetUserBase {
    my $self	= shift;
    $user_base	= $_[0];
}

##------------------------------------
BEGIN { $TYPEINFO{GetUserInternal} = ["function", ["list", "string"]];}
sub GetUserInternal {
    return \@user_internal_keys;
}

##------------------------------------
BEGIN { $TYPEINFO{SetUserInternal} = ["function", "void", ["list", "string"]];}
sub SetUserInternal {
    my $self    = shift;
    if (ref ($_[0]) eq "ARRAY") {
	@user_internal_keys	= @{$_[0]};
    }
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
    my $self = shift;
    $user_filter = $_[0];
}

##------------------------------------
# add new condition to current user filter
BEGIN { $TYPEINFO{AddToCurrentUserFilter} = ["function", "void", "string"];}
sub AddToCurrentUserFilter {
    my $self		= shift;
    my $new_filter	= shift;

    if (!defined $user_filter || $user_filter eq "") {
	$user_filter	= $default_user_filter
    }
    if ($user_filter eq "" || $new_filter eq "") {
	return;
    }
    
    if (substr ($user_filter, 0, 1) ne "(") {
	$user_filter	= "($user_filter)";
    }
    if (substr ($new_filter, 0, 1) ne "(") {
	$new_filter	= "($new_filter)";
    }
    $user_filter	= "(&$user_filter$new_filter)";
}


##------------------------------------
# add new condition to given filter
BEGIN { $TYPEINFO{AddToFilter} = ["function", "string",	# filter to return
    "string",	# filter
    "string",	# what to add
    "string"	# connective: and/or
];}
sub AddToFilter {

    my $self	= shift;
    my $filter	= shift;
    my $new	= shift;
    my $conn	= shift;

    if ($filter eq "") {
	return $new;
    }
    if ($new eq "") {
	return $filter;
    }

    if (substr ($filter, 0, 1) ne "(") {
	$filter	= "($filter)";
    }
    if (substr ($new, 0, 1) ne "(") {
	$new	= "($new)";
    }
    $conn	= (lc ($conn) eq "or") ? "|" : "&";
    return "($conn$filter$new)";
}


##------------------------------------
BEGIN { $TYPEINFO{SetUserScope} = ["function", "void", "integer"];}
sub SetUserScope {
    my $self = shift;
    $user_scope = $_[0];
    if (ref ($user_scope) ne "YaST::YCP::Integer") {
	$user_scope	= YaST::YCP::Integer ($user_scope);
    }
}


##------------------------------------
BEGIN { $TYPEINFO{GetGroupPlugins} = ["function", ["list", "string"]];}
sub GetGroupPlugins {
    return \@default_group_plugins;
}

##------------------------------------
BEGIN { $TYPEINFO{SetGroupPlugins} = ["function", "void", ["list", "string"]];}
sub SetGroupPlugins {
    my $self	= shift;
    if (ref ($_[0]) eq "ARRAY") {
	@default_group_plugins	= @{$_[0]};
    }
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
BEGIN { $TYPEINFO{SetGroupBase} = ["function", "void", "string"];}
sub SetGroupBase {
    my $self	= shift;
    $group_base	= $_[0];
}

##------------------------------------
BEGIN { $TYPEINFO{GetGroupInternal} = ["function", ["list", "string"]];}
sub GetGroupInternal {
    return \@group_internal_keys;
}

##------------------------------------
BEGIN { $TYPEINFO{SetGroupInternal} = ["function", "void", ["list", "string"]];}
sub SetGroupInternal {
    my $self    = shift;
    if (ref ($_[0]) eq "ARRAY") {
	@group_internal_keys	= @{$_[0]};
    }
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
    my $self = shift;
    $group_filter = $_[0];
}

##------------------------------------
# add new condition to current group filter
BEGIN { $TYPEINFO{AddToCurrentGroupFilter} = ["function", "void", "string"];}
sub AddToCurrentGroupFilter {
    my $self = shift;
    if (!defined $group_filter || $group_filter eq "") {
	$group_filter	= $default_group_filter
    }
    my $new_filter	= shift;
    if (substr ($group_filter, 0, 1) ne "(") {
	$group_filter	= "($group_filter)";
    }
    if (substr ($new_filter, 0, 1) ne "(") {
	$new_filter	= "($new_filter)";
    }
    $group_filter	= "(&$group_filter$new_filter)";
}

##------------------------------------
BEGIN { $TYPEINFO{SetGroupScope} = ["function", "void", "integer"];}
sub SetGroupScope {
    my $self = shift;
    $group_scope = $_[0];
    if (ref ($group_scope) ne "YaST::YCP::Integer") {
	$group_scope	= YaST::YCP::Integer ($group_scope);
    }
}

##------------------------------------
BEGIN { $TYPEINFO{SetFiltersRead} = ["function", "void", "boolean"];}
sub SetFiltersRead {
    my $self = shift;
    $filters_read = $_[0];
}

##------------------------------------
BEGIN { $TYPEINFO{SetInitialized} = ["function", "void", "boolean"];}
sub SetInitialized {
    my $self = shift;
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

    my $self		= shift;
    my $user		= $_[0];
    my $dn_attr		= $user_naming_attr;
    my $user_attr	= $dn_attr;
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

    my $self 		= shift;
    my $group		= $_[0];
    my $dn_attr		= $group_naming_attr;
    my $group_attr	= $dn_attr;
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
# @example map of default values contains pair "homedirectory": "/home/%uid"
# -> value of "home" is set to "/home/" + username
# @return new data map with substituted values
BEGIN { $TYPEINFO{SubstituteValues} = ["function",
    ["map", "string", "any" ],
    "string", ["map", "string", "any" ]];
}
sub SubstituteValues {
    
    my $self 	= shift;
    my $what	= $_[0];
    my $data	= $_[1];
    my %ret	= %{$data};

    my @internal	= ($what eq "user") ?
	@user_internal_keys : @group_internal_keys;

    my %defaults	= ($what eq "user") ? %user_defaults : %group_defaults;

    if (Mode->test ()) {
	%defaults	= (
	    "homedirectory" 	=> "/home/\%uid",
	    "cn"		=> "\%uid",
	)
    }

    # 'value' of 'attr' should be changed
    foreach my $attr (keys %{$data}) {

	my $lattr	= lc ($attr);
	my $value	= $data->{$lattr};
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
	if (!defined $svalue ||
	    contains (\@internal, $lattr, 1) ||
	    ($svalue ne "" && !($svalue =~ m/%/))) {
	    next;
	}
	# translate attribute names from LDAP to yast-type
	my $val = $defaults{$lattr};

	if (defined ($val) && $val =~ m/%/) {
	    my @parts	= split (/%/, $val);
	    my $result	= $parts[0];
	    my $i	= 1;
	    while ($i < @parts) {
		my $part	= lc ($parts[$i]);
		my $replaced 	= 0;
		# find a contens of substitution (filled in current user/group)
		foreach my $at (sort keys %{$data}) {
		    my $a = lc ($at);
		    my $v = $data->{$a};
		    if (!defined $v || contains (\@internal, $a, 1) || $replaced){
			next;
		    }
		    if (ref ($v) eq "HASH") {
			next;
		    }
		    my $sv	= $v;
		    if (ref ($v) eq "ARRAY") {
			$sv = $v->[0];
		    }
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
		y2milestone ("attribute '$lattr' changed from '$svalue' to '$result'");
		$ret{$lattr}	= $result;
	    }
	}
    }
    return \%ret;
}

# compares 2 arrays; return 1 if they are equal
# (from perlfaq)
sub same_arrays {

    my ($first, $second) = @_;
    return 0 unless @$first == @$second;
    for (my $i = 0; $i < @$first; $i++) {
	return 0 if $first->[$i] ne $second->[$i];
    }
    return 1;
}


##------------------------------------
# Convert internal map describing user or group to map that could be passed to
# ldap-agent (remove internal keys, rename attributes etc.)
# @param map of user or group
# @return converted map
BEGIN { $TYPEINFO{ConvertMap} = ["function",
    ["map", "string", "any" ],
    ["map", "string", "any" ]];
}
sub ConvertMap {

    my $self		= shift;
    my $data		= shift;
    my $org_object	= undef;
    my $org_ocs		= undef;

    if (defined $data->{"org_user"} && $data->{"modified"} eq "edited") {
	$org_object	= $data->{"org_user"};
    }
    if (defined $data->{"org_group"} && $data->{"modified"} eq "edited") {
	$org_object	= $data->{"org_group"};
    }
    if (defined $org_object->{"objectclass"}) {
	$org_ocs	= $org_object->{"objectclass"};
    }

    my %ret		= ();
    my @attributes	= ();
    my $attributes	= Ldap->GetObjectAttributes ($data->{"objectclass"});
    if (defined $attributes && ref ($attributes) eq "ARRAY") {
	@attributes	= @{$attributes};
    }
    my $old_attributes	= [];
    if (defined $org_ocs) {
	my @ocs		= ();
	foreach my $oc (@$org_ocs) {
	    # object class was deleted
	    if (!contains ($data->{"objectclass"}, $oc, 1)) {
		push @ocs, $oc;
	    }
	}
	if (@ocs > 0) {
	    $old_attributes	= Ldap->GetObjectAttributes (\@ocs);
	}
    }

    my @internal	= @user_internal_keys;
    if (!defined $data->{"uidnumber"}) {
	@internal	= @group_internal_keys;
    }
    foreach my $key (keys %{$data}) {
	my $val	= $data->{$key};
	if (contains (\@internal, $key, 1)) {
	    next;
	}
	if ($key eq "userpassword") {
	    if (!defined $val) {
		next;
	    }
	    my $enc	= lc ($encryption);
	    # check for unchanged password before prepending the hash (#213574)
	    if (defined $org_object && defined $org_object->{$key}) {
		next if $val eq $org_object->{$key};
	    }
	    if ($enc ne "clear" && !($val =~ m/{$enc}/i)) {
		$val = sprintf ("{%s}%s", $enc, $val);
	    }
	}
	# now remove the keys with the unchanged values...
	if (defined $org_object && defined $org_object->{$key}) {

	    if (ref ($val) eq "ARRAY" && ref ($org_object->{$key}) eq "ARRAY"
		 && same_arrays ($val, $org_object->{$key})) {
		y2debug ("---- unchanged array key: $key, value: ", @$val);
		next;
	    }
	    elsif ($org_object->{$key} eq $val) {
		y2debug ("---------- unchanged key: $key, value: $val");
		next;
	    }
	}

	# check if the attributes are allowed by objectclass
	if (!contains (\@attributes, $key, 1)) {
	    if (contains ($old_attributes, $key, 1)) {
		# remove the old attribute
		y2milestone ("Attribute '$key' is not supported now.");
		$val	= "";
	    }
	    else {
		if (not defined ($attribute_usage->{$key})) {
		    my $at = SCR->Read (".ldap.schema.at", {"name" => $key});
		    $attribute_usage->{$key}	= $at->{'usage'};
		    $attribute_usage->{$key}	= 0 if not defined $at->{'usage'};
		}
		# 1, 2 and 3 are operational attributes, they do not require object class
		# 0=userApplications, 1=directoryOperation, 2=distributedOperation, 3=dSAOperation
		if ($attribute_usage->{$key} < 1) {
		    y2warning ("Attribute '$key' is not allowed by schema.");
		    next;
		}
	    }
	}
	if ($key eq $member_attribute && ref ($val) eq "HASH") {
	    my @lval	= ();
	    foreach my $u (keys %{$val}) {
		push @lval, $u;
	    }
	    $val = \@lval;
	}
	y2debug ("-------------------- key: $key, value: $val");

	$ret{$key}	= $val;
    }
    return \%ret;
}

# check the boolean value
sub bool {

    my $param = $_[0];
    if (!defined $param) {
	return 0;
    }
    if (ref ($param) eq "YaST::YCP::Boolean") {
	return $param->value();
    }
    return $param;
}

# gets base from the DN
sub get_base {

    my $dn	= $_[0];
    if (!defined $dn) {
	return "";
    }
    my @dn_list	= split (",", $dn);
    shift @dn_list;
    return join (',', @dn_list);
}


# read the error message generated by plugin
# first parameter is plugin name, 2nd one is configuration map
sub GetPluginError {

    my $plugin	= shift;
    my $config	= shift;

    my $result = UsersPlugins->Apply ("Error", $config, {});
    if (defined $result->{$plugin} && $result->{$plugin} ne "") {
	return $result->{$plugin};
    }
    return "";
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

    my $self 		= shift;
    my %ret		= ();
    my $dn_attr 	= $user_naming_attr;
    my $last_id 	= $last_uid;
    my $users		= $_[0];
    
    # if ldap home directiories are on this machine
    my $server		= Ldap->file_server ();

    foreach my $username (keys %{$users}) {

	my $user		= $users->{$username};

        my $action      = $user->{"modified"};
        if (!defined ($action) || defined ($ret{"msg"})) {
            next; 
	}
	my $uid		= $user->{"uidnumber"};
	if (! defined $uid) { $uid	= GetDefaultUID (); }
        my $home	= $user->{"homedirectory"} || "";
        my $org_home	= $user->{"org_user"}{"homedirectory"} || $home;
        my $gid		= $user->{"gidnumber"};
	if (!defined $gid) { $gid	= GetDefaultGID (); }
	my $create_home	= bool ($user->{"create_home"});
	my $delete_home	= bool ($user->{"delete_home"});
	my $enabled	= bool ($user->{"enabled"});
	my $disabled	= bool ($user->{"disabled"});
	my $plugins	= $user->{"plugins"};
	my $plugins_to_remove	= $user->{"plugins_to_remove"};
	my $plugin_error	= "";

	my $org_username= $user->{"org_user"}{"uid"} || $username;
	# old DN stored from ldap-search (removed in Convert)
	my $dn		= $user->{"dn"}	|| "";
	my $org_dn	= $user->{"org_user"}{"dn"} || $dn;
	my @obj_classes	= @user_class;
	if (defined $user->{"objectclass"} &&
	    ref ($user->{"objectclass"}) eq "ARRAY") {
	    @obj_classes= @{$user->{"objectclass"}};
	}
	# check allowed object classes
	my @ocs		= ();
	if ($action ne "deleted") {
	    foreach my $oc (@obj_classes) {
		if (Ldap->ObjectClassExists ($oc)) {
		    push @ocs, $oc;
		}
	    }
	    $user->{"objectclass"}	= \@ocs;
	}
	my $mode = 777 - String->CutZeros ($umask);
	if (defined ($user->{"home_mode"})) {
	    $mode	= $user->{"home_mode"};
	}
	# ----------- now call the WriteBefore plugin function for this user

	if (!defined $plugins) {
	    $plugins	= \@default_user_plugins;
	}
	my $config	= {
	    "what"	=> "user",
	    "type"	=> "ldap",
	    "modified"	=> $action
	};
	if ($disabled) {
	    $config->{"disabled"}	= $disabled;
	}
	if ($enabled) {
	    $config->{"enabled"}	= $disabled;
	}
	if (defined $plugins_to_remove) {
	    $config->{"plugins_to_remove"}	= $plugins_to_remove;
	}
	# ---------- for deleted users, get the list of all plugins using the
	# PluginPresent call (in add/edit cases, plugins were already read in
	# Users->Edit/Add functions)
	if ($action eq "deleted") {
	    my $res = UsersPlugins->Apply ("PluginPresent", $config, $user);
	    if (defined ($res) && ref ($res) eq "HASH") {
		$plugins = [];
		foreach my $plugin (keys %{$res}) {
		    if (bool ($res->{$plugin}) &&
			!contains ($plugins, $plugin, 1)) {
			push @{$plugins}, $plugin;
		    }
		}
	    }
	}

	foreach my $plugin (sort @{$plugins}) {
	    $config->{"plugins"}	= [ $plugin ];
	    my $res = UsersPlugins->Apply ("WriteBefore", $config, $user);
	    if (!bool ($res->{$plugin})) {
		$plugin_error = GetPluginError ($plugin, $config);
		if ($plugin_error) { last; }
	    }
	}
	# now call WriteBefore on plugins which should be removed:
	# (such call could e.g. remove mail account)
        if (defined $plugins_to_remove && $plugin_error eq "") {
            foreach my $plugin (sort @{$plugins_to_remove}) {
                $config->{"plugins"}	= [ $plugin ];
                my $res = UsersPlugins->Apply ("WriteBefore", $config, $user);
		if (!bool ($res->{$plugin})) {
		    $plugin_error = GetPluginError ($plugin, $config);
		    if ($plugin_error) { last; }
		}
            }
        }
	if ($plugin_error) {
	    $ret{"msg"}	= $plugin_error;
	    last; # stop processing LDAP write...
	}
	# --------------------------------------------------------------------
	# --------------------------------------------------------------------
	my $rdn			= "$dn_attr=".$user->{$dn_attr};
	my $new_dn		= "$rdn,$user_base";
	my %arg_map		= (
	    "dn"	=> $org_dn ne "" ? $org_dn : $new_dn
	);

        if ($action eq "added") {
	    if ($org_dn ne "") {
		$arg_map{"dn"}	= $new_dn;
	    }
	    if (!SCR->Write (".ldap.add",\%arg_map,$self->ConvertMap ($user))) {
		%ret	= %{Ldap->LDAPErrorMap ()};
	    }
            # on server, we can modify homes
            else {
		if ($uid > $last_id) {
		    $last_id = $uid;
		}
		if ($server) {
		    if ($create_home) {
			UsersRoutines->CreateHome (
			    $useradd_defaults{"skel"}, $home);
		    }
		    if ($home ne "/var/lib/nobody") {
			if (UsersRoutines->ChownHome ($uid, $gid, $home)) {
			    UsersRoutines->ChmodHome($home, $mode);
			}
		    }
		}
	    }
        }
        elsif ($action eq "deleted") {
	    if (! SCR->Write (".ldap.delete", \%arg_map)) {
		%ret = %{Ldap->LDAPErrorMap ()};
	    }
            elsif ($server && $delete_home) {
                UsersRoutines->DeleteHome ($home);
		UsersRoutines->DeleteCryptedHome ($home, $org_username);
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
		my $new_base		= get_base ($dn);
		if ($new_base ne get_base ($arg_map{"dn"})) {
		    $arg_map{"newParentDN"}	= $new_base;
		}
	    }
	    if (!SCR->Write (".ldap.modify", \%arg_map, $self->ConvertMap ($user))) {
		%ret = %{Ldap->LDAPErrorMap ()};
	    }
	    else {
		if ($uid > $last_id) {
		    $last_id = $uid;
		}
		if ($server && $home ne $org_home && $home ne "/var/lib/nobody") {
		    if ($create_home) {
			UsersRoutines->MoveHome ($org_home, $home);
		    }
		    if (!defined $user->{"crypted_home_size"} || $user->{"crypted_home_size"} eq 0){
			UsersRoutines->ChownHome ($uid, $gid, $home);
		    }
		}
            }
        }
	if (defined $ret{"msg"}) {
	    last; # error on write
	}
	# ----------- now call the "write" plugin function for this user
	foreach my $plugin (sort @{$plugins}) {
	    $config->{"plugins"}	= [ $plugin ];
	    my $res = UsersPlugins->Apply ("Write", $config, $user);
	    if (!bool ($res->{$plugin})) {
		$plugin_error = GetPluginError ($plugin, $config);
		if ($plugin_error) { last; }
	    }
	}
        if (defined $plugins_to_remove && $plugin_error eq "") {
	    foreach my $plugin (sort @{$plugins_to_remove}) {
		$config->{"plugins"}	= [ $plugin ];
		my $res = UsersPlugins->Apply ("Write", $config, $user);
		if (!bool ($res->{$plugin})) {
		    $plugin_error = GetPluginError ($plugin, $config);
		    if ($plugin_error) { last; }
		}
	    }
        }
	if ($plugin_error) {
	    $ret{"msg"}	= $plugin_error;
	    last;
	}
	# --------------------------------------------------------------------
    }
    if ($last_id != $last_uid && $user_config_dn ne "")  {
	# set nextuniqueid in user config module
	$user_config{"susenextuniqueid"}	= [ $last_id ];
	my %modules	= (
	    $user_config_dn => {
		"modified"	=> "edited"
	    }
	);
	$modules{$user_config_dn}{"susenextuniqueid"} =
	    $user_config{"susenextuniqueid"};
        my %new_ret = %{Ldap->WriteToLDAP (\%modules)};
	%ret    = %new_ret if not defined $ret{"msg"};
    }
    if (defined $ret{"msg"}) {
	my $msg 	= $ret{"msg"};
	if (defined $ret{"server_msg"} &&  $ret{"server_msg"} ne "") {
	    $msg	= "$msg\n".$ret{"server_msg"};
	}
	return $msg;
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

    my $self 		= shift;
    my %ret		= ();
    my $dn_attr 	= $group_naming_attr;
    my $last_id 	= $last_gid;
    my $groups		= $_[0];

    foreach my $groupname (keys %{$groups}) {

	my $group		= $groups->{$groupname};

        my $action      = $group->{"modified"};
        if (!defined ($action) || defined ($ret{"msg"})) {
            next; 
	}
	my $gid		= $group->{"gidnumber"};
	if (!defined $gid) { $gid	= GetDefaultGID (); }
	my %new_group	= ();
	my $dn		= $group->{"dn"}	|| "";
	my $org_dn	= $group->{"org_dn"} 	|| $dn;
	my $plugins	= $group->{"plugins"};
	my $plugins_to_remove	= $group->{"plugins_to_remove"};
	my $plugin_error	= "";

	my @obj_classes	= @group_class;
	if (defined $group->{"objectclass"} &&
	    ref ($group->{"objectclass"}) eq "ARRAY") {
	    @obj_classes= @{$group->{"objectclass"}};
	}
	my %o_classes	= ();
	foreach my $oc (@obj_classes) {
	    $o_classes{lc($oc)}	= 1;
	}
	my $group_oc	= "groupofnames";
	my $other_oc	= "groupofuniquenames";
	if (lc($member_attribute) eq "uniquemember") {
	    $group_oc	= "groupofuniquenames";
	    $other_oc	= "groupofnames";
	}
	# if there is no member of the group, group must be changed
	# to namedObject
	if ((!defined $group->{$member_attribute} ||
	     !%{$group->{$member_attribute}})
	    && defined $o_classes{$group_oc})
	{
	    if ($action eq "added" || $action eq "edited") {
		delete $o_classes{$group_oc};
		$o_classes{"namedobject"}	= 1;
	    }
	    if ($action eq "edited") {
		# delete old group and create new with altered objectclass
		%new_group	= %{$group};
		$action		= "deleted";
	    }
	}
	# we are adding users to empty group (=namedObject):
	# group must be changed to groupofuniquenames/groupofnames
	elsif (%{$group->{$member_attribute}} && $action eq "edited" &&
	       !defined $o_classes{$group_oc})
	{
	    # delete old group...
	    $action		= "deleted";
	    # ... and create new one with altered objectclass
	    delete $o_classes{"namedobject"};
	    $o_classes{$group_oc}	= 1;
	    if (defined $o_classes{$other_oc}) {
		delete $o_classes{$other_oc};
	    }
	    %new_group			= %{$group};
	}
	my @ocs		= ();
	foreach my $oc (keys %o_classes) {
	    if (Ldap->ObjectClassExists ($oc)) {
	        push @ocs, $oc;
	    }
	}
	$group->{"objectclass"}	= \@ocs;
	# ----------- now call the WriteBefore plugin function for this group
    
	if (!defined $plugins) {
	    $plugins	= \@default_group_plugins;
	}
	my $config	= {
	    "what"	=> "group",
	    "type"	=> "ldap",
	    "modified"	=> $action
	};
	if (defined $plugins_to_remove) {
	    $config->{"plugins_to_remove"}	= $plugins_to_remove;
	}
	# ---------- for deleted groups, get the list of all plugins using the
	# PluginPresent call (in add/edit cases, plugins were already read in
	# Users->Edit/Add functions)
	if (($group->{"modified"} || $action) eq "deleted") {
	    my $res = UsersPlugins->Apply ("PluginPresent", $config, $group);
	    if (defined ($res) && ref ($res) eq "HASH") {
		$plugins = [];
		foreach my $plugin (keys %{$res}) {
		    if (bool ($res->{$plugin}) &&
			!contains ($plugins, $plugin, 1)) {
			push @{$plugins}, $plugin;
		    }
		}
	    }
	}
	foreach my $plugin (sort @{$plugins}) {
	    $config->{"plugins"}	= [ $plugin ];
	    my $res = UsersPlugins->Apply ("WriteBefore", $config, $group);
	    if (!bool ($res->{$plugin})) {
		$plugin_error = GetPluginError ($plugin, $config);
		if ($plugin_error) { last; }
	    }
	}
	if (defined $plugins_to_remove && $plugin_error eq "") {
            foreach my $plugin (sort @{$plugins_to_remove}) {
                $config->{"plugins"}	= [ $plugin ];
                my $res = UsersPlugins->Apply ("WriteBefore", $config, $group);
		if (!bool ($res->{$plugin})) {
		    $plugin_error = GetPluginError ($plugin, $config);
		    if ($plugin_error) { last; }
		}
            }
        }
	if ($plugin_error) {
	    $ret{"msg"}	= $plugin_error;
	    last; # stop processing LDAP write...
	}
	# -------------------------------------------------------------------
	my $rdn			= "$dn_attr=".$group->{$dn_attr};
	my $new_dn		= "$rdn,$group_base";
	my %arg_map		= (
	    "dn"	=> $org_dn ne "" ? $org_dn : $new_dn
	);

        if ($action eq "added") {
	    if ($org_dn ne "") {
		$arg_map{"dn"}	= $new_dn;
	    }
	    if (!SCR->Write (".ldap.add",\%arg_map,$self->ConvertMap($group))) {
		%ret 		= %{Ldap->LDAPErrorMap ()};
	    }
	    elsif ($gid > $last_id) {
		$last_id	= $gid;
	    }
        }
        elsif ($action eq "deleted") {
	    if (!SCR->Write (".ldap.delete", \%arg_map)) {
		%ret 		= %{Ldap->LDAPErrorMap ()};
	    }
        }
        elsif ($action eq "edited") {

	    $arg_map{"check_attrs"}	= YaST::YCP::Boolean (1);

	    if (lc ($dn) ne lc ($org_dn)) {
		$arg_map{"rdn"}		= $rdn;
		$arg_map{"new_dn"}	= $dn;
	    }

	    if (!SCR->Write (".ldap.modify", \%arg_map, $self->ConvertMap($group))) {
		%ret 		= %{Ldap->LDAPErrorMap ()};
	    }
	    elsif ($gid > $last_id) {
		$last_id	= $gid;
	    }
        }
	if (defined $ret{"msg"}) {
	    last; # error on write
	}
	# ----------- now call the Write plugin function for this group
	foreach my $plugin (sort @{$plugins}) {
	    $config->{"plugins"}	= [ $plugin ];
	    my $res = UsersPlugins->Apply ("Write", $config, $group);
	    if (!bool ($res->{$plugin})) {
		$plugin_error = GetPluginError ($plugin, $config);
		if ($plugin_error) { last; }
	    }
	}
        if (defined $plugins_to_remove && $plugin_error eq "") {
	    foreach my $plugin (sort @{$plugins_to_remove}) {
                $config->{"plugins"}	= [ $plugin ];
                my $res = UsersPlugins->Apply ("Write", $config, $group);
		if (!bool ($res->{$plugin})) {
		    $plugin_error = GetPluginError ($plugin, $config);
		    if ($plugin_error) { last; }
		}
            }
	}
	if ($plugin_error) {
	    $ret{"msg"}	= $plugin_error;
	    last; # stop processing LDAP write...
	}
	# --------------------------------------------------------------------

	# now add a group whose object class was changed:
	if (%new_group) {
	    $config->{"modified"}	= "added";
	    foreach my $plugin (sort @{$plugins}) {
		$config->{"plugins"}	= [ $plugin ];
		my $res = UsersPlugins->Apply ("WriteBefore", $config, \%new_group);
		if (!bool ($res->{$plugin})) {
		    $plugin_error = GetPluginError ($plugin, $config);
		    if ($plugin_error) { last; }
		}
	    }
	    if (defined $plugins_to_remove && $plugin_error eq "") {
                foreach my $plugin (sort @{$plugins_to_remove}) {
                    $config->{"plugins"}	= [ $plugin ];
                    my $res = UsersPlugins->Apply ("WriteBefore", $config, \%new_group);
		    if (!bool ($res->{$plugin})) {
			$plugin_error = GetPluginError ($plugin, $config);
			if ($plugin_error) { last; }
		    }
                }
            }
	    if ($plugin_error) {
		$ret{"msg"}	= $plugin_error;
		last; # stop processing LDAP write...
	    }
	    # now add new group with modified objectclass
	    if (lc ($dn) ne lc ($org_dn)) {
		$arg_map{"dn"}	= $dn;
	    }
	    $new_group{"objectclass"}	= \@ocs;
	    # remove the org_group submap, we are adding new group:
	    delete $new_group{"org_group"};
	    if (!SCR->Write (".ldap.add", \%arg_map,
		$self->ConvertMap (\%new_group)))
	    {
		%ret 		= %{Ldap->LDAPErrorMap ()};
	    }
	    elsif ($gid > $last_id) {
		$last_id = $gid;
	    }
	    if (defined $ret{"msg"}) {
		last; # error on write
	    }

	    foreach my $plugin (sort @{$plugins}) {
		$config->{"plugins"}	= [ $plugin ];
		my $res = UsersPlugins->Apply ("Write", $config, \%new_group);
		if (!bool ($res->{$plugin})) {
		    $plugin_error = GetPluginError ($plugin, $config);
		    if ($plugin_error) { last; }
		}
	    }
	    if (defined $plugins_to_remove && $plugin_error eq "") {
                foreach my $plugin (sort @{$plugins_to_remove}) {
                    $config->{"plugins"}	= [ $plugin ];
                    my $res = UsersPlugins->Apply ("Write", $config, \%new_group);
		    if (!bool ($res->{$plugin})) {
			$plugin_error = GetPluginError ($plugin, $config);
			if ($plugin_error) { last; }
		    }
                }
            }
	    if ($plugin_error) {
		$ret{"msg"}	= $plugin_error;
		last; # stop processing LDAP write...
	    }
	}
    }
    if ($last_id != $last_gid && $group_config_dn ne "")  {
	# set nextuniqueid in group config module
	$group_config{"susenextuniqueid"}	= [ $last_id ];
	my %modules	= (
	    $group_config_dn => {
		"modified"	=> "edited"
	    }
	);
	$modules{$group_config_dn}{"susenextuniqueid"} =
	    $group_config{"susenextuniqueid"};
        my %new_ret = %{Ldap->WriteToLDAP (\%modules)};
	%ret    = %new_ret if not defined $ret{"msg"};
    }

    if (defined $ret{"msg"}) {
	my $msg 	= $ret{"msg"};
	if (defined $ret{"server_msg"} &&  $ret{"server_msg"} ne "") {
	    $msg	= "$msg\n".$ret{"server_msg"};
	}
	return $msg;
    }
    return "";
}

BEGIN { $TYPEINFO{SetGUI} = ["function", "void", "boolean"];}
sub SetGUI {
    my $self 		= shift;
    $use_gui 		= $_[0];
}

BEGIN { $TYPEINFO{SetLdapRead} = ["function", "void", "boolean"];}
sub SetLdapRead {
    my $self		= shift;
    $ldap_read		= $_[0];
}


1
# EOF
