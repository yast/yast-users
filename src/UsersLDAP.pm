#! /usr/bin/perl -w
#
# UsersLDAP module:
# -- routines for handling LDAP users and groups
#

package UsersLDAP;

use strict;

use ycp;
use YaST::YCP qw(Boolean);

use Locale::gettext;
use POSIX ();     # Needed for setlocale()

POSIX::setlocale(LC_MESSAGES, "");
textdomain("users");

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

# keys in user's map which are not saved anywhere, they are used for internal
# purposes only
my @user_internal_keys		=
    ("create_home", "grouplist", "groupname", "modified", "org_username",
     "org_uid", "plugins", "text_userpassword",
     "org_uidnumber", "org_homedirectory","org_user", "type", "org_groupname",
     "org_type", "what", "encrypted", "no_skeleton", "disabled", "enabled",
     "dn", "org_dn", "removed_grouplist", "delete_home", "addit_data");

my @group_internal_keys		=
    ("modified", "type", "more_users", "s_userlist", "encrypted", "org_type",
     "dn", "org_dn", "org_groupname", "org_gidnumber", "removed_userlist",
     "what", "org_cn", "plugins");


# defualt scope for searching, set it by SetUserScope
my $user_scope			= 2;
my $group_scope			= 2;

 
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

##------------------------------------
# Initializes LDAP connection and reads users and groups configuration
# return value is error message
sub Initialize {

    Ldap->Read();
    Ldap->SetGUI ($use_gui);

    my $ldap_mesg = Ldap->LDAPInit ();
    if ($ldap_mesg ne "") {
	Ldap->LDAPErrorMessage ("init", $ldap_mesg);
	return $ldap_mesg;
    }
    if (!Ldap->anonymous () && !defined (Ldap->bind_pass ())) {
	y2error ("no password to LDAP - cannot bind!");
	# error message
	return _("No password to LDAP was entered");
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
    if (defined $user_config{"susesearchfilter"}) {
        $default_user_filter = @{$user_config{"susesearchfilter"}}[0];
    }
    if (defined $group_config{"susesearchfilter"}) {
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
    if (defined $user_config{"susedefaultbase"}) {
	$user_base = $user_config{"susedefaultbase"}[0];
    }
    else {
	$user_base = Ldap->nss_base_passwd ();
    }
    if ($user_base eq "") {
	$user_base = Ldap->GetDomain();
    }

    if (defined $group_config{"susedefaultbase"}) {
	$group_base = $group_config{"susedefaultbase"}[0];
    }
    else {
	$group_base = Ldap->nss_base_group ();
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

    # default shadow (for new LDAP users)
    foreach my $key ("shadowwarning", "shadowinactive", "shadowexpire", "shadowmin", "shadowmax", "shadowflag") {
	if (defined $user_defaults{$key}) {
	    $shadow{$key}	= $user_defaults{$key};
	}
	else {
	    $shadow{$key}	= "";
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
    if (defined $user_config{"suseskeldir"}) {
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
    if (defined ($user_config{"suseminpasswordlength"})) {
	$min_pass_length	= $user_config{"suseminpasswordlength"}[0];
    }
    if (defined ($user_config{"susemaxpasswordlength"})) {
	$max_pass_length	= $user_config{"susemaxpasswordlength"}[0];
    }

    # last used Id
    if (defined ($user_config{"susenextuniqueid"})) {
	$last_uid = $user_config{"susenextuniqueid"}[0];
    }
    else {
	$last_uid = UsersCache->GetLastUID ("local");
    }
    UsersCache->SetLastUID ($last_uid, "ldap");

    if (defined ($group_config{"susenextuniqueid"})) {
	$last_gid = $group_config{"susenextuniqueid"}[0];
    }
    else {
	$last_gid = UsersCache->GetLastGID ("local");
    }
    UsersCache->SetLastGID ($last_gid, "ldap");

    # naming attributes
    if (defined ($user_template{"susenamingattribute"})) {
        $user_naming_attr = $user_template{"susenamingattribute"}[0];
    }
    if (defined ($group_template{"susenamingattribute"})) {
        $group_naming_attr = $group_template{"susenamingattribute"}[0];
    }

    # max id
    if (defined ($user_config{"susemaxuniqueid"})) {
	$max_uid	= $user_config{"susemaxuniqueid"}[0];
    }
    if (defined ($group_config{"susemaxuniqueid"})) {
	$max_gid	= $group_config{"susemaxuniqueid"}[0];
    }
    UsersCache->SetMaxUID ($max_uid, "ldap");
    UsersCache->SetMaxGID ($max_gid, "ldap");

    # min id
    if (defined ($user_config{"suseminuniqueid"})) {
	$min_uid	= $user_config{"suseminuniqueid"}[0];
    }
    if (defined ($group_config{"suseminuniqueid"})) {
	$min_gid	= $group_config{"suseminuniqueid"}[0];
    }
    UsersCache->SetMinUID ($min_uid, "ldap");
    UsersCache->SetMinGID ($min_gid, "ldap");

    if (defined ($user_config{"susepasswordhash"})) {
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

    # TODO use allowed/required attrs from config?
    # (if yes, objectclass must be in required!)
    # For now, we get all:
    my $user_attrs	= \@user_attributes;
#    my $user_attrs	= [ "uid", "uidnumber", "gidnumber", "gecos", "cn", "homedirectory" ];
    my $group_attrs 	= \@group_attributes;

    my %args = (
	"user_base"		=> $user_base,
	"group_base"		=> $group_base,
	"user_filter"		=> $user_filter,
	"group_filter"		=> $group_filter,
	"user_scope"		=> YaST::YCP::Integer ($user_scope),
	# 2 = sub - TODO configurable?
	"group_scope"		=> YaST::YCP::Integer ($group_scope),
	"user_attrs"		=> $user_attrs,
	"group_attrs"		=> $group_attrs,
	"member_attribute"	=> $member_attribute
    );
y2internal ("user at: ", @{$user_attrs});
y2internal ("group at: ", @{$group_attrs});
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
    if (defined $_[0] && ref ($_[0]) eq "HASH") {
	%useradd_defaults	= %{$_[0]};
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
BEGIN { $TYPEINFO{SetUserAttributes} = ["function", "void",["list", "string"]];}
sub SetUserAttributes {
    my $self	= shift;
    if (ref ($_[0]) eq "ARRAY") {
	@user_attributes	= @{$_[0]};
    }
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
BEGIN { $TYPEINFO{SetUserScope} = ["function", "void", "integer"];}
sub SetUserScope {
    my $self = shift;
    $user_scope = $_[0];
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
BEGIN { $TYPEINFO{SetGroupScope} = ["function", "void", "integer"];}
sub SetGroupScope {
    my $self = shift;
    $group_scope = $_[0];
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


##------------------------------------
# Convert internal map describing user or group to map that could be passed to
# ldap-agent (remove internal keys, rename attributes etc.)
# @param map of user or group
# @return converted map
sub ConvertMap {

    my $self		= shift;
    my $data		= $_[0];
    my %ret		= ();
    my @attributes	= ();
    my $attributes	= Ldap->GetObjectAttributes ($data->{"objectclass"});
    if (defined $attributes && ref ($attributes) eq "ARRAY") {
	@attributes	= @{$attributes};
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
	    if ($val eq "x" || $val eq "*") {
		next;
	    }
	    my $enc	= lc ($encryption);
	    if ($enc ne "clear" && !($val =~ m/^{$enc}/)) {
		$val = sprintf ("{%s}%s", lc ($encryption), $val);
	    }
	}
	# check if the attributes are allowed by objectclass
	if (!contains (\@attributes, $key, 1)) {
	    y2warning ("Attribute '$key' is not allowed by schema");
	    next;
	}
	if ($key eq $member_attribute && ref ($val) eq "HASH") {
	    my @lval	= ();
	    foreach my $u (keys %{$val}) {
		push @lval, $u;
	    }
	    $val = \@lval;
	}
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

    foreach my $uid (keys %{$users}) {

	my $user		= $users->{$uid};

        my $action      = $user->{"modified"};
        if (!defined ($action) || defined ($ret{"msg"})) {
            next; 
	}
        my $home	= $user->{"homedirectory"} || "";
        my $org_home	= $user->{"org_user"}{"homedirectory"} || $home;
        my $gid		= $user->{"gidnumber"} || GetDefaultGID ();
	my $create_home	= bool ($user->{"create_home"});
	my $delete_home	= bool ($user->{"delete_home"});
	my $enabled	= bool ($user->{"enabled"});
	my $disabled	= bool ($user->{"disabled"});
	my $plugins	= $user->{"plugins"};
	my $plugins_to_remove	= $user->{"plugins_to_remove"};

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
	foreach my $oc (@obj_classes) {
	    if (Ldap->ObjectClassExists ($oc)) {
		push @ocs, $oc;
	    }
	}
	$user->{"objectclass"}	= \@ocs;
	# now internal attributes are removed from user's map
	$user			= $self->ConvertMap ($user);
	my $rdn			= "$dn_attr=".$user->{$dn_attr};
	my $new_dn		= "$rdn,$user_base";
	my %arg_map		= (
	    "dn"	=> $org_dn ne "" ? $org_dn : $new_dn
	);

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
	    
	foreach my $plugin (sort @{$plugins}) {
	    $config->{"plugins"}	= [ $plugin ];
	    my $res = UsersPlugins->Apply ("WriteBefore", $config, $user);
#TODO check the return value?
	}

	# --------------------------------------------------------------------
        if ($action eq "added") {
	    if (! SCR->Write (".ldap.add", \%arg_map, $user)) {
		%ret	= %{Ldap->LDAPErrorMap ()};
	    }
            # on server, we can modify homes
            else {
		if ($uid > $last_id) {
		    $last_id = $uid;
		}
		if ($server) {
		    if ($create_home) {
			UsersRoutines->CreateHome ($useradd_defaults{"skel"}, $home);
		    }
		    UsersRoutines->ChownHome ($uid, $gid, $home);
		}
	    }
        }
        elsif ($action eq "deleted") {
	    if (! SCR->Write (".ldap.delete", \%arg_map)) {
		%ret = %{Ldap->LDAPErrorMap ()};
	    }
            elsif ($server && $delete_home) {
                UsersRoutines->DeleteHome ($home);
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
	    if (! SCR->Write (".ldap.modify", \%arg_map, $user)) {
		%ret = %{Ldap->LDAPErrorMap ()};
	    }
	    else {
		if ($uid > $last_id) {
		    $last_id = $uid;
		}
		if ($server && $home ne $org_home) {
		    if ($create_home) {
			UsersRoutines->MoveHome ($org_home, $home);
		    }
		    UsersRoutines->ChownHome ($uid, $gid, $home);
		}
            }
        }
	# ----------- now call the "write" plugin function for this user
	if (!defined $ret{"msg"}) {
	    foreach my $plugin (sort @{$plugins}) {
		$config->{"plugins"}	= [ $plugin ];
		my $res = UsersPlugins->Apply ("WriteBefore", $config, $user);
	    }
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
        %ret = %{Ldap->WriteToLDAP (\%modules)};
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

    my $self 		= shift;
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
	my $plugins	= $group->{"plugins"};
	my $plugins_to_remove	= $group->{"plugins_to_remove"};

	my @obj_classes	= @group_class;
	if (defined $group->{"objectclass"} &&
	    ref ($group->{"objectclass"}) eq "ARRAY") {
	    @obj_classes= @{$group->{"objectclass"}};
	}
	my %o_classes	= ();
	foreach my $oc (@obj_classes) {
	    $o_classes{$oc}	= 1;
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
	    if (contains (\@obj_classes, $other_oc, 1)) {
		foreach my $o (keys %o_classes) {
		    if (lc ($o) eq $other_oc) { $other_oc = $o; }
		}
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
	$group			= $self->ConvertMap ($group);

	my $rdn			= "$dn_attr=".$group->{$dn_attr};
	my $new_dn		= "$rdn,$group_base";
	my %arg_map		= (
	    "dn"	=> $org_dn ne "" ? $org_dn : $new_dn
	);

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
	foreach my $plugin (sort @{$plugins}) {
	    $config->{"plugins"}	= [ $plugin ];
	    my $res = UsersPlugins->Apply ("WriteBefore", $config, $group);
	}
	# -------------------------------------------------------------------
	
        if ($action eq "added") {
	    if (!SCR->Write (".ldap.add", \%arg_map, $group)) {
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

	    if (!SCR->Write (".ldap.modify", \%arg_map, $group)) {
		%ret 		= %{Ldap->LDAPErrorMap ()};
	    }
	    elsif ($gid > $last_id) {
		$last_id	= $gid;
	    }
        }
	# ----------- now call the Write plugin function for this group
	if (!defined $ret{"msg"}) {
	    foreach my $plugin (sort @{$plugins}) {
		$config->{"plugins"}	= [ $plugin ];
		my $res = UsersPlugins->Apply ("WriteBefore", $config, $group);
	    }
	}
	# --------------------------------------------------------------------

	# now add a group whose object class was changed:
	if (%new_group && !%ret) {
	    $config->{"modified"}	= "added";
	    foreach my $plugin (sort @{$plugins}) {
		$config->{"plugins"}	= [ $plugin ];
		my $res = UsersPlugins->Apply ("WriteBefore", $config, \%new_group);
	    }
	    # now add new group with modified objectclass
	    if (lc ($dn) ne lc ($org_dn)) {
		$arg_map{"dn"}	= $dn;
	    }
	    $new_group{"objectclass"}	= \@ocs;
	    if (!SCR->Write (".ldap.add", \%arg_map,
		$self->ConvertMap (\%new_group)))
	    {
		%ret 		= %{Ldap->LDAPErrorMap ()};
	    }
	    elsif ($gid > $last_id) {
		$last_id = $gid;
	    }
	    foreach my $plugin (sort @{$plugins}) {
		$config->{"plugins"}	= [ $plugin ];
		my $res = UsersPlugins->Apply ("Write", $config, \%new_group);
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
        %ret = %{Ldap->WriteToLDAP (\%modules)};
    }

    if (%ret) {
	return $ret{"msg"};
    }
    return "";
}

BEGIN { $TYPEINFO{SetGUI} = ["function", "void", "boolean"];}
sub SetGUI {
    my $self 		= shift;
    $use_gui 		= $_[0];
}

1
# EOF
