#! /usr/bin/perl -w
#
# Users module written in Perl
#

#TODO do not dereference large map if not necessary...

package Users;

use strict;

# FIXME should be found in defualt place...?
use lib '/usr/lib/perl5/vendor_perl/5.8.1/i586-linux-thread-multi/YaST';
use ycp;
use YCP;

#use io_routines;
#use check_routines;

our %TYPEINFO;


my $default_groupname		= "users";

my @user_sources		= ();

my %users			= (
    "system"		=> (),
    "local"		=> (),
);

my %shadow			= (
    "system"		=> (),
    "local"		=> (),
);

my %groups			= (
    "system"		=> (),
    "local"		=> (),
);

my %users_by_name		= (
    "system"		=> (),
    "local"		=> (),
);
my %groups_by_name		= (
    "system"		=> (),
    "local"		=> (),
);

my %removed_homes		= ();

my %removed_users		= ();
my %removed_groups		= ();

my %user_in_work		= ();
my %group_in_work		= ();

# the first user, added during installation
my %saved_user			= ();

my %useradd_defaults		= (
    "group"		=> "500",
    "home"		=> "/home",
    "inactive"		=> "",
    "expire"		=> "",
    "shell"		=> "",
    "skel"		=> "",
    "groups"		=> "audio,video,uucp,dialout",
);

my $tmpdir			= "/tmp";
# which sets of users are available:
my @available_usersets		= [ "system", "local"];
my @available_groupsets		= [ "system", "local"];

# list of available shells (read from /etc/shells)
my @all_shells 			= ();


my $users_modified		= 0;
my $groups_modified		= 0;
my $ldap_modified		= 0;
my $customs_modified 		= 0;
my $defaults_modified 		= 0;
my $security_modified 		= 0;

my $is_nis_master		= 0;

# TODO - move to UsersCache?
my $useradd_cmd 		= "";
my $userdel_precmd 		= "";
my $userdel_postcmd 		= "";

my $pass_warn_age		= "7";
my $pass_min_days		= "0";
my $pass_max_days		= "99999";

# password encryption method
my $encryption_method		= "des";
my $use_cracklib 		= 0;
my $cracklib_dictpath		= "";
my $obscure_checks 		= 0;

# starting dialog for installation mode
my $start_dialog		= "summary";
my $use_next_time		= 0;

# which sets of users are we working with:
my @current_users		= ();
my @current_groups 		= ();

# mail alias for root
my $root_mail			= "";
 
##------------------------------------
##------------------- global imports

YaST::YCP::Import ("SCR");
YaST::YCP::Import ("Autologin");
YaST::YCP::Import ("Mode");
YaST::YCP::Import ("Security");
YaST::YCP::Import ("UsersCache");

##-------------------------------------------------------------------------
##----------------- various routines --------------------------------------


BEGIN { $TYPEINFO{LastChangeIsNow} = ["function", "string"]; }
sub LastChangeIsNow {
    return sprintf ("%u", `date +%s` / (60*60*24));
}


BEGIN { $TYPEINFO{DebugMap} = ["function",
    "void",
    [ "map", "string", "string"]];
}
sub DebugMap {
    UsersCache::DebugMap (@_);
}

BEGIN { $TYPEINFO{Modified} = ["function", "boolean"];}
sub Modified {

    my $ret =	$users_modified 	||
		$groups_modified	||
		$ldap_modified		||
		$customs_modified	||
		$defaults_modified	||
		$security_modified;

    return $ret ? "true" : "false";
}

BEGIN { $TYPEINFO{GetRootMail} = ["function", "string"]; }
sub GetRootMail {
    return $root_mail;
}

BEGIN { $TYPEINFO{SetRootMail} = ["function", "void", "string"]; }
sub SetRootMail {
    $root_mail = $_[0];
}


BEGIN { $TYPEINFO{GetStartDialog} = ["function", "string"]; }
sub GetStartDialog {
    return $start_dialog;
}

BEGIN { $TYPEINFO{StartDialog} = ["function", "boolean", "string"]; }
sub StartDialog {
    return $start_dialog eq $_[0] ? "true" : "false";
}

BEGIN { $TYPEINFO{SetStartDialog} = ["function", "void", "string"]; }
sub SetStartDialog {
    $start_dialog = $_[0];
}

BEGIN { $TYPEINFO{UseNextTime} = ["function", "boolean"]; }
sub UseNextTime {
    return $use_next_time;
}

BEGIN { $TYPEINFO{SetUseNextTime} = ["function", "void", "boolean"]; }
sub SetUseNextTime {
    $use_next_time = $_[0];
#TODO    $use_next_time = Boolean ($_[0]);
}


BEGIN { $TYPEINFO{GetAvailableUserSets} = ["function", ["list", "string"]]; }
sub GetAvailableUserSets {
    return \@available_usersets;
}

BEGIN { $TYPEINFO{GetAvailableGroupSets} = ["function", ["list", "string"]]; }
sub GetAvailableGroupSets {
    return \@available_groupsets;
}
    
BEGIN { $TYPEINFO{ChangeCustoms} = ["function",
    "void",
    "string", ["list","string"]];
}
sub ChangeCustoms {

    #TODO
}

BEGIN { $TYPEINFO{GetCurrentUsers} = ["function", ["list", "string"]]; }
sub GetCurrentUsers {
    return \@current_users;
}

BEGIN { $TYPEINFO{ChangeCurrentUsers} = ["function", "boolean", "string"];}
sub ChangeCurrentUsers {
    return "true";
#TODO
}

BEGIN { $TYPEINFO{CryptPassword} = ["function", "string", "string", "string"];}
sub CryptPassword {
    return $_[0]."FIXME";
}

BEGIN { $TYPEINFO{EncryptionMethod} = ["function", "string"];}
sub EncryptionMethod {
    return $encryption_method;
}

BEGIN { $TYPEINFO{AllShells} = ["function", ["list", "string"]];}
sub AllShells {
    return @all_shells;
}


    
##------------------------------------
#sub contains {
#
#    foreach my $key (@{$_[0]}) {
#	if ($key eq $_[1]) { return 1; }
#    }
#    return 0;
#}

##------------------------------------
BEGIN { $TYPEINFO{CheckHomeMounted} = ["function", "void"]; }
# Checks if the home directory is properly mounted (bug #20365)
sub CheckHomeMounted {

#    if ( Mode::live_eval ) {
#	return "";
#    }

    my $ret 		= "";
    my $mountpoint_in	= "";
    my $home 		= GetDefaultHome ("local");
    if (substr ($home, -1, 1) eq "/") {
	chop $home;
    }

#    my @fstab = SCR::Read (".etc.fstab");
#    foreach my %line (@fstab) {
#        if ($line{"file"} eq $home) {
#            $mountpoint_in = "/etc/fstab";
#	}
#    };

#    if (-e "/etc/cryptotab") {
#        my @cryptotab = SCR::Read (".etc.cryptotab");
#	foreach my %line (@cryptotab) {
#            if ($line{"mount"} eq $home) {
#		$mountpoint_in = "/etc/cryptotab";
#	    }
#        });
#    }

    if ($mountpoint_in ne "") {
        my $mounted	= 0;
#        my @mtab	= SCR::Read (".etc.mtab");
#	foreach my %line (@mtab) {
#	    if ($line{"file"} eq $home) {
#                $mounted = 1;
#	    }
#        };

        if (!$mounted) {
#            return Popup::YesNo(
#// Popup text: %1 is the directory (e.g. /home), %2 file name (e.g. /etc/fstab)
#// For more info, look at the bug #20365
#sformat(_("In %2, there is a mount point for the directory
#%1, which is used as a default home directory for new
#users, but this directory is not currently mounted.
#If you add new users using the default values,
#their home directories will be created in the current %1.
#This can imply that these directories will not be accessible
#after you mount correctly. Continue user configuration?
#"), home, mountpoint_in));
	}
    }
    return $ret;
}


##-------------------------------------------------------------------------
##----------------- get routines ------------------------------------------

##------------------------------------
BEGIN { $TYPEINFO{GetMinUID} = ["function",
    "integer",
    "string"]; #user type
}
sub GetMinUID {

    return UsersCache::GetMinUID ($_[0]);
}

##------------------------------------
BEGIN { $TYPEINFO{GetMaxUID} = ["function",
    "integer",
    "string"]; #user type
}
sub GetMaxUID {

    return UsersCache::GetMaxUID ($_[0]);
}


##------------------------------------
BEGIN { $TYPEINFO{GetDefaultGrouplist} = ["function",
    ["map", "string", "string"],
    "string"];
}
sub GetDefaultGrouplist {

    my $type		= $_[0];
    my %grouplist	= ();

    if ($type eq "local") {
	foreach my $group (split (/,/, $useradd_defaults{"groups"})) {
	    $grouplist{$group}	= 1;
	}
    }
    else {
#	@grouplist	= split (/,/, $useradd_defaults{"groups"});#TODO LDAP
    }
    return \%grouplist;
}

##------------------------------------
BEGIN { $TYPEINFO{GetDefaultGID} = ["function", "integer", "string"]; }
sub GetDefaultGID {

    my $type	= $_[0];
    my $gid	= $useradd_defaults{"group"};

    if ($type eq "ldap") {
#	$gid	= $ldap_defaults{"group"}; #TODO LDAP
    }
    else {
	# set also default group name
	my %group	= %{GetGroup ($gid, "local")};
        if (!%group) {
	    %group	= %{GetGroup ($gid, "system")};
	}
        if (%group) {
	    $default_groupname	= $group{"groupname"};
	}
    }
    return $gid;
}

##------------------------------------
BEGIN { $TYPEINFO{GetDefaultShell} = ["function", "string", "string"]; }
sub GetDefaultShell {

    my $type = $_[0];

    if ($type eq "ldap") {
	return "/bin/bash";#TODO LDAP
    }
    else {
        return $useradd_defaults{"shell"};
    }
}

##------------------------------------
BEGIN { $TYPEINFO{GetDefaultHome} = ["function", "string", "string"]; }
sub GetDefaultHome {

    my $home = $useradd_defaults{"home"} || "";

    if ($_[0] eq "ldap") {
	$home	= "/home/";
    }
    if (substr ($home, -1, 1) ne "/") {
	$home.="/";
    }
    return $home;
}

##------------------------------------
BEGIN { $TYPEINFO{GetDefaultShadow} = ["function",
    [ "map", "string", "string"],
    "string"];
}
sub GetDefaultShadow {

    my $type = $_[0];

    if ($type eq "ldap") {
	return {};
    }
    else {
        return (
            "shadowInactive"	=> $useradd_defaults{"inactive"},
            "shadowExpire"      => $useradd_defaults{"expire"},
            "shadowWarning"     => $pass_warn_age,
            "shadowMin"         => $pass_min_days,
            "shadowMax"         => $pass_max_days,
            "shadowFlag"        => "",
            "shadowLastChange"	=> "",
	    "userPassword"	=> ""
	);
    }
}


##------------------------------------
BEGIN { $TYPEINFO{GetDefaultGroupname} = ["function", "string", "string"]; }
sub GetDefaultGroupname {

    my $type = $_[0];

    if ($type eq "ldap") {
	return "lusers";
    }
    else {
        return $default_groupname;
    }
}

##------------------------------------
BEGIN { $TYPEINFO{GetUser} = [ "function",
    ["map", "string", "any" ],
    "integer", "string"]; # uid, type (can be empty string)
}
sub GetUser {

    my $uid		= $_[0];
    my @types_to_look	= ($_[1]);
    if ($_[1] eq "") {
	@types_to_look = keys %users;
    }

    foreach my $type (@types_to_look) {
	if (defined $users{$type}{$uid}) {
	    return $users{$type}{$uid};
	}
    }
    return {};
}

##------------------------------------
BEGIN { $TYPEINFO{GetCurrentUser} = [ "function", ["map", "string", "any" ]];}
sub GetCurrentUser {
    return \%user_in_work;
}

##------------------------------------
# must be called before each Add...
BEGIN { $TYPEINFO{ResetCurrentUser} = [ "function", "void" ];}
sub ResetCurrentUser {
    undef %user_in_work;
}

##------------------------------------
BEGIN { $TYPEINFO{SaveCurrentUser} = [ "function", "void" ];}
sub SaveCurrentUser {
    %saved_user = %user_in_work;
}

##------------------------------------
BEGIN { $TYPEINFO{RestoreCurrentUser} = [ "function", "void" ];}
sub RestoreCurrentUser {
    %user_in_work = %saved_user;
}


BEGIN { $TYPEINFO{GetCurrentGroup} = [ "function", ["map", "string", "any" ]];}
sub GetCurrentGroup {
    return \%group_in_work;
}

##------------------------------------
BEGIN { $TYPEINFO{ResetCurrentGroup} = [ "function", "void" ];}
sub ResetCurrentGroup {
    undef %group_in_work;
}

##------------------------------------
# Returns the map of users specified by its name
# @param name user's identification (username or DN)
# @param type (can be empty string)
# @return the desired user's map
BEGIN { $TYPEINFO{GetUserByName} = [ "function",
    ["map", "string", "any" ],
    "string", "string"];
}
sub GetUserByName {

    my $username	= $_[0];
#    if (issubstring (name, "=")) #TODO LDAP
#	name = get_first (name);

    my @types_to_look	= ($_[1]);
    if ($_[1] eq "") {
	@types_to_look = keys %users_by_name;
    }
    
    foreach my $type (@types_to_look) {
	if (defined $users_by_name{$type}{$username}) {
	    return GetUser ($users_by_name{$type}{$username}, $type);
	}
    }
    return {};
}


##------------------------------------
BEGIN { $TYPEINFO{GetGroup} = [ "function",
    ["map", "string", "any" ],
    "integer", "string"];
}
sub GetGroup {

    my $gid		= $_[0];
    my @types_to_look	= ($_[1]);
    if ($_[1] eq "") {
	@types_to_look = keys %groups;
    }

    foreach my $type (@types_to_look) {
	if (defined $groups{$type}{$gid}) {
	    return $groups{$type}{$gid};
	}
    }
    return {};
}

##------------------------------------
# Gets the first group with given name
BEGIN { $TYPEINFO{GetGroupByName} = [ "function",
    ["map", "string", "any" ],
    "string", "string"];
}
sub GetGroupByName {

    my $groupname	= $_[0];
    my $type		= $_[1];

    # NOTE: different behaviour than GetUserByName:
    # Given user type is checked for first, but the other follow.
    # The only reason for "type" argument is to get the (probably) right
    # group as first (e.g. there are 2 'users' groups - local and ldap).
    my @types_to_look	= (keys %groups_by_name);
    if ($_[1] ne "") {
	unshift @types_to_look, $_[1];
    }
    
    foreach my $type (@types_to_look) {
	if (defined $groups_by_name{$type}{$groupname}) {
	    return GetGroup ($groups_by_name{$type}{$groupname}, $type);
	}
    }
    return {};
}



##------------------------------------
# returns the groups of a given user
# @param map of user
sub FindGroupsBelongUser {
    
    my %grouplist	= ();
    my $user		= $_[0];

    foreach my $type (keys %groups) {

	my $uname	= $user->{"username"};
	if ($type eq "ldap") {# LDAP groups have list of user DN's
	    $uname	= $user->{"dn"};
	}
	if (!defined $uname) { next; }
        foreach my $gid (keys %{$groups{$type}}) {

	    my $group	= $groups{$type}{$gid};
            my $userlist = $group->{"userlist"};
	    if ($type eq "ldap") { 
		$userlist = $group->{"uniqueMember"};
	    }
            if (defined $userlist->{$uname}) {
		$grouplist{$group->{"groupname"}}	= 1;
            }

#	    my %group	= %{$groups{$type}{$gid}}; # ref?
#            my %userlist = %{$group{"userlist"}};
#	    if ($type eq "ldap") { 
#		%userlist = %{$group{"uniqueMember"}};
#	    }
#            if (%userlist && defined $userlist{$uname}) {
#		$grouplist{$group{"groupname"}}	= 1;
#            }
        };
    };
    return \%grouplist;
}

##-------------------------------------------------------------------------
##----------------- read routines -----------------------------------------

# Read the /etc/shells file and return a item list or a string shell list.
# @param todo `items or `stringlist
# @return list of shells
sub ReadAllShells {

    my @available_shells	= ();
    my $shells_s = SCR::Read (".target.string", "/etc/shells");
    my @shells_read = split (/\n/, $shells_s);

    foreach my $shell_entry (@shells_read) {

	if ($shell_entry eq "" || $shell_entry =~ m/^passwd|bash1$/) {
	    next;
	}
	if (-e $shell_entry) {
	    push @all_shells, $shell_entry;
	}
    };
}

##------------------------------------
# Checks the possible user sources (NIS/LDAP available?)
BEGIN { $TYPEINFO{ReadSourcesSettings} = ["function", "void"]; }
sub ReadSourcesSettings {

    @available_usersets		= [ "local", "system" ];
    @available_groupsets	= [ "local", "system" ];

    my $is_nis_available	= 1;#FIXME IsNISAvailable ();
    $is_nis_master 		= 0;#IsNISMaster ();
    my $is_ldap_available 	= 1;#IsLDAPAvailable ();

    if (!$is_nis_master && $is_nis_available) {
        push @available_usersets, "nis";
        push @available_groupsets, "nis";
    }
    if ($is_ldap_available) {
        push @available_usersets, "ldap";
        push @available_groupsets, "ldap";
    }
    push @available_usersets, "custom";
    push @available_groupsets, "custom";
}


##------------------------------------
BEGIN { $TYPEINFO{ReadSystemDefaults} = ["function", "void"]; }
sub ReadSystemDefaults {

    Security::Read ();

    my %security	= %{Security::Export ()};
    # TODO move these variables to UsersCache?
    $pass_warn_age	= $security{"PASS_WARN_AGE"};
    $pass_min_days	= $security{"PASS_MIN_DAYS"};
    $pass_max_days	= $security{"PASS_MAX_DAYS"};

    # command running before/after adding/deleting user
    $useradd_cmd 	= $security{"USERADD_CMD"};
    $userdel_precmd 	= $security{"USERDEL_PRECMD"};
    $userdel_postcmd 	= $security{"USERDEL_POSTCMD"};

    $encryption_method	= $security{"PASSWD_ENCRYPTION"};
    $use_cracklib 	= ($security{"PASSWD_USE_CRACKLIB"} eq "yes");
    $cracklib_dictpath	= $security{"CRACKLIB_DICTPATH"};
    $obscure_checks 	= ($security{"OBSCURE_CHECKS_ENAB"} eq "yes");

#    $min_pass_length{"local"} = $security{"PASS_MIN_LEN"};
#    $min_pass_length{"system"} = $security{"PASS_MIN_LEN"};
#
#    pass_length {"local", "max"} = (encryptionMethod != "des") ?
#	    Security::PasswordMaxLengths {encryptionMethod}:8 :
#	    tointeger ($security {"PASS_MAX_LEN"}:"8");

}

##------------------------------------
BEGIN { $TYPEINFO{ReadLoginDefaults} = ["function", "void"]; }
sub ReadLoginDefaults {

    foreach my $key (keys %useradd_defaults) {
        my $entry = SCR::Read (".etc.default.useradd.$key");#FIXME (agent-ini?)
        if (!$entry) {
	    $entry = "";
	}
	$entry =~ s/\"//g;
        $useradd_defaults{$key} = $entry;
    }

    if (%useradd_defaults) {
        return "true";
    }
    return "false";
}

##------------------------------------
# Read new set of users - "on demand" (called from running module)
# @param type the type of users, currently "ldap" or "nis"
# @return success
sub ReadNewSet {

    my $type	= $_[0];
    if ($type eq "nis") {

#        $nis_not_read = 0;
#        users ["nis"] = ReadNISUsers (tmpdir);
#        users_by_name ["nis"] = ReadNISUsersByName (tmpdir);
#        groups ["nis"] = ReadNISGroups (tmpdir);
#        groups_by_name ["nis"] = ReadNISGroupsByName (tmpdir);
    }
    elsif ($type eq "ldap") {

#	# read all needed LDAP settings now:
#	if (!ReadLDAPSettings ()) {
#	    return 0;
#	}
#
#	my $ldap_mesg = ReadLDAP();
#	if ($ldap_mesg ne "") {
#            Ldap::LDAPErrorMessage ("read", $ldap_mesg);
#	    # TODO error as return value?
#            return 0;
#        }
#        $ldap_not_read = 0;

	# ---------------------- testing (without using Ldap module):
	
	# init:
	my %args = ( "hostname" => "localhost" );
	SCR::Execute (".ldap", \%args);
	
	# bind:
	%args = (
	    "bind_dn"	=> "uid=jirka,dc=suse,dc=cz",
	    "bind_pw"	=> "q"
	);
	SCR::Execute (".ldap.bind", \%args);

	%args = (
	    "base_dn"		=> "ou=ldapconfig,dc=suse,dc=cz",
	    "filter"		=> "objectClass=objectTemplate",
	    "scope"		=> 2, # sub: all templates under config DN
	    "map"		=> 1, #true, FIXME how to pass boolean value?
	    "not_found_ok"	=> 1, #true,
	);
#	my @templates = @{SCR::Read (".ldap.search", \%args)};
	my %templates = %{SCR::Read (".ldap.search", \%args)};
#	DebugMap (\%{$templates[0]});
#	DebugMap (\%templates);

	# generate users structures:
	%args =	(
	    "user_base"	=> "ou=Users,dc=suse,dc=cz",
	    "group_base"	=> "ou=Groups,dc=suse,dc=cz",
	    "user_filter"	=> "objectClass=posixAccount",
	    "group_filter"	=> "objectClass=posixGroup",
	    "user_scope"	=> 2,
	    "group_scope"	=> 2,
#	    "user_attrs"	=> ldap_user_attrs,
#	    "group_attrs"	=> ldap_group_attrs,
	    "itemlists"		=> 1
	);
	SCR::Execute (".ldap.users.search", \%args);

	my %lu = %{SCR::Read(".ldap.users")};
#	DebugMap (\%{$lu{500}});
#	DebugMap (\%{$lu{510}});
    }
    UsersCache::ReadUsers ($type);
    UsersCache::ReadGroups ($type);

    return 1;
}


##------------------------------------
BEGIN { $TYPEINFO{ReadLocal} = ["function", "void"]; }
sub ReadLocal {

    my %id_limits = (
	"max_system_uid"	=> UsersCache::GetMaxUID ("system"),
	"max_system_gid"	=> UsersCache::GetMaxGID ("system"),
    );
    # id limits are necessary for differ local and system users
    SCR::Execute (".passwd.init", \%id_limits);
#    %users		= %{SCR::Read (".passwd.users")};
#    %users_by_name	= %{SCR::Read (".passwd.users.by_name")};
#    %shadow		= %{SCR::Read (".passwd.shadow")};
#    %groups		= %{SCR::Read (".passwd.groups")};
#    %groups_by_name	= %{SCR::Read (".passwd.groups.by_name")};

    foreach my $type ("local", "system") {
	$users{$type}		= \%{SCR::Read (".passwd.$type.users")};
	$users_by_name{$type}	= \%{SCR::Read (".passwd.$type.users.by_name")};
	$shadow{$type}		= \%{SCR::Read (".passwd.$type.shadow")};
	$groups{$type}		= \%{SCR::Read (".passwd.$type.groups")};
	$groups_by_name{$type}	= \%{SCR::Read(".passwd.$type.groups.by_name")};
    }

}

##------------------------------------
BEGIN { $TYPEINFO{Read} = ["function", "boolean"]; }
sub Read {

    $tmpdir = SCR::Read (".target.tmpdir");

    ReadLoginDefaults ();

    CheckHomeMounted();

    ReadSystemDefaults();

    ReadSourcesSettings();

#    ReadCustomSets();

    ReadAllShells();

    ReadLocal ();

    UsersCache::Read ();

    Autologin::Read ();

#    if (Mode::cont) # initial configuration
#    {
#	Autologin::used		= true;
#	Autologin::modified	= true;
#    }

#    ReadNewSet ("ldap");

    return "true";
}

##-------------------------------------------------------------------------
##----------------- data manipulation routines ----------------------------

##------------------------------------
# extract the "shadow" items from user's map
BEGIN { $TYPEINFO{CreateShadowMap} = ["function",
    ["map", "string", "any" ],
    ["map", "string", "any" ]];
}
sub CreateShadowMap {
    
    my %user		= %{$_[0]};
    my %shadow_map	= ();
    
    my %default_shadow = GetDefaultShadow ($user{"type"});
    foreach my $shadow_item (keys %default_shadow) {
	$shadow_map{$shadow_item}	= $user{$shadow_item};
    };
    
    return \%shadow_map;
}

##------------------------------------
# Remove user from the list of members of current group
BEGIN { $TYPEINFO{RemoveUserFromGroup} = ["function", "boolean", "string"]; }
sub RemoveUserFromGroup {

    my $ret		= "false";
    my $user		= $_[0];
    my $group_type	= $group_in_work{"type"};

    if ($group_type eq "ldap") {
        $user           = $user_in_work{"dn"};
	if (defined $user_in_work{"org_dn"}) {
	    $user	= $user_in_work{"org_dn"};
	}
	if (defined $group_in_work{"uniqueMember"}{$user}) {
	    delete $group_in_work{"uniqueMember"}{$user};
	    $ret			= "true";
	    $group_in_work{"what"}	= "user_change";
	}
    }
    elsif (defined $group_in_work{"userlist"}{$user}) {
	$ret			= "true";
	$group_in_work{"what"}	= "user_change";
	delete $group_in_work{"userlist"}{$user};
    }
    return $ret;
}

##------------------------------------ 
# Add user to the members list of current group (group_in_work)
BEGIN { $TYPEINFO{AddUserToGroup} = ["function", "boolean", "string"]; }
sub AddUserToGroup {

    my $ret		= "false";
    my $user		= $_[0];
    my $group_type	= $group_in_work{"type"};

    if ($group_type eq "ldap") {
        $user           = $user_in_work{"dn"};
	if (!defined $group_in_work{"uniqueMember"}{$user}) {
            $group_in_work{"uniqueMember"}{$user}	= 1;
	    $group_in_work{"what"}			= "user_change";
	    $ret					= "true";
	}
    }
    elsif (!defined $group_in_work{"userlist"}{$user}) {
        $group_in_work{"userlist"}{$user}	= 1;
        $ret					= "true";
        $group_in_work{"what"}			= "user_change";
    }
    return $ret;
}

##------------------------------------
# local users have to load shadow settings from global map
sub LoadShadow {

    if (%user_in_work && $user_in_work{"type"} ne "ldap") {
	my $username	= $user_in_work{"username"};
	my $type	= $user_in_work{"type"};
	foreach my $key (keys %{$shadow{$type}{$username}}) {
	    $user_in_work{$key} = $shadow{$type}{$username}{$key};
	}
    }
}
					

##------------------------------------
BEGIN { $TYPEINFO{SelectUserByName} = [ "function",
    "void",
    "string"];
}
sub SelectUserByName {

    %user_in_work	= %{GetUserByName ($_[0], "")};
    LoadShadow ();
}

##------------------------------------
BEGIN { $TYPEINFO{SelectUser} = [ "function",
    "void",
    "integer"];
}
sub SelectUser {

    %user_in_work = %{GetUser ($_[0], "")};
    LoadShadow ();
}

##------------------------------------
BEGIN { $TYPEINFO{SelectGroupByName} = [ "function",
    "void",
    "string"];
}
sub SelectGroupByName {

    %group_in_work = %{GetGroupByName($_[0], "local")};
}

##------------------------------------
BEGIN { $TYPEINFO{SelectGroup} = [ "function",
    "void",
    "integer"];
}
sub SelectGroup {

    %group_in_work = %{GetGroup ($_[0], "")};
}


##------------------------------------
# boolean parameter means "delete home directory"
BEGIN { $TYPEINFO{DeleteUser} = ["function", "boolean", "boolean" ]; }
sub DeleteUser {

    if (%user_in_work) {
	$user_in_work{"what"}		= "delete_user";
	$user_in_work{"delete_home"}	= $_[0];
	return "true";
    }
    return "false";
}

##------------------------------------
BEGIN { $TYPEINFO{DeleteGroup} = ["function", "boolean" ]; }
sub DeleteGroup {

    if (%group_in_work) {
	$group_in_work{"what"}	= "delete_group";
	return "true";
    }
    return "false";
}


##------------------------------------
#TODO the meaning of the map is different then in original Users.ycp!
#it used to be whole map of user (user_in_work), now it is map of changes!

#Edit is used in 2 diffr. situations:
#	1. initialization (creates "org_user")	- could be in SelectUser???
#	2. save changed values into user_in_work
BEGIN { $TYPEINFO{EditUser} = ["function",
    "boolean",
    ["map", "string", "any" ]];		# data to change in user_in_work
}
sub EditUser {

    if (!%user_in_work) { return "false"; }

    my %data		= %{$_[0]};
    my $type		= $user_in_work{"type"} || "";
    if (defined $data{"type"}) {
	$type 	= $data{"type"};
    }
    my $username	= $data{"username"};
    # check if user is edited for first time
    if (!defined $user_in_work{"org_user"} &&
	($user_in_work{"what"} || "add_user") ne "add_user") {

	# save first map for later checks of modification (in Commit)
	my %org_user			= %user_in_work;
	$user_in_work{"org_user"}	= \%org_user;

	# grouplist wasn't fully generated while reading nis & ldap users
	if ($type eq "nis" || $type eq "ldap") {
	    $user_in_work{"grouplist"} = FindGroupsBelongUser (\%org_user);
	    # TODO is map evaluated?
	    DebugMap ($user_in_work{"grouplist"});
	}
	# empty password entry for autoinstall config (do not want to
	# read password from disk: #30573)
#	if (Mode::config && $user_in_work{"userPassword"} eq "x") {
#	    $user_in_work{"userPassword"} = "";
#	}
    }
    # update the settings which should be changed
    foreach my $key (keys %data) {
	if ($key eq "username" || $key eq "homeDirectory" ||
	    $key eq "uidNumber" || $key eq "type" ||
	    $key eq "groupname" || $key eq "dn")
	{
	    # backup the values of important keys (if not already done)
	    my $org_key = "org_$key";
	    if (defined $data{$key} && defined $user_in_work{$key} &&
		$data{$key} ne $user_in_work{$key} &&
		    (!defined $user_in_work{$org_key} ||
		    $user_in_work{$org_key} ne $user_in_work{$key}))
	    {
		$user_in_work{$org_key}	= $user_in_work{$key};
	    }
	}
	# compare the differences, create removed_grouplist
	if ($key eq "grouplist" && defined $user_in_work{$key}) {
	    my %removed = ();
	    foreach my $group (keys %{$user_in_work{$key}}) {
		if (!defined $data{$key}{$group}) {
		    $removed{$group} = 1;
		}
	    }
	    if (%removed) {
		# ensure that previous removed_grouplist is not rewritten:
		if (defined $user_in_work{"removed_grouplist"}) {
		    foreach my $g (keys %{$user_in_work{"removed_grouplist"}}) {
			if (!defined $data{"grouplist"}{$g}) {
			    $removed{$g} = 1;
			}
		    }
		}
		$user_in_work{"removed_grouplist"} = \%removed;
	    }
	}
	$user_in_work{$key}	= $data{$key};
    }
    $user_in_work{"what"}	= "edit_user";

    UsersCache::SetUserType ($type);
    return "true";
}

##------------------------------------
BEGIN { $TYPEINFO{EditGroup} = ["function",
    "boolean",
    ["map", "string", "any" ]];		# data to change in group_in_work
}
sub EditGroup {

    if (!%group_in_work) { return "false"; }

    my %data	= %{$_[0]};
    my $type	= $group_in_work{"type"};

    if (defined $data{"type"}) {
	$type = $data{"type"};
    }

    # update the settings which should be changed
    foreach my $key (keys %data) {
	if ($key eq "groupname" || $key eq "gidNumber" ||
	    $key eq "type" || $key eq "dn")
	{
	    # backup the values of important keys (if not already done)
	    my $org_key = "org_$key";
	    if (defined $group_in_work{$key} &&
		$data{$key} ne $group_in_work{$key} &&
		    (!defined $group_in_work{$org_key} ||
		    $group_in_work{$org_key} ne $group_in_work{$key}))
	    {
		$group_in_work{$org_key}	= $group_in_work{$key};
	    }
	}
	# TODO create @removed_user from modified %userlist
	# compare the differences, create removed_userlist
	if ($key eq "userlist" && defined $group_in_work{"userlist"}) {
	    my %removed = ();
	    foreach my $user (keys %{$group_in_work{"userlist"}}) {
		if (!defined $data{"userlist"}{$user}) {
		    $removed{$user} = 1;
		}
	    }
	    if (%removed) {
		$group_in_work{"removed_userlist"} = \%removed;
	    }
	}
	$group_in_work{$key}	= $data{$key};
    }
    $group_in_work{"what"}	= "edit_group";

    UsersCache::SetGroupType ($type);
    return "true";
}

##------------------------------------
# Initializes user_in_work map with default values
# @param data user initial data (could be an empty map)
BEGIN { $TYPEINFO{AddUser} = ["function",
    "boolean",
    ["map", "string", "any" ]];		# data to fill in
}
sub AddUser {

    my %data	= %{$_[0]};

    my $type	= "local"; #TODO look into current_users/groups for default type
    if (defined $data{"type"}) {
	$type = $data{"type"};
    }

    if (!%data) {
	ResetCurrentUser ();
	# adding totaly new entry - e.g. from the summary table
    }

    foreach my $key (keys %data) {
	$user_in_work{$key}	= $data{$key};
    }
#TODO if "what" already exists, we can return
    $user_in_work{"type"}	= $type;
    $user_in_work{"what"}	= "add_user";

    UsersCache::SetUserType ($type);

    if (!defined $user_in_work{"uidNumber"}) {
	$user_in_work{"uidNumber"} = UsersCache::NextFreeUID ();
    }
    my $username		= $data{"username"};
    if (defined $username) {
	$user_in_work{"username"}	= $username;
    }

    if (!defined $user_in_work{"cn"}) {
	$user_in_work{"cn"}	= "";
    }
    if (!defined $user_in_work{"groupname"}) {
	$user_in_work{"groupname"}	= GetDefaultGroupname ($type);
    }
    if (!defined $user_in_work{"grouplist"}) {
	$user_in_work{"grouplist"}	= GetDefaultGrouplist ($type);
    }
    if (!defined $user_in_work{"homeDirectory"} && defined ($username)) {
	$user_in_work{"homeDirectory"} = GetDefaultHome ($type).$username;
    }
    if (!defined $user_in_work{"gidNumber"}) {
	$user_in_work{"gidNumber"}	= GetDefaultGID ($type);
    }
    if (!defined $user_in_work{"loginShell"}) {
	$user_in_work{"loginShell"}	= GetDefaultShell ($type);
    }
    if (!defined $user_in_work{"create_home"}) {
	$user_in_work{"create_home"}	= "true";
    }
    if (!defined $user_in_work{"userPassword"}) {
	$user_in_work{"userPassword"}	= "";
    }
    else {
	# TODO apply CryptPassword?
    }
    my %default_shadow = GetDefaultShadow ($type);
    foreach my $shadow_item (keys %default_shadow) {
	if (!defined $user_in_work{$shadow_item}) {
	    $user_in_work{$shadow_item}	= $default_shadow{$shadow_item};
	}
    }
    if (!defined $user_in_work{"shadowLastChange"}) {
        $user_in_work{"shadowLastChange"} = LastChangeIsNow ();
    }

    if ($type eq "ldap") {
	    # add default object classes
#	    if (!defined $user_in_work{"objectClass"}) {
#		$user_in_work{"objectClass"} = GetLDAPUserClass();
#	    }
	    # add other default values
#	    foreach (string attr, any val, ldap_user_defaults, ``{
#		string a = ldap2yast_user_attrs [attr]:attr;
#		if (!haskey (user_in_work, a) || user_in_work[a]:"" == "")
#		    user_in_work [a] = val;
#	    });
#	    user_in_work ["dn"] = data["dn"]:CreateUserDN (data);
    }
    return "true";
}

##------------------------------------
# Shortcut to AddUser
BEGIN { $TYPEINFO{Add} = ["function",
    "boolean",
    ["map", "string", "any" ]];
}
sub Add {
    return AddUser ($_[0]);
}
    

##------------------------------------
# Initializes group_in_work map with default values
# @param data group initial data (could be an empty map)
BEGIN { $TYPEINFO{AddGroup} = ["function",
    "boolean",
    ["map", "string", "any" ]];		# data to fill in
}
sub AddGroup {

    my %data	= %{$_[0]};
    my $type	= "local"; #TODO look into current_groups for default type

    if (defined $data{"type"}) {
	$type = $data{"type"};
    }
    if (!%data) {
	ResetCurrentGroup ();
    }
    foreach my $key (keys %data) {
	$group_in_work{$key}	= $data{$key};
    }
    $group_in_work{"type"}		= $type;
    $group_in_work{"what"}		= "add_group";
	
    UsersCache::SetGroupType ($type);

    if (!defined $group_in_work{"gidNumber"}) {
	$group_in_work{"gidNumber"}	= UsersCache::NextFreeGID ($type);
    }
#	if (type == "ldap")
#	{
#	    # add default object classes
#	    group_in_work["objectClass"] = data["objectClass"]:ldap_group_class;
#	    # add other default values
#	    foreach (string attr, any val, ldap_group_defaults, ``{
#		string a = ldap2yast_group_attrs [attr]:attr;
#		if (!haskey (group_in_work, a) || group_in_work[a]:"" == "")
#		    group_in_work [a] = val;
#	    });
#	    group_in_work ["dn"] = data["dn"]:CreateGroupDN (data);
#	}
    return "true"; #TODO better return value: current u/g map?
}

##------------------------------------ 
BEGIN { $TYPEINFO{SubstituteValues} = ["function",
    ["map", "string", "any" ],
    "string", ["map", "string", "any" ]];
}
sub SubstituteValues {
    
    return $_[1]; #FIXME - call this from AddUser/Group...?

}

##------------------------------------ 
# Checks if commited user is really modified and has to be saved
sub UserReallyModified {

    my %user	= %{$_[0]};

    if (($user{"what"} || "") eq "group_change") {
        return 0;
    }
    if (($user{"what"} || "") ne "edit_user") {
        return 1;
    }

    my $ret = 0;

    if ($user{"type"} ne "ldap") {
	# grouplist can be ignored, it is a modification of groups
	while ( my ($key, $value) = each %{$user{"org_user"}}) {
	    if ($key ne "grouplist" &&
		(!defined $user{$key} || $user{$key} ne $value))
	    {
		$ret = 1;
		y2debug ("old value:%1, changed to:%2",
		    $value, $user{$key} || "-" );
	    }
	};
	return $ret;
    }
    #TODO LDAP
    return $ret;
}


##------------------------------------
# Update the global map of users using current user or group
BEGIN { $TYPEINFO{CommitUser} = ["function", "boolean"] }
sub CommitUser {

    if (!%user_in_work) { return "false"; }
    if (defined $user_in_work{"check_error"}) {
	y2error ("commit is forbidden: ", $user_in_work{"check_error"});
	return "false";
    }

    # create local copy of current user
    my %user	= %user_in_work;
    
    my $type	= "local";
    if (defined $user{"type"}) {
        $type	= $user{"type"};
    }
    my $org_type	= $user{"org_type"} || $type;
    my $what_user	= $user{"what"};
    my $uid		= $user{"uidNumber"};
    my $org_uid		= $user{"org_uidNumber"} || $uid;
    my $username	= $user{"username"};
    my $org_username	= $user{"org_username"} || $username;
    my $groupname	= $user{"groupname"};
    my $home		= $user{"homeDirectory"};
    my %grouplist	= %{$user{"grouplist"}};


    if (($type eq "local" || $type eq "system") &&
	!$users_modified && UserReallyModified (\%user)) {
	    $users_modified = 1;
    }
    if ($type eq "ldap" && !$ldap_modified && UserReallyModified (\%user)) {
        $ldap_modified = 1;
    }

    y2internal ("commiting user '$username', action is '$what_user'");

    # --- 1. do the special action
    if ($what_user eq "add_user") {
	
        $user{"modified"}	= "added";

	if ($type eq "ldap") {
	    %user = SubstituteValues ("user", \%user);
	}

        # update the affected groups
        foreach my $group (keys %grouplist) {
            %group_in_work = %{GetGroupByName ($group, $type)};
            if (%group_in_work && AddUserToGroup ($username) eq "true") {
                CommitGroup ();
	    }
        };
        # add user to his default group (updating only cache variables)
        %group_in_work = %{GetGroupByName ($groupname, $type)};
        if (%group_in_work) {
            $group_in_work{"what"}	= "user_change_default";
            $group_in_work{"more_users"}{$username}	= 1;
            CommitGroup ();
        }

        # check if home directory for this user doesn't already exist
        if (defined $user{"create_home"} &&
	    $user{"create_home"} eq "false" &&
            defined $removed_homes{$home}) {

	    delete $removed_homes{$home};
        }

        # add new entry to global shadow map:
        $shadow{$type}{$username}	= CreateShadowMap (\%user);
    }
    elsif ( $what_user eq "edit_user" ) {

        if (!defined $user{"modified"}) {
            $user{"modified"}	= "edited";
	}
        # check the change of additional group membership
        foreach my $group (keys %grouplist) {

            %group_in_work = %{GetGroupByName ($group, $type)};
            if (%group_in_work) {
	        # username changed - remove org_username
	        if ($org_username ne $username) {
		   RemoveUserFromGroup ($org_username);
	        }
	        if (AddUserToGroup ($username) eq "true") {
		   CommitGroup ();
	        }
	    }
        };

        # check if user was removed from some additional groups
	if (defined $user{"removed_grouplist"}) {
            foreach my $group (keys %{$user{"removed_grouplist"}}) {
	        %group_in_work = %{GetGroupByName ($group, $type)};
	        if (%group_in_work &&
		    RemoveUserFromGroup ($org_username) eq "true") {
		    CommitGroup ();
	        }
	    };
	}
	
        # check the possible change of default group
        my $org_groupname = $groupname;
	if (defined $user{"org_groupname"}) {
	    $org_groupname	= $user{"org_groupname"};
	}
        if ($username ne $org_username && $groupname eq $org_groupname) {
            # change the user's name in his default group
            %group_in_work	= %{GetGroupByName ($groupname, $type)};
            if (%group_in_work) {
                $group_in_work{"what"}	= "user_change_default";
                delete $group_in_work{"more_users"}{$org_username};
                $group_in_work{"more_users"}{$username}	= 1;
                CommitGroup ();
            }
        }
        elsif ($groupname ne $org_groupname) {
            # note: username could be also changed!
            # 1. remove the name from original group ...
            %group_in_work	= %{GetGroupByName ($org_groupname, $type)};
            if (%group_in_work) {
                $group_in_work{"what"}	= "user_change_default";
                delete $group_in_work{"more_users"}{$org_username};
                CommitGroup ();
            }
            # 2. and add it to the new one:
            %group_in_work	= %{GetGroupByName ($groupname, $type)};
            if (%group_in_work) {
                $group_in_work{"what"}	= "user_change_default";
                $group_in_work{"more_users"}{$username}	= 1;
                CommitGroup ();
            }
        }

	# check if home directory for this user doesn't already exist
        if (defined $user{"create_home"} &&
	    $user{"create_home"} eq "false" &&
            defined $removed_homes{$home}) {

	    delete $removed_homes{$home};
	}

        # modify the shadow entry
        if ($type eq "local" || $type eq "system") {
            if ($username ne $org_username &&
                defined $shadow{$type}{$org_username}) {
                delete $shadow{$type}{$org_username};
	    }
            $shadow{$type}{$username} = CreateShadowMap (\%user);
        }
    }
    elsif ( $what_user eq "group_change_default") {
	# gid of default group was changed
	$user{"modified"} = "edited";
    }
    elsif ( $what_user eq "delete_user" ) {

        # prevent the add & delete of the same user
        if (!defined $user{"modified"}) {
            $user{"modified"} = "deleted";
	    $removed_users{$type}{$uid}	= \%user;
        }

        # check the change of group membership
        foreach my $group (keys %grouplist) {
            %group_in_work = %{GetGroupByName ($group, $type)};
            if (%group_in_work &&
	        RemoveUserFromGroup ($org_username) eq "true") {
                CommitGroup();
	    }
        };
        # remove user from his default group -- only cache structures
        %group_in_work			= %{GetGroupByName ($groupname, $type)};
	if (%group_in_work) {
	    $group_in_work{"what"}	= "user_change_default";
            delete $group_in_work{"more_users"}{$username};
	    CommitGroup ();
	}

	# store deleted directories... someone could want to use them
	if (defined $user{"delete_home"} && $type ne "ldap") {
	    #TODO undef delete_home instead of set it false
	    my $h	= $home;
	    if (defined $user{"org_homeDirectory"}) {
	        $h	= $user{"org_homeDirectory"};
	    }
	    $removed_homes{$h}	= 1;
	}
    }

    # --- 2. and now do the common changes

    UsersCache::CommitUser (\%user);
	
    if ($what_user eq "delete_user") {
        delete $users{$type}{$uid};
        delete $users_by_name{$type}{$username};
        if ($type ne "ldap") {
            delete $shadow{$type}{$username};
	}
    }
    else {

        if ($org_type ne $type) {
            delete $shadow{$org_type}{$org_username};
        }
        if ($uid != $org_uid && defined ($users{$org_type}{$org_uid})) {
            delete $users{$org_type}{$org_uid};
        }
        if ($username ne $org_username || $org_type ne $type) {
            delete $users_by_name{$org_type}{$org_username};
        }

        $user{"org_username"}			= $username;
        $users{$type}{$uid}			= \%user;
        $users_by_name{$type}{$username}	= $uid;
    }
    undef %user_in_work;
    return "true";
}

##------------------------------------
# Update the global map of groups using current group
BEGIN { $TYPEINFO{CommitGroup} = ["function", "boolean"]; }
sub CommitGroup {

    if (!%group_in_work) { return "false"; }

    if (defined $group_in_work{"check_error"}) {
        y2error ("commit is forbidden: ", $group_in_work{"check_error"});
        return "false";
    }

    # we need to create local copy of current group map
    my %group	= %group_in_work;

    my $type	= "local";
    if (defined $group{"type"}) {
        $type	= $group{"type"};
    }

    my $what_group	= $group{"what"} || "";
    my $org_type    	= $group{"org_type"} || $type;
    my $groupname    	= $group{"groupname"};
    my $org_groupname	= $group{"org_groupname"} || $groupname;
    my $gid    		= $group{"gidNumber"};
    my $org_gid		= $group{"org_gidNumber"} || $gid;
    my %userlist	= %{$group{"userlist"}};

    y2internal ("commiting group '$groupname', action is '$what_group'");

    if ($type eq "system" || $type eq "local") {
	$groups_modified = 1;
    }
    elsif ($type eq "ldap" && $what_group ne "") {
	$ldap_modified	= 1;
    }

    # 1. specific action
    if ( $what_group eq "add_group" ) {

	$group{"modified"} = "added";
        # update users's grouplists (only cache structures)
        foreach my $user (keys %userlist) {
            %user_in_work = %{GetUserByName ($user, "")};
	    if (%user_in_work) {
                $user_in_work{"grouplist"}{$groupname}	= 1;
	        $user_in_work{"what"} = "group_change";
	        CommitUser ();
	    }
        };
    }
    elsif ($what_group eq "edit_group") {
	if (!defined $group{"modified"}) {
	    $group{"modified"}	= "edited";
	}
        # update users's grouplists (mainly cache structures)
        foreach my $user (keys %userlist) {
            %user_in_work = %{GetUserByName ($user, "")};
            if (%user_in_work) {
                my $commit_user	= 0;
                # new user added to group
                if (!defined $user_in_work{"grouplist"}{$org_groupname}) {
                    $user_in_work{"grouplist"}{$groupname}	= 1;
                    $commit_user 				= 1;
                }
	        # + group name was changed
                elsif ($org_groupname ne $groupname) {
	    	delete $user_in_work{"grouplist"}{$org_groupname};
                    $user_in_work{"grouplist"}{$groupname}	= 1;
                    $commit_user				= 1;
                }

                if ($commit_user) {
                    $user_in_work{"what"}	= "group_change";
                    CommitUser ();
                }
            }
        };
        # check the additional users removed from our group
        foreach my $user (keys %{$group{"removed_userlist"}}) {
            %user_in_work = %{GetUserByName ($user, "")};
            if (%user_in_work) {
                if (!defined $user_in_work{"grouplist"}{$org_groupname}) {
		    delete $user_in_work{"grouplist"}{$org_groupname};
                    $user_in_work{"what"}	= "group_change";
                    CommitUser ();
                }
            }
	};
        # correct the changed groupname/gid of our group for users
	# having this group as default
        if ($groupname ne $org_groupname || $gid != $org_gid) {
            foreach my $user (keys %{$group{"more_users"}}) {
                %user_in_work = %{GetUserByName ($user, "")};
                if (%user_in_work) {
		    $user_in_work{"groupname"}	= $groupname;
                    $user_in_work{"gidNumber"}	= $gid;
		    $user_in_work{"what"}		= "group_change";
		    if ($gid != $org_gid) {
			$user_in_work{"what"} 	= "group_change_default";
		    }
                    CommitUser ();
                }
            };
        }
    }
    elsif ($what_group eq "delete_group") {
	if (!defined $group{"modified"}) {
	    $group {"modified"}			= "deleted";
            $removed_groups{$type}{$org_gid}	= \%group;
        }
	delete $groups{$type}{$org_gid};
        delete $groups_by_name{$type}{$org_groupname};
	# deleted group had no members -> no user change
    }
    elsif ( $what_group eq "user_change" ) # do not call Commit again
    {
        if (!defined $group{"modified"}) {
            $group{"modified"}	= "edited";
        }
    }
#    elsif ( $what_group eq "user_change_default") {
#            # current group is some user's default - changin only cache
#            # structures and don't set modified flag
#    }

    UsersCache::CommitGroup (\%group);
    # 2. common action: update groups

    if ($what_group ne "delete_group") { # also for `change_user!
        
	if ($gid != $org_gid) {
	    if (defined ($groups{$org_type}{$org_gid})) {
	        delete $groups{$org_type}{$org_gid};
	    }
	    # type was changed, but groupname didn't
	    if ($type ne $org_type && $groupname eq $org_groupname) {
		delete $groups_by_name{$org_type}{$groupname};
	    }
	}

        if ($groupname ne $org_groupname &&
	    defined ($groups_by_name{$org_type}{$org_groupname})) {
            delete $groups_by_name{$org_type}{$org_groupname};
	}

        # this has to be done due to multiple changes of groupname TODO ???
        $group{"org_groupname"}		= $groupname;

        $groups{$type}{$gid}		= \%group;
        $groups_by_name{$type}{$groupname}	= $gid;
    }
    undef %group_in_work;
    return "true";
}

##-------------------------------------------------------------------------
##----------------- write routines ----------------------------------------

##------------------------------------
# Writes the set of values in "Custom" filter and other internal variables
sub WriteCustomSets {

    my %customs = (
#        "custom_users"	=> @user_custom_sets,
#        "custom_groups"	=> @group_custom_sets,
#        "dont_warn_when_uppercase"	=> not_ask_uppercase,
    );
#    SCR::Write (.target.ycp, Directory::vardir + "/users.ycp", \%customs);

    return 1;#TODO
}

##------------------------------------
# Writes settings to /etc/defaults/useradd
sub WriteLoginDefaults {

    my $ret = 1;

    while ( my ($key, $value) = each %useradd_defaults) {
#TODO        $ret = $ret && SCR::Write (".etc.default.useradd.$key", $value);
    }

    y2milestone ("Succesfully written useradd defaults: %1", $ret);
    return $ret;
}

##------------------------------------
# Save Security settings (encryption method) if changed in Users module
sub WriteSecurity {

    my $ret = 1;
#    if ( $encryptionMethod != Security::Settings["PASSWD_ENCRYPTION"]:"des" )
#    {
#	y2milestone( "Changing encryption method to $%encryptionMethod");
#        Security::modified = true;
#	Security::Settings["PASSWD_ENCRYPTION"] = encryptionMethod;
#	Progress::off();
#	ret = Security::Write();
#	if (!write_only)
#	    Progress::on();
#    } TODO
    return $ret;
}

##------------------------------------
sub CreateHome {

    return 1;#TODO
}

sub ChownHome {

    return 1;#TODO
}

sub MoveHome {

    return 1;#TODO
}

sub DeleteHome {

    return 1;#TODO
}

##------------------------------------
BEGIN { $TYPEINFO{WriteGroup} = ["function", "void"]; }
sub WriteGroup () {

    SCR::Write (".passwd.groups", \%groups);
    return 1;
}

##------------------------------------
BEGIN { $TYPEINFO{WritePasswd} = ["function", "void"]; }
sub WritePasswd () {
    SCR::Write (".passwd.users", \%users);
    return 1;
}

##------------------------------------
BEGIN { $TYPEINFO{WriteShadow} = ["function", "void"]; }
sub WriteShadow () {
    
    SCR::Write (".passwd.shadow", \%shadow);
    return 1;
}

##------------------------------------
sub DeleteUsers {

    my $ret = 1;

    foreach my $type ("system", "local") {
	if (!defined $removed_users{$type}) { next; }
	foreach my $uid (keys %{$removed_users{$type}}) {
	    my %user = %{$removed_users{$type}{$uid}};
	    my $cmd = "$userdel_precmd $user{\"username\"} $uid $user{\"gidNumber\"} $user{\"homeDirectory\"}";
#	    SCR::Execute(.target.bash, cmd);
	};
    };

    foreach my $home (keys %removed_homes) {
	$ret = $ret && DeleteHome ($home);
    };

    foreach my $type ("system", "local") {
	if (!defined $removed_users{$type}) { next; }
	foreach my $uid (keys %{$removed_users{$type}}) {
	    my %user = %{$removed_users{$type}{$uid}};
	    my $cmd = "$userdel_postcmd $user{\"username\"} $uid $user{\"gidNumber\"} $user{\"homeDirectory\"}";
#	    SCR::Execute(.target.bash, cmd);
	};
    };
    return $ret;
}

##------------------------------------
BEGIN { $TYPEINFO{Write} = ["function", "boolean"]; }
sub Write () {

    my $ret	= "";
    
    if ($groups_modified) {
        if (! WriteGroup ()) {
            y2error ("Cannot write group file.");
	    $ret = "Cannot write group file.";
        }
        # remove the group cache for nscd (bug 24748)
        SCR::Execute (".target.bash", "/usr/sbin/nscd -i group");
    }


    if ($users_modified) {
        if (!DeleteUsers ()) {
            y2error ("Error while removing users.");
	    $ret = "Error while removing users.";
	}
        if (!WritePasswd ()) {
            y2error ("Cannot write passwd file.");
	    $ret = "Cannot write passwd file.";
	}
	# remove the passwd cache for nscd (bug 24748)
        SCR::Execute (".target.bash", "/usr/sbin/nscd -i passwd");
    }

    # FIXME: modified users will be needed!
    my %modified_users = (
	"local"		=> {},
	"system"	=> {}
    );

    # check for homedir changes
    foreach my $type (keys %modified_users)  {
	foreach my $uid (keys %{$modified_users{$type}}) {
	    
	    my %user		= %{$modified_users{$type}{$uid}};
	    my $home 		= $user{"homeDirectory"} || "";
	    my $username 	= $user{"username"} || "";
	    my $command 	= "";
            my $user_mod 	= $user{"modified"} || "no";
            my $gid 		= $user{"gidNumber"};
        
	    if ($user_mod eq "imported" || $user_mod eq "added") {
#		if ((($user{"create_home"} || 1) || $user_mod eq "imported") &&
#		    SCR::Read (.target.stat, home) == $[])
#		{
#		    CreateHome ($default_skel, $home);
#		}
		ChownHome ($uid, $gid, $home);
		# call the useradd.local (TODO check the existence ??)
		$command = sprintf ("%s %s", $useradd_cmd, $username);
#		y2debug ("%1 return value: %2", useradd_cmd,
#		    SCR::Execute (.target.bash, command));
	    }
	    else { # only "edited" can be here
		my $org_home = $user{"org_homeDirectory"} || $home;
		if ($home ne $org_home) {
		    # move the home directory
		    if (($user{"create_home"} || "false") eq "true") {
			MoveHome ($org_home, $home);
		    }
		}
		ChownHome ($uid, $gid, $home);
	    }
	};
    };

    if ($users_modified) {
        if (! WriteShadow ()) {
	    $ret = "Cannot write shadow file.";
            y2error ("Cannot write shadow file.");
        }
    }

    # call make on NIS server
    if (($users_modified || $groups_modified) && $is_nis_master) {
#        map ret = (map) SCR::Execute(.target.bash_output,
#	    "/usr/bin/make -C /var/yp");
#        if (ret["exit"]:1 != 0)
#        {
#            y2error("Cannot make NIS database: %1", ret);
#        }
    }

    if ($customs_modified) {
        WriteCustomSets();
    }

    if ($defaults_modified) {
        WriteLoginDefaults();
    }

    if ($security_modified) {
	WriteSecurity();
    }

#    if (Mode::cont) {
#	# mail forward from root
#        if (root_mail != "" && !MailAliases::SetRootAlias (root_mail))
#            # error popup
#            Report::Error(_("There was an error while setting forwarding for root's mail."));
#    }

#    Autologin::Write (Mode::cont || write_only);


#    # do not show user in first dialog when all has been writen
#    if (Mode::cont) {
#        $use_next_time	= 0;
#        undef %saved_user;
#        undef %user_in_work;
#    }

    return $ret;
}

##-------------------------------------------------------------------------
##----------------- check routines (TODO move outside...) ---------

# "-" means range! -> at the begining or at the end!
my $valid_logname_chars = "[0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ._-]";

my $valid_password_chars = "[-0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!@#\$%^&*() ,;:._+/|?{}=\[]|]";# the ']' is or-ed...

my $valid_home_chars = "[0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ/_.-]";

##------------------------------------
BEGIN { $TYPEINFO{ValidLognameChars} = ["function", "string"]; }
sub ValidLognameChars {
    return $valid_logname_chars;
}


##------------------------------------
# check the uid of current user
BEGIN { $TYPEINFO{CheckUID} = ["function", "string", "integer"]; }
sub CheckUID {

    my $uid	= $_[0];
    my $type	= UsersCache::GetUserType ();
    my $min	= UsersCache::GetMinUID ($type);
    my $max	= UsersCache::GetMaxUID ($type);

    if (!defined $uid) { #FIXME if uid was not defined, it failed before...!
	return "There is no free UID for this type of user.";
    }

    if ($uid == $user_in_work{"uidNumber"}) {
	return "";
    }
    if (UsersCache::UIDExists ($uid) eq "true") {#FIXME translatable strings!
	return "The user ID entered is already in use.
Select another user ID.";
    }

    if (($type ne "system" && $type ne "local" && ($uid < $min || $uid > $max))
	||
	# allow change of type: "local" <-> "system"
	(($type eq "system" || $type eq "local") &&
	 (
	    ($uid < UsersCache::GetMinUID ("local") &&
	    $uid < UsersCache::GetMinUID ("system")) ||
	    ($uid > UsersCache::GetMaxUID ("local") &&
	     $uid > UsersCache::GetMaxUID ("system"))
	 )
	)) 
    {
	return sprintf ("The selected user ID is not allowed.
Select a valid integer between %i and %i.", $min, $max);
    }
    return "";
}

##------------------------------------
# check the uid of current user - part 2
BEGIN { $TYPEINFO{CheckUIDUI} = ["function",
    ["map", "string", "string"],
    "integer", ["map", "string", "string"]];
}
sub CheckUIDUI {

    my $uid	= $_[0];
    my %ui_map	= %{$_[1]};
    my $type	= UsersCache::GetUserType (); #TODO maybe type should be an argument?
    my %ret	= ();

    if (($ui_map{"local"} || 0) != 1) {
	if ($type eq "system" &&
	    $uid > UsersCache::GetMinUID ("local") &&
	    $uid < UsersCache::GetMaxUID ("local"))
	{
	    $ret{"question_id"}	= "local";
	    $ret{"question"}	= sprintf ("The selected user ID is a local ID,
because the ID is greater than %i.
Really change type of user to 'local'?", UsersCache::GetMinUID ("local"));
	    return \%ret;
	}
    }

    if (($ui_map{"system"} || 0) != 1) {
	if ($type eq "local" &&
	    $uid > UsersCache::GetMinUID ("system") &&
	    $uid < UsersCache::GetMaxUID ("system"))
	{
	    $ret{"question_id"}	= "system";
	    $ret{"question"}	= sprintf ("The selected user ID is a system ID,
because the ID is smaller than %i.
Really change type of user to 'system'?", UsersCache::GetMaxUID ("system"));
	    return \%ret;
	}
    }
    return \%ret;
}

##------------------------------------
# check the username of current user
BEGIN { $TYPEINFO{CheckUsername} = ["function", "string", "string"]; }
sub CheckUsername {

    my $username	= $_[0];

    if (!defined $username || $username eq "") {
        return "You didn't enter a username.
Please try again.";
    }
    
    if (length ($username) < $UsersCache::min_length_login ||
	length ($username) > $UsersCache::max_length_login ) {

	return sprintf ("The user name must be between %i and %i characters in length.
Try again.", $UsersCache::min_length_login, $UsersCache::max_length_login);
    }
	
    my $filtered = $username;
    $filtered =~ s/$valid_logname_chars//g;

    my $first = substr ($username, 0, 1);
    if ($first ne "_" && ($first lt "A" || $first gt "z" ) || $filtered ne "") { 
	return "The user login may contain only
letters, digits, \"-\", \".\", and \"_\"
and must begin with a letter or \"_\".
Try again.";
    }

    if ($username ne ($user_in_work{"username"} || "") &&
	UsersCache::UsernameExists ($username) eq "true") {
	return "There is a conflict between the entered
user name and an existing user name.
Try another one.";
    }
    return "";
    
}

##------------------------------------
# TODO same as for fullname??? fllname cannot contain ","
BEGIN { $TYPEINFO{CheckGECOS} = ["function", "string", "string"]; }
sub CheckGECOS {

    my $gecos		= $_[0];

    if ($gecos =~ m/:/) {
        return "The \"Additional User Information\" entry cannot
contain a colon (:).  Try again.";
    }
    
    my @gecos_l = split (/,/, $gecos);
    if (@gecos_l > 3 ) {
        return "The \"Additional User Information\" entry can consist
of up to three sections separated by commas.
Remove the surplus.";
    }
    
    return "";
}

##------------------------------------
# check the password of current user
BEGIN { $TYPEINFO{CheckPassword} = ["function", "string", "string"]; }
sub CheckPassword {

    my $pw 		= $_[0];
    my $type		= UsersCache::GetUserType ();
    my $min_length 	= $UsersCache::min_pass_length{$type};
    my $max_length 	= $UsersCache::max_pass_length{$type};

    if (($pw || "") eq "") {
            
	return "You didn't enter a password.
Please try again.";
    }

    if (length ($pw) < $min_length) {
        return sprintf ("The password must have between %i and %i characters.
Please try again.", $max_length, $min_length);
    }

    my $filtered = $pw;
    $filtered =~ s/$valid_password_chars//g;

    if ($filtered ne "") {
	return "The password may only contain the following characters:
0..9, a..z, A..Z, and any of \"#* ,.;:._-+!\$%^&/|\?{[()]}\".
Please try again.";
    }
            
    return "";
}

##------------------------------------
# Try to crack password using cracklib
# @param username user name
# @param pw password
# @return utility output: either "" or error message
sub CrackPassword {

    my $ret 	= "";
    my $pw 	= $_[0];

    if (!defined $cracklib_dictpath || $cracklib_dictpath eq "" ||
	SCR::Read (".target.size", "$cracklib_dictpath.pwd") == -1) {
	$ret = SCR::Execute (".crack", $pw);
    }
    else {
	$ret = SCR::Execute (".crack", $pw, $cracklib_dictpath);
    }
    return $ret;#TODO ret should be recoded!
}

##------------------------------------
# Just some simple checks for password contens
# @param username user name
# @param pw password
# @return error message (password too simple) or empty string (OK)
sub CheckObscurity {

    my $username	= $_[0];
    my $pw 		= $_[1];

    if ($pw =~ m/$username/) {
        return "You have used the user name as a part of the password.
This is not good security practice. Are you sure?";
    }

    # check for lowercase
    my $filtered 	= $pw;
    $filtered 		=~ s/[a-z]//g;
    if ($filtered eq "") {
        return "You have used only lowercase letters for the password.
This is not good security practice. Are you sure?";
    }

    # check for numbers
    $filtered 		= $pw;
    $filtered 		=~ s/[0-9]//g;
    if ($filtered eq "") {
        return "You have used only digits for the password.
This is not good security practice. Are you sure?";
    }
    return "";
}

##------------------------------------
# Checks if password is not too long
# @param pw password
sub CheckPasswordMaxLength {

    my $pw 		= $_[0];
    my $type		= UsersCache::GetUserType ();
    my $max_length 	= $UsersCache::max_pass_length{$type};

    if (length ($pw) > $max_length) {
        return "The password is too long for the current encryption method.
Truncate it to $max_length characters?";
    }
    return "";
}

##------------------------------------
# check the password of current user -- part 2
BEGIN { $TYPEINFO{CheckPasswordUI} = ["function",
    ["map", "string", "string"],
    "string", "string", ["map", "string", "string"]];
}
sub CheckPasswordUI {

    my $username	= $_[0];
    my $pw 		= $_[1];
    my %ui_map		= %{$_[2]};
    my %ret		= ();

    if ($use_cracklib && (($ui_map{"crack"} || 0) != 1)) {
	my $error = CrackPassword ($pw);
	if ($error ne "") {
	    $ret{"question_id"}	= "crack";
	    $ret{"question"}	= "Password is too simple:
$error
Really use it?";
	    return \%ret;
	}
    }
    
    if ($obscure_checks && (($ui_map{"obscure"} || 0) != 1)) {
	my $error = CheckObscurity ($username, $pw);
	if ($error ne "") {
	    $ret{"question_id"}	= "obscure";
	    $ret{"question"}	= $error;
	    return \%ret;
	}
    }
    
    if (($ui_map{"truncate"} || 0) != 1) {
	my $error = CheckPasswordMaxLength ($pw);
	if ($error ne "") {
	    $ret{"question_id"}	= "truncate";
	    $ret{"question"}	= $error;
	}
    }
    return \%ret;
}


##------------------------------------
# Check if it is possible to write (=create homes) to given directory
# @param dir the directory
# @return empty string on success or name of directory which is not writable
sub IsDirWritable {

    my $dir = $_[0];

    # maybe more directories in path don't exist
    while ($dir ne "" && !%{SCR::Read (".target.stat", $dir)}) {
	$dir = substr ($dir, 0, rindex ($dir, "/"));
    }

    my $tmpfile = $dir."/tmpfile";

    while (SCR::Execute (".target.bash", "/usr/bin/test -e $tmpfile") == 0) {
        $tmpfile .= "0";
    }

    my %out = %{SCR::Execute (".target.bash_output", "/bin/touch $tmpfile")};
    if (defined $out{"exit"} && $out{"exit"} == 0) {
        SCR::Execute (".target.bash", "/bin/rm $tmpfile");
        return "";
    }
    return $dir;
}


##------------------------------------
# check the home directory of current user
BEGIN { $TYPEINFO{CheckHome} = ["function", "string", "string"]; }
sub CheckHome {

    my $home		= $_[0];
    if ($home eq "" || $home eq ($user_in_work{"homeDirectory"} || "")) {
	return "";
    }

    my $type		= UsersCache::GetUserType ();
    my $first 		= substr ($home, 0, 1);
    my $filtered 	= $home;
    $filtered 		=~ s/$valid_home_chars//g;

    if ($filtered ne "" || $first ne "/" || $home =~ m/\/\./) {
        return "The home directory may only contain the following characters:
a..zA..Z0..9_-/
Try again.";
    }

    # check if directory is writable
#    if (!Mode::config && ($type ne "ldap" || $ldap_file_server)) 
# TODO chould that ldap-check be here or upper (in the function CheckHome is called from)?
    if (1) {
	my $home_path = substr ($home, 0, rindex ($home, "/"));
        $home_path = IsDirWritable ($home_path);
        if ($home_path ne "") {
            return "The directory $home_path is not writable.
Choose another path for the home directory.";
	}
    }

    if ($home ne ($user_in_work{"homeDirectory"} || "") &&
        UsersCache::HomeExists ($home) eq "true") {
        return "The home directory is used from another user.
Please try again.";
    }

    return "";
}

##------------------------------------
# check the home directory of current user - part 2
BEGIN { $TYPEINFO{CheckHomeUI} = ["function",
    ["map", "string", "string"],
    "integer", "string", ["map", "string", "string"]];
}
sub CheckHomeUI {

    my $uid		= $_[0];
    my $home		= $_[1];
    my %ui_map		= %{$_[2]};
    my $type		= UsersCache::GetUserType ();
    my %ret		= ();

    if ($home eq "" || $home eq ($user_in_work{"homeDirectory"} || "") ||
	!($user_in_work{"create_home"} || 0)) {
	return \%ret;
    }

    if ((($ui_map{"chown"} || 0) != 1) &&
	(SCR::Read (".target.size", $home) != -1)) {
#	!Mode::config &&
#	($user_type ne "ldap" || $ldap_file_server))
        
	$ret{"question_id"}	= "chown";
	$ret{"question"}	= "The home directory selected already exists.
Use it and change its owner?";

	my %stat 	= %{SCR::Read (".target.stat", $home)};
	my $dir_uid	= $stat{"uidNumber"} || -1;
                    
	if ($uid == $dir_uid) { # chown is not needed (#25200)
	    $ret{"question"}	= "The home directory selected already exists
and is owned by the currently edited user.
Use this directory?";
	}
	# maybe it is home of some user marked to delete...
	elsif (defined $removed_homes{$home}) {
	    $ret{"question"}	= "The home directory selected ($home)
already exists as a former home directory of
a user previously marked for deletion.
Use this directory?";
	}
    }
    return \%ret;
}


##------------------------------------
# check the gid of current group
BEGIN { $TYPEINFO{CheckGID} = ["function", "string", "integer"]; }
sub CheckGID {

    my $gid	= $_[0];
    my $type	= UsersCache::GetUserType ();

    if (!defined $gid) {
	return "There is no free GID for this type of group.";
    }

    if ($gid == $group_in_work{"gidNumber"}) {
	return "";
    }

    if (UsersCache::GIDExists ($gid) eq "true") {
	return "The group ID entered is already in use.
Select another group ID.";
    }

    if ($gid < UsersCache::GetMinGID ($type) ||
	$gid > UsersCache::GetMaxGID ($type)) {
	
	return sprintf ("The selected group ID is not allowed.
Select a valid integer between %i and %i.",
	    UsersCache::GetMinGID($type), UsersCache::GetMaxGID($type));
    }#TODO questin...
    return "";
}

##------------------------------------
# check the groupname of current group
BEGIN { $TYPEINFO{CheckGroupname} = ["function", "string", "string"]; }
sub CheckGroupname {

    my $groupname	= $_[0];

    if (!defined $groupname || $groupname eq "") {
        return "You didn't enter a groupname.
Please try again.";
    }
    
    if (length ($groupname) < $UsersCache::min_length_groupname ||
	length ($groupname) > $UsersCache::max_length_groupname ) {

	return sprintf ("The group name must be between %i and %i characters in length.
Try again.", $UsersCache::min_length_groupname,
	     $UsersCache::max_length_groupname);
    }
	
    my $filtered = $groupname;
    $filtered =~ s/$valid_logname_chars//g;

    my $first = substr ($groupname, 0, 1);
    if ($first lt "A" || $first gt "z" || $filtered ne "") { 
	return "The group name may contain only
letters, digits, \"-\", \".\", and \"_\"
and must begin with a letter.
Try again.";
    }
    
    if ($groupname ne ($group_in_work{"groupname"} || "") &&
	UsersCache::GroupnameExists ($groupname) eq "true") {
	return "There is a conflict between the entered
group name and an existing group name.
Try another one."
    }
    return "";
}

##------------------------------------
# check correctness of current user data
# if map is empty, it takes current user map
BEGIN { $TYPEINFO{CheckUser} = ["function", "string", ["map", "string","any"]];}
sub CheckUser {

    my %user	= %{$_[0]};
    if (!%user) {
	%user = %user_in_work;
    }

    my $error	= CheckUID ($user{"uidNumber"});

    if ($error eq "") {
	$error	= CheckUsername ($user{"username"});
    }

    if ($error eq "") {
	$error	= CheckPassword ($user{"userPassword"});
    }
    
    if ($error eq "") {
	$error	= CheckHome ($user{"homeDirectory"});
    }

#TODO CheckGECOS, CheckFullanme, Check*UI (?)

    # disable commit
    if ($error ne "") {
	$user_in_work{"check_error"} = $error;
    }
    return $error;
}


##------------------------------------
# check correctness of current group data
BEGIN { $TYPEINFO{CheckGroup} = ["function", "string"]; }
sub CheckGroup {

    my $error = CheckGID ();

    if ($error eq "") {
	$error = CheckGroupname ();
    }
    
    # disable commit
    if ($error ne "") {
	$group_in_work{"check_error"} = $error;
    }
    return $error;
}

##------------------------------------ LDAP related routines...
# Creates DN of user
BEGIN { $TYPEINFO{CreateUserDN} = ["function",
    ["map", "string", "any"],
    ["map", "string", "any"]];
}
sub CreateUserDN {

    return $_[0]; #FIXME
#    string dn_attr = ldap_user_naming_attr;
#    string user_attr = ldap2yast_user_attrs [dn_attr]:dn_attr;
#    return sformat ("%1=%2,%3", dn_attr, user[user_attr]:"", ldap_user_base);
}

BEGIN { $TYPEINFO{CreateGroupDN} = ["function",
    ["map", "string", "any"],
    ["map", "string", "any"]];
}
sub CreateGroupDN {

    return $_[0]; #TODO
#    string dn_attr = ldap_group_naming_attr;
#    string group_attr = ldap2yast_group_attrs [dn_attr]:dn_attr;
#    return sformat ("%1=%2,%3", dn_attr, group[group_attr]:"", ldap_group_base);
}


# EOF
