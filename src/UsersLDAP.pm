#! /usr/bin/perl -w
#
# Users module TODO comment
## -------------------------------------------- ldap related routines 
#

package UsersLDAP;

use strict;

use ycp;
use YaST::YCP qw(Boolean);

our %TYPEINFO;

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

# current filters (must be empty on start):
my $user_filter 		= "";
my $group_filter 		= "";

# if filters were read (could be read without reading users and groups)
my $filters_read 		= 0;

# if ldap home directiories are on this machine
my $file_server			= 0;

# default shadow settings for LDAP users
my %shadow 			= ();

# other default settings (home, shell, etc.) for LDAP users
my %defaults 			= ();

# some default values for LDAP users
my $default_groupname 		= "";
my $default_grouplist 		= "";

# password encryption for LDAP users
my $encryption			= "crypt";

# default object classes of LDAP users (read from Ldap module)
my @user_class 			=
    ["top","posixAccount","shadowAccount", "inetOrgPerson"];

# default object classes of LDAP groups (read from Ldap module)
my @group_class 		=
    [ "top", "posixGroup", "groupOfUniqueNames"];

# naming attrributes (to be used when creating DN)
my $user_naming_attr 		= "uid";
my $group_naming_attr 		= "cn";

# last uid/gid used
my $last_uid 			= 0;
my $last_gid 			= 0;

# password to LDAP server
my $password			= "";

##------------------------------------
##------------------- global imports

YaST::YCP::Import ("Ldap");
YaST::YCP::Import ("SCR");
YaST::YCP::Import ("UsersCache");

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
    foreach my $source (split (/ /, $passwd_source)) {
	if ($source eq "ldap") { return 1; }
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

    my $ldap_mesg = Ldap::LDAPInit ();
    if ($ldap_mesg ne "") {
	# FIXME: how to solve UI-related routines?
	Ldap::LDAPErrorMessage ("init", $ldap_mesg);
	return 0;
    }

    if (!defined (Ldap::bind_pass ()) && !Ldap::anonymous ()) {
#	Ldap::bind_pass = Ldap::LDAPAskAndBind(true); FIXME
	$password = "q";
	Ldap::SetBindPassword ($password);
    }
    if (!defined (Ldap::bind_pass ())) {
	return 0; # canceled
    }

    Ldap::InitSchema ();

    my %modules = %{Ldap::ReadConfigModules ()};
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
    if (@user_templates > 1 || @group_templates > 1) {
	y2warning ("more templates"); # -> ReadTemplates function
#	term rbu_buttons = `VBox( `Left(`Label (_("User Templates"))));
#	term rbg_buttons = `VBox( `Left(`Label (_("Group Templates"))));
#	foreach (string templ, user_templates, ``{
#	    rbu_buttons = add (rbu_buttons,
#		`Left(`RadioButton (`id(templ), templ, true)));
#	});
#	foreach (string templ, group_templates, ``{
#	    rbg_buttons = add (rbg_buttons,
#		`Left(`RadioButton (`id(templ), templ, true)));
#	});
#	term rb_users = `RadioButtonGroup (`id(`rbu), rbu_buttons);
#	term rb_groups = `RadioButtonGroup (`id(`rbg), rbg_buttons);
#
#	UI::OpenDialog (`opt(`decorated), `HBox (`HSpacing (1),
#        `VBox(
#            `HSpacing(50),
#	    `VSpacing (0.5),
#	    // label
#            `Label (_("There are multiple templates defined as default. Select the one to read.")),
#	    `VSpacing (0.5),
#	    user_templates == [] ? `Empty(): rb_users,
#	    `VSpacing (0.5),
#	    group_templates == [] ? `Empty() : rb_groups,
#            `HBox(
#              `PushButton (`id(`ok),`opt(`key_F10, `default),
#		Label::OKButton()),
#              // button label
#              `PushButton (`id(`cancel),`opt(`key_F9), Label::CancelButton())
#            )),
#	`HSpacing (1))
#	);
#	any ret = UI::UserInput();
#	if (ret == `ok)
#	{
#	    if (user_templates != [])
#		user_template = (string) UI::QueryWidget (`id(`rbu), `CurrentButton);
#	    if (group_templates != [])
#		group_template = (string)UI::QueryWidget (`id(`rbg), `CurrentButton);
#	}
#	UI::CloseDialog();
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

    $file_server	= Ldap::file_server ();

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

    if (defined $user_config{"defaultObjectClass"}) {
	@user_class = @{$user_template{"defaultObjectClass"}};
    }

    if (defined $group_config{"defaultBase"}) {
	$group_base = $group_config{"defaultBase"}[0];
    }
    else {
	$group_base = Ldap::nss_base_passwd ();
    }
    if ($group_base eq "") {
	$group_base = $user_base;
    }

    if (defined $group_config{"defaultObjectClass"}) {
	@group_class = @{$group_template{"defaultObjectClass"}};
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
	    $shadow{"key"}	= $user_defaults{$key};
	}
	else {
	    $shadow{"key"}	= "";
	}
    }
	
#    # other defaults (for new users)
#    Users::ldap_defaults	= $[
#	"skel": user_config ["skelDir",0]:Users::default_skel,
#	"home": user_defaults ["homeDirectory"]:
#	    Users::GetDefaultHome(false,"local"),
#	"group": user_defaults["gidNumber"]:sformat ("%1",Users::default_gid),
#	"shell": user_defaults["loginShell"]:Users::GetDefaultShell("local"),
#    ];
#
#    # password length (there is no check if it is correct for curr. encryption)
#    if (user_config ["minPasswordLength"]:[] != [])
#	Users::pass_length ["ldap", "min"] =
#	    tointeger (user_config ["minPasswordLength",0]:"5");
#    if (user_config ["maxPasswordLength"]:"" != "")
#	Users::pass_length ["ldap", "max"] =
#	    tointeger (user_config ["maxPasswordLength",0]:"8");
#
#    # set default secondary groups
#    # WARNING: there are DN's, but we expect only names...
#    string grouplist = Users::ldap_default_grouplist;
#    foreach (string dn, user_template ["secondaryGroup"]:[], ``{
#	if (grouplist != "")
#	    grouplist = grouplist + ",";
#	grouplist = grouplist + get_first (dn);
#    });
#    Users::ldap_default_grouplist = grouplist;
#
    # last used Id
    if (defined ($user_config{"nextUniqueId"})) {
	$last_uid = $user_config{"nextUniqueId"}[0];
    }
    else {
	$last_uid = UsersCache::last_uid{"local"};
    }
#    UsersCache::last_uid ["ldap"] = Users::ldap_last_uid;

    if (defined ($group_config{"nextUniqueId"})) {
	$last_gid = $group_config{"nextUniqueId"}[0];
    }
    else {
	$last_gid = UsersCache::last_gid{"local"};
    }
#    UsersCache::last_gid ["ldap"] = Users::ldap_last_gid;

    # naming attributes
    if (defined ($user_template{"namingAttribute"})) {
        $user_naming_attr = $user_template{"namingAttribute"}[0];
    }
    if (defined ($group_template{"namingAttribute"})) {
        $group_naming_attr = $group_template{"namingAttribute"}[0];
    }

#    # max id
#    if (user_config ["maxUniqueId"]:[] != [])
#    {
#	Users::max_uid ["ldap"] = tointeger (
#	    user_config ["maxUniqueId",0]:"60000");
#    }
#    if (group_config ["maxUniqueId"]:[] != [])
#    {
#	Users::max_gid ["ldap"] = tointeger (
#	    group_config ["maxUniqueId",0]:"60000");
#    }
#    UsersCache::max_uid = Users::max_uid;
#    UsersCache::max_gid = Users::max_gid;
#
#    # min id
#    if (user_config ["minUniqueId"]:[] != [])
#    {
#	Users::min_uid ["ldap"] = tointeger (
#	    user_config ["minUniqueId",0]:"1000");
#	UsersCache::min_uid ["ldap"] = Users::min_uid ["ldap"]:1000;
#    }
#    if (group_config ["minUniqueId"]:[] != [])
#    {
#	Users::min_gid ["ldap"] = tointeger (
#	    group_config ["minUniqueId",0]:"1000");
#	UsersCache::min_gid ["ldap"] = Users::min_gid ["ldap"]:1000;
#    }
#
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
# do the LDAP search command; check the search filters before
sub Read {

    my $ret = "";

    my $user_filter = $user_filter ne "" ? $user_filter: $default_user_filter;
    my $group_filter = $group_filter ne ""? $group_filter:$default_group_filter;

    my @user_attrs	= ();
    my @group_attrs 	= ();
    # TODO use allowed/required attrs from config?
    # if yes, objectClass must be in required!

    my %args = (
	"user_base"	=> $user_base,
	"group_base"	=> $group_base,
	"user_filter"	=> $user_filter,
	"group_filter"	=> $group_filter,
	"user_scope"	=> 2,#sub
	"group_scope"	=> 2,
	"user_attrs"	=> @user_attrs,
	"group_attrs"	=> @group_attrs,
	"itemlists"	=> YaST::YCP::Boolean (1)
    );
    if (!SCR::Execute (".ldap.users.search", \%args)) {
	$ret = Ldap::LDAPError();
    }
    return $ret;
}


# EOF
