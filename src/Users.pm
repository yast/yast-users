#! /usr/bin/perl -w
#
# Users module
#

#TODO do not dereference large maps if not necessary...

package Users;

use strict;

use ycp;
use YaST::YCP qw(Boolean);

use Locale::gettext;
use POSIX ();     # Needed for setlocale()

POSIX::setlocale(LC_MESSAGES, "");
textdomain("users");

our %TYPEINFO;

# If YaST UI (Qt,ncurses) should be used. When this is off, some helper
# UI-related structures won't be generated.
my $use_gui			= 1;

# What client to call after authentication dialog during installation:
# could be "users","nis","nisplus" or "ldap", for more see inst_auth.ycp
my $after_auth			= "users";

# Write only, keep progress turned off
my $write_only			= 0; 

# Where the user/group/password data are stored (can be different on NIS server)
my $base_directory		= "/etc";

my $root_password		= "";

my %default_groupname		= ();

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

my %modified_users 		= (
    "local"		=> {},
    "system"		=> {}
);

my %modified_groups 		= ();

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
my @available_usersets		= ();
my @available_groupsets		= ();

# available shells (read from /etc/shells)
my %all_shells 			= ();


my $users_modified		= 0;
my $groups_modified		= 0;
my $ldap_modified		= 0;
my $customs_modified 		= 0;
my $defaults_modified 		= 0;
my $security_modified 		= 0;

# variables describing available users sets:
my $nis_available 		= 1;
my $ldap_available 		= 1;
my $nis_master			= 0;

# nis users are not read by default, but could be read on demand:
my $nis_not_read 		= 1;

# ldap users are not read by default, but could be read on demand:
my $ldap_not_read 		= 1;

# paths to commands that should be run before (after) adding (deleting) a user
my $useradd_cmd 		= "";
my $userdel_precmd 		= "";
my $userdel_postcmd 		= "";

my $pass_warn_age		= "7";
my $pass_min_days		= "0";
my $pass_max_days		= "99999";

# password encryption method
my $encryption_method		= "des";
my $use_cracklib 		= 1;
my $cracklib_dictpath		= "";
my $obscure_checks 		= 1;

# the +/- entries in config files:
my $plus_passwd			= "";
my $plus_group			= "";
my $plus_shadow 		= "";

# starting dialog for installation mode
my $start_dialog		= "summary";
my $use_next_time		= 0;

# if user should be warned when using uppercase letters in login name
my $not_ask_uppercase		= 0;

# which sets of users are we working with:
my @current_users		= ();
my @current_groups 		= ();

# mail alias for root
my $root_mail			= "";

my %min_pass_length	= (
    "local"		=> 5,
    "ldap"		=> 5,
    "system"		=> 5
);

my %max_pass_length	= (
    "local"		=> 8,
    "ldap"		=> 8,
    "system"		=> 8
);

# users sets in "Custom" selection:
my @user_custom_sets		= ();
my @group_custom_sets		= ();

# helper structures, filled from UsersLDAP
my %ldap2yast_user_attrs	= ();
my %ldap2yast_group_attrs	= ();
 
##------------------------------------
##------------------- global imports

YaST::YCP::Import ("SCR");
YaST::YCP::Import ("Autologin");
YaST::YCP::Import ("Directory");
YaST::YCP::Import ("Ldap");
YaST::YCP::Import ("MailAliases");
YaST::YCP::Import ("Mode");
YaST::YCP::Import ("Popup");
YaST::YCP::Import ("Security");
YaST::YCP::Import ("Service");
YaST::YCP::Import ("Progress");
YaST::YCP::Import ("Report");
YaST::YCP::Import ("UsersCache");
YaST::YCP::Import ("UsersLDAP");
YaST::YCP::Import ("UsersRoutines");
YaST::YCP::Import ("UsersUI");

##-------------------------------------------------------------------------
##----------------- various routines --------------------------------------

sub contains {

    foreach my $key (@{$_[0]}) {
	if ($key eq $_[1]) { return 1; }
    }
    return 0;
}

sub _ {
    return gettext ($_[0]);
}


sub DebugMap {
    UsersCache::DebugMap (@_);
}

##------------------------------------
BEGIN { $TYPEINFO{LastChangeIsNow} = ["function", "string"]; }
sub LastChangeIsNow {
    if (Mode::test ()) { return "0";}

    my %out = %{SCR::Execute (".target.bash_output", "date +%s")};
    my $seconds = $out{"stdout"} || "0";
    chomp $seconds;
    return sprintf ("%u", $seconds / (60*60*24));
}

BEGIN { $TYPEINFO{Modified} = ["function", "boolean"];}
sub Modified {

    my $ret =	$users_modified 	||
		$groups_modified	||
		$ldap_modified		||
		$customs_modified	||
		$defaults_modified	||
		$security_modified;

    return $ret;
}

BEGIN { $TYPEINFO{NISAvailable} = ["function", "boolean"]; }
sub NISAvailable {
    return $nis_available;
}

BEGIN { $TYPEINFO{NISNotRead} = ["function", "boolean"]; }
sub NISNotRead {
    return $nis_not_read;
}

BEGIN { $TYPEINFO{LDAPAvailable} = ["function", "boolean"]; }
sub LDAPAvailable {
    return $ldap_available;
}

BEGIN { $TYPEINFO{LDAPModified} = ["function", "boolean"]; }
sub LDAPModified {
    return $ldap_modified;
}

BEGIN { $TYPEINFO{LDAPNotRead} = ["function", "boolean"]; }
sub LDAPNotRead {
    return $ldap_not_read;
}

BEGIN { $TYPEINFO{SetLDAPNotRead} = ["function", "void", "boolean"]; }
sub SetLDAPNotRead {
    $ldap_not_read = $_[0];
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
    return $start_dialog eq $_[0];
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
}


BEGIN { $TYPEINFO{GetAvailableUserSets} = ["function", ["list", "string"]]; }
sub GetAvailableUserSets {
    return @available_usersets;
}

BEGIN { $TYPEINFO{GetAvailableGroupSets} = ["function", ["list", "string"]]; }
sub GetAvailableGroupSets {
    return @available_groupsets;
}
    
##------------------------------------
BEGIN { $TYPEINFO{GetCurrentUsers} = ["function", ["list", "string"]]; }
sub GetCurrentUsers {
    return @current_users;
}

BEGIN { $TYPEINFO{GetCurrentGroups} = ["function", ["list", "string"]]; }
sub GetCurrentGroups {
    return @current_groups;
}

##------------------------------------
# Change the current users set, additional reading could be necessary
# @param new the new current set
BEGIN { $TYPEINFO{ChangeCurrentUsers} = ["function", "boolean", "string"];}
sub ChangeCurrentUsers {

    my $new 	= $_[0];
    my @backup	= @current_users;

    if ($new eq "custom") {
        @current_users = @user_custom_sets;
    }
    else {
        @current_users = ( $new );
    }
    if (contains (\@current_users, "ldap") && $ldap_not_read) {
        if (!ReadNewSet ("ldap")) {
            @current_users = @backup;
            return 0;
        }
    }

    if (contains (\@current_users, "nis") && $nis_not_read) {
        if (!ReadNewSet ("nis")) {
            @current_users = @backup;
            return 0;
        }
    }

    # correct also possible change in custom itemlist
    if ($new eq "custom") {
	UsersCache::SetCustomizedUsersView (1);
    }

    UsersCache::SetCurrentUsers (\@current_users);
    return 1;
}

##------------------------------------
# Change the current group set, additional reading could be necessary
# @param new the new current set
BEGIN { $TYPEINFO{ChangeCurrentGroups} = ["function", "boolean", "string"];}
sub ChangeCurrentGroups {

    my $new 	= $_[0];
    my @backup	= @current_groups;

    if ($new eq "custom") {
        @current_groups = @group_custom_sets;
    }
    else {
        @current_groups = ( $new );
    }

    if (contains (\@current_groups, "ldap") && $ldap_not_read) {
        if (!ReadNewSet ("ldap")) {
            @current_groups = @backup;
            return 0;
        }
    }

    if (contains (\@current_groups, "nis") && $nis_not_read) {
        if (!ReadNewSet ("nis")) {
            @current_groups = @backup;
            return 0;
        }
    }

    # correct also possible change in custom itemlist
    if ($new eq "custom") {
	UsersCache::SetCustomizedGroupsView (1);
    }

    UsersCache::SetCurrentGroups (\@current_groups);
    return 1;
}


##------------------------------------
BEGIN { $TYPEINFO{ChangeCustoms} = ["function",
    "boolean",
    "string", ["list","string"]];
}
sub ChangeCustoms {

    my @new	= @{$_[1]};

    if ($_[0] eq "users") {
        my @old			= @user_custom_sets;
        @user_custom_sets 	= @new;
        $customs_modified	= ChangeCurrentUsers ("custom");
        if (!$customs_modified) {
            @user_custom_sets 	= @old;
	}
    }
    else
    {
        my @old			= @group_custom_sets;
        @group_custom_sets 	= @new;
        $customs_modified	= ChangeCurrentGroups ("custom");
        if (!$customs_modified) {
            @group_custom_sets 	= @old;
	}
    }
    return $customs_modified;
}


BEGIN { $TYPEINFO{AllShells} = ["function", ["list", "string"]];}
sub AllShells {
    return sort keys %all_shells;
}

BEGIN { $TYPEINFO{AfterAuth} = ["function", "string"];}
sub AfterAuth {
    return $after_auth;
}

BEGIN { $TYPEINFO{SetAfterAuth} = ["function", "void", "string"];}
sub SetAfterAuth {
    $after_auth = $_[0];
}

BEGIN { $TYPEINFO{NotAskUppercase} = ["function", "boolean"];}
sub NotAskUppercase {
    return $not_ask_uppercase;
}

BEGIN { $TYPEINFO{SetAskUppercase} = ["function", "void", "boolean"];}
sub SetAskUppercase {
    if ($not_ask_uppercase != $_[0]) {
        $not_ask_uppercase 	= $_[0];
	$customs_modified	= 1;
    }
}
    
    
##------------------------------------
BEGIN { $TYPEINFO{CheckHomeMounted} = ["function", "void"]; }
# Checks if the home directory is properly mounted (bug #20365)
sub CheckHomeMounted {

    if ( Mode::live_eval() || Mode::test() || Mode::config() ) {
	return "";
    }

    my $ret 		= "";
    my $mountpoint_in	= "";
    my $home 		= GetDefaultHome ("local");
    if (substr ($home, -1, 1) eq "/") {
	chop $home;
    }

    my @fstab = SCR::Read (".etc.fstab");
    foreach my $line (@fstab) {
	my %line	= %{$line};
        if ($line{"file"} eq $home) {
            $mountpoint_in = "/etc/fstab";
	}
    }

    if (SCR::Read (".target.size", "/etc/cryptotab") != -1) {
        my @cryptotab = SCR::Read (".etc.cryptotab");
	foreach my $line (@cryptotab) {
	    my %line	= %{$line};
            if ($line{"mount"} eq $home) {
		$mountpoint_in = "/etc/cryptotab";
	    }
        }
    }

    if ($mountpoint_in ne "") {
        my $mounted	= 0;
        my @mtab	= SCR::Read (".etc.mtab");
	foreach my $line (@mtab) {
	    my %line	= %{$line};
	    if ($line{"file"} eq $home) {
                $mounted = 1;
	    }
        }

        if (!$mounted) {
            return sprintf (
# Popup text: %1 is the directory (e.g. /home), %2 file name (e.g. /etc/fstab)
_("In %s, there is a mount point for the directory
%s, which is used as a default home directory for new
users, but this directory is not currently mounted.
If you add new users using the default values,
their home directories will be created in the current %s.
This can imply that these directories will not be accessible
after you mount correctly. Continue user configuration?"),
	    $mountpoint_in, $home, $home);
	}
    }
    return $ret;
}


##-------------------------------------------------------------------------
##----------------- get routines ------------------------------------------

##------------------------------------
BEGIN { $TYPEINFO{GetMinPasswordLength} = ["function", "integer", "string"]; }
sub GetMinPasswordLength {
    if (defined ($min_pass_length{$_[0]})) {
	return $min_pass_length{$_[0]};
    }
    else { return 5;}
}

##------------------------------------
BEGIN { $TYPEINFO{GetMaxPasswordLength} = ["function", "integer", "string"]; }
sub GetMaxPasswordLength {
    if (defined ($max_pass_length{$_[0]})) {
	return $max_pass_length{$_[0]};
    }
    else { return 8; }
}

##------------------------------------
BEGIN { $TYPEINFO{GetDefaultGrouplist} = ["function",
    ["map", "string", "integer"],
    "string"];
}
sub GetDefaultGrouplist {

    my $type		= $_[0];
    my %grouplist	= ();
    my $grouplist	= "";

    if ($type eq "ldap") {
	$grouplist	= UsersLDAP::GetDefaultGrouplist ();
    }
    else {
	$grouplist	= $useradd_defaults{"groups"};
    }
    foreach my $group (split (/,/, $grouplist)) {
	$grouplist{$group}	= 1;
    }
    return \%grouplist;
}

##------------------------------------
BEGIN { $TYPEINFO{GetDefaultGID} = ["function", "integer", "string"]; }
sub GetDefaultGID {

    my $type	= $_[0];
    my $gid	= $useradd_defaults{"group"};

    if ($type eq "ldap") {
	$gid	= UsersLDAP::GetDefaultGID ();
    }
    return $gid;
}

##------------------------------------
BEGIN { $TYPEINFO{GetDefaultShell} = ["function", "string", "string"]; }
sub GetDefaultShell {

    my $type = $_[0];

    if ($type eq "ldap") {
	return UsersLDAP::GetDefaultShell ();
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
	$home	= UsersLDAP::GetDefaultHome ();
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

    my $type	= $_[0];
    my %ret 	= (
            "shadowInactive"	=> $useradd_defaults{"inactive"},
            "shadowExpire"      => $useradd_defaults{"expire"},
            "shadowWarning"     => $pass_warn_age,
            "shadowMin"         => $pass_min_days,
            "shadowMax"         => $pass_max_days,
            "shadowFlag"        => "",
            "shadowLastChange"	=> "",
	    "userPassword"	=> ""
    );
    if ($type eq "ldap") {
	%ret	= %{UsersLDAP::GetDefaultShadow()};
    }
    return \%ret;
}


##------------------------------------
BEGIN { $TYPEINFO{GetDefaultGroupname} = ["function", "string", "string"]; }
sub GetDefaultGroupname {

    my $type = $_[0];

    if (defined $default_groupname{$type}) {
        return $default_groupname{$type};
    }
	
    my $gid	= GetDefaultGID ($type);
    my %group	= ();
    if ($type eq "ldap") {
	%group	= %{GetGroup ($gid, "ldap")};
    }
    if (!%group) {
	%group	= %{GetGroup ($gid, "local")};
    }
    if (!%group) {
	%group	= %{GetGroup ($gid, "system")};
    }
    if (%group) {
	$default_groupname{$type}	= $group{"groupname"};
        return $default_groupname{$type};
    }
}

##------------------------------------
BEGIN { $TYPEINFO{GetLoginDefaults} = ["function",
    ["map", "string", "string"]];
}
sub GetLoginDefaults {
    
    return \%useradd_defaults;   
}

# Change the structure with default values (/etc/defaults/useradd)
# @param new_defaults new values
# @param groupname the name of dew default group
##------------------------------------
BEGIN { $TYPEINFO{SetLoginDefaults} = ["function",
    "void",
    ["map", "string", "string"], "string"];
}
sub SetLoginDefaults {

    my %data			= %{$_[0]};
    $default_groupname{"local"}	= $_[1];
    $default_groupname{"system"}= $_[1];

    foreach my $key (keys %data) {
        if ($data{$key} ne  $useradd_defaults{$key}) {
            $useradd_defaults{$key} = $data{$key};
	    $defaults_modified = 1;
	}
    };

    if (substr ($useradd_defaults{"home"}, -1, 1) eq "/") {
	chop $useradd_defaults{"home"};
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
    if ($username =~ m/=/) {
	$username = UsersCache::get_first ($username);
# TODO maybe we should have users_by_dn set!
    }

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
	@types_to_look = sort keys %groups;
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
        };
    };
    return \%grouplist;
}

##-------------------------------------------------------------------------
##----------------- read routines -----------------------------------------

BEGIN { $TYPEINFO{GetUserCustomSets} = [ "function", ["list", "string"]]; }
sub GetUserCustomSets {
    return @user_custom_sets;
}

BEGIN { $TYPEINFO{GetGroupCustomSets} = [ "function", ["list", "string"]]; }
sub GetGroupCustomSets {
    return @group_custom_sets;
}

##------------------------------------
# Reads the set of values in "Custom" filter from disk and other internal
# variables ("not_ask")
sub ReadCustomSets {

    my $file = Directory::vardir()."/users.ycp";
    if (SCR::Read (".target.size", $file) == -1) {
	SCR::Execute (".target.bash", "/bin/touch $file");
	$customs_modified	= 1;
    }
    else {
	my $customs = SCR::Read (".target.ycp", $file);

	if (defined $customs && ref ($customs) eq "HASH") {
	    my %custom_map	= %{$customs};
	    if (defined ($custom_map{"custom_users"}) &&
		ref ($custom_map{"custom_users"}) eq "ARRAY")
	    {
		@user_custom_sets = @{$custom_map{"custom_users"}};
	    }
	    if (defined ($custom_map{"custom_groups"}) &&
		ref ($custom_map{"custom_groups"}) eq "ARRAY")
	    {
		@group_custom_sets = @{$custom_map{"custom_groups"}};
	    }
	    if (defined ($custom_map{"dont_warn_when_uppercase"})) {
		$not_ask_uppercase = $custom_map{"dont_warn_when_uppercase"};
	    }
	}
    }
    if (@user_custom_sets == 0) {
	@user_custom_sets = ("local");
    }
    if (@group_custom_sets == 0) {
	@group_custom_sets = ("local");
    }
}

##------------------------------------
# Read the /etc/shells file and return a item list or a string shell list.
# @param todo `items or `stringlist
# @return list of shells
BEGIN { $TYPEINFO{ReadAllShells} = ["function", "void"]; }
sub ReadAllShells {

    my @available_shells	= ();
    my $shells_s = SCR::Read (".target.string", "/etc/shells");
    my @shells_read = split (/\n/, $shells_s);

    foreach my $shell_entry (@shells_read) {

	if ($shell_entry eq "" || $shell_entry =~ m/^passwd|bash1$/) {
	    next;
	}
	if (SCR::Read (".target.size", $shell_entry) != -1) {
	    $all_shells{$shell_entry} = 1;
	}
    };
}

##------------------------------------
# Checks the possible user sources (NIS/LDAP available?)
BEGIN { $TYPEINFO{ReadSourcesSettings} = ["function", "void"]; }
sub ReadSourcesSettings {

    @available_usersets		= ( "local", "system" );
    @available_groupsets	= ( "local", "system" );

    $nis_available		= ReadNISAvailable ();
    $nis_master 		= ReadNISMaster ();
    $ldap_available 		= UsersLDAP::ReadAvailable ();

    if (!$nis_master && $nis_available) {
        push @available_usersets, "nis";
        push @available_groupsets, "nis";
    }
    if ($ldap_available) {
        push @available_usersets, "ldap";
        push @available_groupsets, "ldap";
    }
    push @available_usersets, "custom";
    push @available_groupsets, "custom";
}


##------------------------------------
BEGIN { $TYPEINFO{ReadSystemDefaults} = ["function", "void"]; }
sub ReadSystemDefaults {

    if (Mode::test ()) { return; }

    Progress::off ();
    Security::Read ();
    if ($use_gui) { Progress::on (); }

    my %security	= %{Security::Export ()};
    $pass_warn_age	= $security{"PASS_WARN_AGE"};
    $pass_min_days	= $security{"PASS_MIN_DAYS"};
    $pass_max_days	= $security{"PASS_MAX_DAYS"};

    # command running before/after adding/deleting user
    $useradd_cmd 	= $security{"USERADD_CMD"};
    $userdel_precmd 	= $security{"USERDEL_PRECMD"};
    $userdel_postcmd 	= $security{"USERDEL_POSTCMD"};

    $encryption_method	= $security{"PASSWD_ENCRYPTION"};
    $cracklib_dictpath	= $security{"CRACKLIB_DICTPATH"};
    $use_cracklib 	= ($security{"PASSWD_USE_CRACKLIB"} eq "yes");
    $obscure_checks 	= ($security{"OBSCURE_CHECKS_ENAB"} eq "yes");

    $min_pass_length{"local"}	= $security{"PASS_MIN_LEN"};
    $min_pass_length{"system"}	= $security{"PASS_MIN_LEN"};

    my %max_lengths		= %{Security::PasswordMaxLengths ()};
    $max_pass_length{"local"}	= $max_lengths{$encryption_method};
    $max_pass_length{"system"}	= $max_pass_length{"local"};

    UsersCache::InitConstants (\%security);
}

##------------------------------------
BEGIN { $TYPEINFO{ReadLoginDefaults} = ["function", "boolean"]; }
sub ReadLoginDefaults {

    foreach my $key (sort keys %useradd_defaults) {
        my $entry = SCR::Read (".etc.default.useradd.$key");
        if (!$entry) {
	    $entry = "";
	}
	$entry =~ s/\"//g;
        $useradd_defaults{$key} = $entry;
    }

    UsersLDAP::InitConstants (\%useradd_defaults);

    if (%useradd_defaults) {
        return 1;
    }
    return 0;
}

##------------------------------------
# Read new set of users - "on demand" (called from running module)
# @param type the type of users, currently "ldap" or "nis"
# @return success
BEGIN { $TYPEINFO{ReadNewSet} = ["function", "boolean", "string"]; }
sub ReadNewSet {

    my $type	= $_[0];
    if ($type eq "nis") {

        $nis_not_read = 0;
	
	$users{$type}		= \%{SCR::Read (".$type.users")};
	$users_by_name{$type}	= \%{SCR::Read (".$type.users.by_name")};
	$groups{$type}		= \%{SCR::Read (".$type.groups")};
	$groups_by_name{$type}	= \%{SCR::Read(".$type.groups.by_name")};

	UsersCache::BuildUserItemList ($type, $users{$type});
	UsersCache::BuildGroupItemList ($type, $groups{$type});
    }
    elsif ($type eq "ldap") {

	UsersLDAP::SetGUI ($use_gui);

	# read all needed LDAP settings now:
	if (!UsersLDAP::ReadSettings ()) {
	    return 0;
	}

	# generate ldap users/groups list in the agent:
	my $ldap_mesg = UsersLDAP::Read();
	if ($ldap_mesg ne "") {
            Ldap::LDAPErrorMessage ("read", $ldap_mesg);
	    # FIXME error as return value?
            return 0;
        }

	# read the LDAP data (users, groups, items)
	$users{$type}		= \%{SCR::Read (".$type.users")};
	$users_by_name{$type}	= \%{SCR::Read (".$type.users.by_name")};
	$groups{$type}		= \%{SCR::Read (".$type.groups")};
	$groups_by_name{$type}	= \%{SCR::Read(".$type.groups.by_name")};

	# read the necessary part of LDAP user configuration
	$min_pass_length{"ldap"}= UsersLDAP::GetMinPasswordLength ();
	$max_pass_length{"ldap"}= UsersLDAP::GetMaxPasswordLength ();

	%ldap2yast_user_attrs	= %{UsersLDAP::GetUserAttrsLDAP2YaST ()};
	%ldap2yast_group_attrs	= %{UsersLDAP::GetGroupAttrsLDAP2YaST ()};

	# TODO itemlist should be generated by ldap-agent...
	UsersCache::BuildUserItemList ($type, $users{$type});
	UsersCache::BuildGroupItemList ($type, $groups{$type});

        $ldap_not_read = 0;
    }
    UsersCache::ReadUsers ($type);
    UsersCache::ReadGroups ($type);

    return 1;
}


##------------------------------------
BEGIN { $TYPEINFO{ReadLocal} = ["function", "string"]; }
sub ReadLocal {

    my %configuration = (
	"max_system_uid"	=> UsersCache::GetMaxUID ("system"),
	"max_system_gid"	=> UsersCache::GetMaxGID ("system"),
	"base_directory"	=> $base_directory
    );
    # id limits are necessary for differ local and system users
    my $init = SCR::Execute (".passwd.init", \%configuration);
    if (!$init) {
	y2internal ("passwd agent init: $init");
#	my $error = SCR::Read (".passwd.error"); TODO
	return "passwd error";
    }

    foreach my $type ("local", "system") {
	$users{$type}		= \%{SCR::Read (".passwd.$type.users")};
	$users_by_name{$type}	= \%{SCR::Read (".passwd.$type.users.by_name")};
	$shadow{$type}		= \%{SCR::Read (".passwd.$type.shadow")};
	$groups{$type}		= \%{SCR::Read (".passwd.$type.groups")};
	$groups_by_name{$type}	= \%{SCR::Read(".passwd.$type.groups.by_name")};
    }

    $plus_passwd	= SCR::Read (".passwd.passwd.plusline");
    $plus_shadow	= SCR::Read (".passwd.shadow.plusline");
    $plus_group		= SCR::Read (".passwd.group.plusline");
    return "";
}

sub ReadUsersCache {
    
#    y2warning ("ReadUsersCache start");
    UsersCache::Read ();

#    y2warning ("ReadUsersCache 1");

    UsersCache::BuildUserItemList ("local", $users{"local"});
    UsersCache::BuildUserItemList ("system", $users{"system"});

#    y2warning ("ReadUsersCache 2");

    UsersCache::BuildGroupItemList ("local", $groups{"local"});
    UsersCache::BuildGroupItemList ("system", $groups{"system"});

#    y2warning ("ReadUsersCache 3");

    UsersCache::SetCurrentUsers (\@user_custom_sets);
    UsersCache::SetCurrentGroups (\@group_custom_sets);
#    y2warning ("ReadUsersCache finish");
}

##------------------------------------
BEGIN { $TYPEINFO{Read} = ["function", "boolean"]; }
sub Read {

    # progress caption
    my $caption 	= _("Initializing user and group configuration");
    my $no_of_steps 	= 5;

    if ($use_gui) {
	Progress::New ($caption, " ", $no_of_steps,
	    [
		# progress stage label
		_("Read the default login settings"),
		# progress stage label
		_("Read the default system settings"),
		# progress stage label
		_("Read the configuration type"),
		# progress stage label
		_("Read the user custom settings"),
		# progress stage label
		_("Read users and groups"),
		# progress stage label
		_("Build the cache structures")
           ],
	   [
		# progress step label
		_("Reading the default login settings..."),
		# progress step label
		 _("Reading the default system setttings..."),
		# progress step label
		 _("Reading the configuration type..."),
		# progress step label
		 _("Reading custom settings..."),
		# progress step label
		 _("Reading users and groups..."),
		# progress step label
		 _("Building the cache structures..."),
		# final progress step label
		 _("Finished")
	    ], "" );
    }

    $tmpdir = SCR::Read (".target.tmpdir");
    my $error_msg = "";

    # default login settings
    if ($use_gui) { Progress::NextStage (); }

    ReadLoginDefaults ();

    $error_msg = CheckHomeMounted();

    if ($use_gui && $error_msg ne "" && !Popup::YesNo ($error_msg)) {
	return 0; # problem with home directory: do not continue
    }

    # default system settings
    if ($use_gui) { Progress::NextStage (); }

    ReadSystemDefaults();

    ReadAllShells();

    # configuration type
    if ($use_gui) { Progress::NextStage (); }

    ReadSourcesSettings();

    if ($nis_master && $use_gui && !Mode::cont()) {
	my $directory = UsersUI::ReadNISConfigurationType ($base_directory);
	if (!defined ($directory)) {
	    return 0; # aborted in NIS server dialog
	}
	else {
	    $base_directory = $directory;
	}
    }

    # custom settings
    if ($use_gui) { Progress::NextStage (); }

    ReadCustomSets();

    # users and group
    if ($use_gui) { Progress::NextStage (); }

    $error_msg = ReadLocal ();
    if ($error_msg) {
	Report::Error ($error_msg);
	return 0; # problem with reading config files ( /etc/passwd etc.)
    }

    # Build the cache structures
    if ($use_gui) { Progress::NextStage (); }

    ReadUsersCache ();

    Autologin::Read ();

    if (Mode::cont () ) {
	Autologin::Use (YaST::YCP::Boolean (1));
    }

    return 1;
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
    
    my %default_shadow = %{GetDefaultShadow ($user{"type"})};
    foreach my $shadow_item (keys %default_shadow) {
	$shadow_map{$shadow_item}	= $user{$shadow_item};
    };
    return \%shadow_map;
}

##------------------------------------
# Remove user from the list of members of current group
BEGIN { $TYPEINFO{RemoveUserFromGroup} = ["function", "boolean", "string"]; }
sub RemoveUserFromGroup {

    my $ret		= 0;
    my $user		= $_[0];
    my $group_type	= $group_in_work{"type"};

    if ($group_type eq "ldap") {
        $user           = $user_in_work{"dn"};
	if (defined $user_in_work{"org_dn"}) {
	    $user	= $user_in_work{"org_dn"};
	}
	if (defined $group_in_work{"uniqueMember"}{$user}) {
	    delete $group_in_work{"uniqueMember"}{$user};
	    $ret			= 1;
	    $group_in_work{"what"}	= "user_change";
	}
    }
    elsif (defined $group_in_work{"userlist"}{$user}) {
	$ret			= 1;
	$group_in_work{"what"}	= "user_change";
	delete $group_in_work{"userlist"}{$user};
    }
    return $ret;
}

##------------------------------------ 
# Add user to the members list of current group (group_in_work)
BEGIN { $TYPEINFO{AddUserToGroup} = ["function", "boolean", "string"]; }
sub AddUserToGroup {

    my $ret		= 0;
    my $user		= $_[0];
    my $group_type	= $group_in_work{"type"};

    if ($group_type eq "ldap") {
        $user           = $user_in_work{"dn"};
	if (!defined $group_in_work{"uniqueMember"}{$user}) {
            $group_in_work{"uniqueMember"}{$user}	= 1;
	    $group_in_work{"what"}			= "user_change";
	    $ret					= 1;
	}
    }
    elsif (!defined $group_in_work{"userlist"}{$user}) {
        $group_in_work{"userlist"}{$user}	= 1;
        $ret					= 1;
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
	    if ($key eq "userPassword") {
		next;
	    }
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
    UsersCache::SetUserType ($user_in_work{"type"});
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
    UsersCache::SetGroupType ($group_in_work{"type"});
}


##------------------------------------
# boolean parameter means "delete home directory"
BEGIN { $TYPEINFO{DeleteUser} = ["function", "boolean", "boolean" ]; }
sub DeleteUser {

    if (%user_in_work) {
	$user_in_work{"what"}		= "delete_user";
y2internal ("param: ", $_[0]);#FIXME FIXME
	if (YaST::YCP::Boolean ($_[0])) {
	    $user_in_work{"delete_home"}	= YaST::YCP::Boolean ($_[0]);
	}
	return 1;
    }
    return 0;
}

##------------------------------------
BEGIN { $TYPEINFO{DeleteGroup} = ["function", "boolean" ]; }
sub DeleteGroup {

    if (%group_in_work) {
	$group_in_work{"what"}	= "delete_group";
	return 1;
    }
    return 0;
}


##------------------------------------
#Edit is used in 2 diffr. situations
#	1. initialization (creates "org_user")	- could be in SelectUser?
#	2. save changed values into user_in_work
BEGIN { $TYPEINFO{EditUser} = ["function",
    "boolean",
    ["map", "string", "any" ]];		# data to change in user_in_work
}
sub EditUser {

    if (!%user_in_work) { return 0; }

    my %data		= %{$_[0]};
    my $type		= $user_in_work{"type"} || "";

    if (defined $data{"type"}) {
	$type 	= $data{"type"};
    }
    my $username	= $data{"username"};

    # check if user is edited for first time
    if (!defined $user_in_work{"org_user"} &&
	($user_in_work{"what"} || "") ne "add_user") {

	# save first map for later checks of modification (in Commit)
	my %org_user			= %user_in_work;
	$user_in_work{"org_user"}	= \%org_user;

	# grouplist wasn't fully generated while reading nis & ldap users
	if ($type eq "nis" || $type eq "ldap") {
	    $user_in_work{"grouplist"} = FindGroupsBelongUser (\%org_user);
	}
	# empty password entry for autoinstall config (do not want to
	# read password from disk: #30573)
	if (Mode::config () && $user_in_work{"userPassword"} eq "x") {
	    $user_in_work{"userPassword"} = "";
	}
    }
    # update the settings which should be changed
    foreach my $key (keys %data) {
	if ($key eq "username" || $key eq "homeDirectory" ||
	    $key eq "uidNumber" || $key eq "type" ||
	    $key eq "groupname") # || $key eq "dn")
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
	# change of DN requires special handling:
	if ($type eq "ldap" && $key eq "dn") {

	    my $new_dn	= UsersLDAP::CreateUserDN (\%data);
	    if (defined $new_dn && ($user_in_work{$key} ne $new_dn ||
				    !defined $user_in_work{"org_dn"})) {
		$user_in_work{"org_dn"} = $user_in_work{$key}; 	
		$user_in_work{$key}	= $new_dn;
		next;
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
	if ($key eq "create_home" || $key eq "encrypted") {
	    $user_in_work{$key}	= YaST::YCP::Boolean ($data{$key});
	    next;
	}
	if ($key eq "userPassword" && $data{$key} ne "" && $data{$key} ne "x") {
	    # crypt password only once (when changed)
	    if (!defined ($data{"encrypted"})) {
		$user_in_work{$key} 	= CryptPassword ($data{$key}, $type);
		$user_in_work{"encrypted"}	= YaST::YCP::Boolean (1);
		next;
	    }
	}
	$user_in_work{$key}	= $data{$key};
    }
    $user_in_work{"what"}	= "edit_user";
    UsersCache::SetUserType ($type);
    return 1;
}

##------------------------------------
BEGIN { $TYPEINFO{EditGroup} = ["function",
    "boolean",
    ["map", "string", "any" ]];		# data to change in group_in_work
}
sub EditGroup {

    if (!%group_in_work) { return 0; }

    my %data	= %{$_[0]};
    my $type	= $group_in_work{"type"};

    if (defined $data{"type"}) {
	$type = $data{"type"};
    }

    # update the settings which should be changed
    foreach my $key (keys %data) {
	if ($key eq "groupname" || $key eq "gidNumber" || $key eq "type") {
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
	# change of DN requires special handling:
	if ($type eq "ldap" && $key eq "dn") {

	    my $new_dn	= UsersLDAP::CreateGroupDN (\%data);
	    if (defined $new_dn && ($group_in_work{$key} ne $new_dn ||
				    !defined $group_in_work{"org_dn"}))
	    {
		$group_in_work{"org_dn"} 	= $group_in_work{$key}; 	
		$group_in_work{$key}		= $new_dn;
		next;
	    }
	}
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
	# same, but for LDAP groups
	if ($key eq "uniqueMember" && defined $group_in_work{"uniqueMember"}) {
	    my %removed = ();
	    foreach my $user (keys %{$group_in_work{"uniqueMember"}}) {
		if (!defined $data{"uniqueMember"}{$user}) {
		    $removed{$user} = 1;
		}
	    }
	    if (%removed) {
		$group_in_work{"removed_userlist"} = \%removed;
	    }
	}
	if ($key eq "userPassword" && $data{$key} ne "" && $data{$key} ne "x"
	    && $data{$key} ne "!") {
	    # crypt password only once (when changed)
	    if (!defined ($data{"encrypted"})) {
		$group_in_work{$key} 	= CryptPassword ($data{$key}, $type);
		$group_in_work{"encrypted"}	= YaST::YCP::Boolean (1);
		next;
	    }
	}
	$group_in_work{$key}	= $data{$key};
    }
    $group_in_work{"what"}	= "edit_group";

    UsersCache::SetGroupType ($type);
    return 1;
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
    my $type;

    if (!%data) {
	# adding totaly new entry - e.g. from the summary table
	# Must be called, or some old entries in user_in_work could be used!
	ResetCurrentUser ();
	# this is necessary to know when to check uniquity of username etc.
    }

    if (defined $data{"type"}) {
	$type = $data{"type"};
    }

    # guess the type of new user from the list of users currently shown
    if (!defined $type) {
	$type	= "local";
	my $i	= @current_users - 1;
	while ($i >= 0 )
	{
	    # nis user cannot be added from client
	    if ($current_users[$i] ne "nis") {
		$type = $current_users[$i];
	    }
	    $i --;
	}
    }

    foreach my $key (keys %data) {
	if ($key eq "create_home" || $key eq "encrypted") {
	    $user_in_work{$key}	= YaST::YCP::Boolean ($data{$key});
	}
	elsif ($key eq "userPassword") {
	    # crypt password only once
	    if (!defined ($data{"encrypted"})) {
		$user_in_work{$key} 	= CryptPassword ($data{$key}, $type);
		$user_in_work{"encrypted"}	= YaST::YCP::Boolean (1);
	    }
	}
	else {
	    $user_in_work{$key}	= $data{$key};
	}
    }
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
	$user_in_work{"create_home"}	= YaST::YCP::Boolean (1);
    }
    my %default_shadow = %{GetDefaultShadow ($type)};
    foreach my $shadow_item (keys %default_shadow) {
	if (!defined $user_in_work{$shadow_item}) {
	    $user_in_work{$shadow_item}	= $default_shadow{$shadow_item};
	}
    }
    if (!defined $user_in_work{"shadowLastChange"} ||
	$user_in_work{"shadowLastChange"} eq "") {
        $user_in_work{"shadowLastChange"} = LastChangeIsNow ();
    }
    if (!defined $user_in_work{"userPassword"}) {
	$user_in_work{"userPassword"}	= "";
    }

    if ($type eq "ldap") {
	# add default object classes
	if (!defined $user_in_work{"objectClass"}) {
	    my @classes = UsersLDAP::GetUserClass();
	    $user_in_work{"objectClass"} = \@classes;
	}
        # add other default values
	my %ldap_defaults	= %{UsersLDAP::GetUserDefaults()};
	foreach my $attr (keys %ldap_defaults) {
	    my $a = $ldap2yast_user_attrs{$attr} || $a;
	    if (!defined ($user_in_work{$attr})) {
		$user_in_work{$attr}	= $ldap_defaults{$attr};
	    }
	};
	if (!defined $user_in_work{"dn"}) {
	    my $dn = UsersLDAP::CreateUserDN (\%data);
	    if (defined $dn) {
		$user_in_work{"dn"} = $dn;
	    }
	}
    }
    return 1;
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
    my $type;

    if (!%data) {
	ResetCurrentGroup ();
    }

    if (defined $data{"type"}) {
	$type = $data{"type"};
    }
    # guess the type of new group from the list of groups currently shown
    if (!defined $type) {
	$type	= "local";
	my $i	= @current_groups - 1;
	while ($i >= 0 ) {
	    # nis group cannot be added from client
	    if ($current_groups[$i] ne "nis") {
		$type = $current_groups[$i];
	    }
	    $i --;
	}
    }

    foreach my $key (keys %data) {
	if ($key eq "userPassword") {
	    # crypt password only once
	    if (!defined ($data{"encrypted"})) {
		$group_in_work{$key} 	= CryptPassword ($data{$key}, $type);
		$group_in_work{"encrypted"}	= YaST::YCP::Boolean (1);
	    }
	}
	$group_in_work{$key}	= $data{$key};
    }

    $group_in_work{"type"}		= $type;
    $group_in_work{"what"}		= "add_group";
	
    UsersCache::SetGroupType ($type);

    if (!defined $group_in_work{"gidNumber"}) {
	$group_in_work{"gidNumber"}	= UsersCache::NextFreeGID ($type);
    }
    
    if ($type eq "ldap") {
	# add default object classes
	if (!defined $group_in_work{"objectClass"}) {
	    my @classes = UsersLDAP::GetGroupClass();
	    $group_in_work{"objectClass"} = \@classes;
	}
        # add other default values
	my %ldap_defaults	= %{UsersLDAP::GetGroupDefaults()};
	foreach my $attr (keys %ldap_defaults) {
	    my $a = $ldap2yast_group_attrs{$attr} || $a;
	    if (!defined ($group_in_work{$attr})) {
		$group_in_work{$attr}	= $ldap_defaults{$attr};
	    }
	};
	if (!defined $group_in_work{"dn"}) {
	    my $dn = UsersLDAP::CreateGroupDN (\%data);
	    if (defined $dn) {
		$group_in_work{"dn"} = $dn;
	    }
	}
    }
    return 1;
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
	}
	return $ret;
    }
    # search result, because some attributes were not filled yet
    my @internal_keys	= UsersLDAP::GetUserInternal ();
    foreach my $key (keys %user) {

	my $value = $user{$key};
	if (!defined $user{$key} || contains (\@internal_keys, $key) ||
	    ref ($value) eq "HASH" ) {
	    next;
	}
	if (!defined ($user{"org_user"}{$key})) {
	    if ($value ne "") {
		$ret = 1;
	    }
	}
	elsif (ref ($value) eq "ARRAY") {
	    if (@{$user{"org_user"}{$key}} ne @{$value}) {
		$ret = 1;
	    }
	}
        elsif ($user{"org_user"}{$key} ne $value) {
	    $ret = 1;
	}
    }
    return $ret;
}


##------------------------------------
# Update the global map of users using current user or group
BEGIN { $TYPEINFO{CommitUser} = ["function", "boolean"] }
sub CommitUser {

    if (!%user_in_work) { return 0; }
    if (defined $user_in_work{"check_error"}) {
        y2error ("commit is forbidden: ", $user_in_work{"check_error"});
	return 0;
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
    my $groupname	= $user{"groupname"} || GetDefaultGroupname ($type);
    my $home		= $user{"homeDirectory"};
    my %grouplist	= %{$user{"grouplist"}};

    if (($type eq "local" || $type eq "system") &&
	!$users_modified && UserReallyModified (\%user)) {
	    $users_modified = 1;
    }
    if ($type eq "ldap" && !$ldap_modified && UserReallyModified (\%user)) {
        $ldap_modified = 1;
    }

    y2internal ("commiting user '$username', action is '$what_user', modified: $users_modified");

    # --- 1. do the special action
    if ($what_user eq "add_user") {
	
        $user{"modified"}	= "added";

	if ($type eq "ldap") {
	    %user = %{UsersLDAP::SubstituteValues ("user", \%user)};
	}

        # update the affected groups
        foreach my $group (keys %grouplist) {
            %group_in_work = %{GetGroupByName ($group, $type)};
            if (%group_in_work && AddUserToGroup ($username)) {
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
        if (defined $removed_homes{$home}) {
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
	        if (AddUserToGroup ($username)) {
		   CommitGroup ();
	        }
	    }
        };

        # check if user was removed from some additional groups
	if (defined $user{"removed_grouplist"}) {
            foreach my $group (keys %{$user{"removed_grouplist"}}) {
	        %group_in_work = %{GetGroupByName ($group, $type)};
	        if (%group_in_work &&
		    RemoveUserFromGroup ($org_username)) {
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
        if (defined $removed_homes{$home}) {
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
	        RemoveUserFromGroup ($org_username)) {
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
y2internal ("delete: ", $user{"delete_home"});
y2internal ("delete: ", $user{"delete_home"} || 0);
# FIXME boolean value cannot be tested???
# - same for create_home etc.
	if ($type ne "ldap" && ($user{"delete_home"} || 0)) {
	    my $h	= $home;
	    if (defined $user{"org_user"}{"homeDirectory"}) {
	        $h	= $user{"org_user"}{"homeDirectory"};
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
	if (defined $modified_users{$type}{$uid}) {
	    delete $modified_users{$type}{$uid};
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

        $user{"org_uidNumber"}			= $uid;
        $user{"org_username"}			= $username;
        $user{"org_homeDirectory"}		= $home;
        $users{$type}{$uid}			= \%user;
        $users_by_name{$type}{$username}	= $uid;

	if ((($user{"modified"} || "") ne "") && $what_user ne "group_change") {
	    $modified_users{$type}{$uid}	= \%user;
	}
    }
    undef %user_in_work;
    return 1;
}

##------------------------------------
# Update the global map of groups using current group
BEGIN { $TYPEINFO{CommitGroup} = ["function", "boolean"]; }
sub CommitGroup {

    if (!%group_in_work || !defined $group_in_work{"gidNumber"} ||
	!defined $group_in_work{"groupname"}) {
	return 0;
    }

    if (defined $group_in_work{"check_error"}) {
        y2error ("commit is forbidden: ", $group_in_work{"check_error"});
        return 0;
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
    my %userlist	= ();
    if (defined $group{"userlist"}) {
	%userlist	= %{$group{"userlist"}};
    }
    y2internal ("commiting group '$groupname', action is '$what_group'");

    if ($type eq "system" || $type eq "local") {
	$groups_modified = 1;
    }
    if ($type eq "ldap" && $what_group ne "") {
	$ldap_modified	= 1;
	if (defined $group{"uniqueMember"}) {
	    %userlist	= %{$group{"uniqueMember"}};
	}
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
                if (defined $user_in_work{"grouplist"}{$org_groupname}) {
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
	if (!defined $group{"modified"} || $group{"modified"} ne "added") {
	    $group {"modified"}			= "deleted";
            $removed_groups{$type}{$org_gid}	= \%group;
        }
	delete $groups{$type}{$org_gid};
        delete $groups_by_name{$type}{$org_groupname};

	if (defined $modified_groups{$type}{$gid}) {
	    delete $modified_groups{$type}{$gid};
	}
    }
    elsif ( $what_group eq "user_change" ) # do not call Commit again
    {
        if (!defined $group{"modified"}) {
            $group{"modified"}	= "edited";
        }
    }

    # 2. common action: update groups
    UsersCache::CommitGroup (\%group);
    if ($what_group ne "delete_group") { # also for "user_change"
        
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

	if (($group{"modified"} || "") ne "") {
	    $modified_groups{$type}{$gid}	= \%group;
	}
    }
    undef %group_in_work;
    return 1;
}

##-------------------------------------------------------------------------
##----------------- write routines ----------------------------------------

##------------------------------------
# Writes the set of values in "Custom" filter and other internal variables
sub WriteCustomSets {

    my %customs = (
        "custom_users"			=> \@user_custom_sets,
        "custom_groups"			=> \@group_custom_sets,
    );
    $customs{"dont_warn_when_uppercase"} =
	YaST::YCP::Boolean ($not_ask_uppercase);
    my $ret = SCR::Write (".target.ycp", Directory::vardir()."/users.ycp", \%customs);

    y2milestone ("Custom user information written: ", $ret);
    return $ret;
}

##------------------------------------
# Writes settings to /etc/defaults/useradd
sub WriteLoginDefaults {

    my $ret = 1;

    while ( my ($key, $value) = each %useradd_defaults) {
	$ret = $ret && SCR::Write (".etc.default.useradd.$key", $value);
    }

    y2milestone ("Succesfully written useradd defaults: $ret");
    return $ret;
}

##------------------------------------
# Save Security settings (encryption method) if changed in Users module
BEGIN { $TYPEINFO{WriteSecurity} = ["function", "boolean"]; }
sub WriteSecurity {

    my $ret = 1;
    if ($security_modified) {
	
	my %security	= (
	    "PASSWD_ENCRYPTION"	=> $encryption_method
	);
	Security::Import (\%security);
	Progress::off();
	$ret = Security::Write();
	if (!$write_only && $use_gui) {
	    Progress::on();
	}
    }
    y2milestone ("Security module settings written: $ret");	
    return $ret;
}


##------------------------------------
BEGIN { $TYPEINFO{WriteGroup} = ["function", "boolean"]; }
sub WriteGroup {

    return SCR::Write (".passwd.groups", \%groups);
}

##------------------------------------
BEGIN { $TYPEINFO{WritePasswd} = ["function", "boolean"]; }
sub WritePasswd {
    return SCR::Write (".passwd.users", \%users);
}

##------------------------------------
BEGIN { $TYPEINFO{WriteShadow} = ["function", "boolean"]; }
sub WriteShadow {
    
    return SCR::Write (".passwd.shadow", \%shadow);
}

##------------------------------------
sub DeleteUsers {

    my $ret = 1;

    foreach my $type ("system", "local") {
	if (!defined $removed_users{$type}) { next; }
	foreach my $uid (keys %{$removed_users{$type}}) {
	    my %user = %{$removed_users{$type}{$uid}};
	    my $cmd = "$userdel_precmd $user{\"username\"} $uid $user{\"gidNumber\"} $user{\"homeDirectory\"}";
	    SCR::Execute (".target.bash", $cmd);
	};
    };

    foreach my $home (keys %removed_homes) {
	$ret = $ret && UsersRoutines::DeleteHome ($home);
    };

    foreach my $type ("system", "local") {
	if (!defined $removed_users{$type}) { next; }
	foreach my $uid (keys %{$removed_users{$type}}) {
	    my %user = %{$removed_users{$type}{$uid}};
	    my $cmd = "$userdel_postcmd $user{\"username\"} $uid $user{\"gidNumber\"} $user{\"homeDirectory\"}";
	    SCR::Execute (".target.bash", $cmd);
	};
    };
    return $ret;
}

##------------------------------------
BEGIN { $TYPEINFO{Write} = ["function", "string"]; }
sub Write {

    my $ret	= ""; #FIXME return value???

    # progress caption
    my $caption 	= _("Writing user and group configuration...");
    my $no_of_steps = 8;

    if ($use_gui) {
	Progress::New ($caption, " ", $no_of_steps,
	    [
		# progress stage label
		_("Write groups"),
		# progress stage label
		_("Check for deleted users"),
		# progress stage label
		_("Write users"),
		# progress stage label
		_("Write passwords"),
		# progress stage label
		_("Write LDAP users and groups"),
		# progress stage label
		_("Write the custom settings"),
		# progress stage label
		_("Write the default login settings")
           ], [
		# progress step label
		_("Writing groups..."),
		# progress step label
		_("Checking deleted users..."),
		# progress step label
		_("Writing users..."),
		# progress step label
		_("Writing passwords..."),
		# progress step label
		_("Writing LDAP users and groups..."),
		# progress step label
		_("Writing the custom settings..."),
		# progress step label
		_("Writing the default login settings..."),
		# final progress step label
		_("Finished")
	    ], "" );
    } 

    # Write groups 
    if ($use_gui) { Progress::NextStage (); }

    if ($groups_modified) {
        if (! WriteGroup ()) {
            Report::Error (_("Cannot write group file."));
	    $ret = _("Cannot write group file.");
        }
        # remove the group cache for nscd (bug 24748)
        SCR::Execute (".target.bash", "/usr/sbin/nscd -i group");
    }

    # Check for deleted users
    if ($use_gui) { Progress::NextStage (); }

    if ($users_modified) {
        if (!DeleteUsers ()) {
            Report::Error (_("Error while removing users."));
	    $ret = _("Error while removing users.");
	}
    }

    # Write users
    if ($use_gui) { Progress::NextStage (); }

    if ($users_modified) {
        if (!WritePasswd ()) {
            Report::Error (_("Cannot write passwd file."));
	    $ret = _("Cannot write passwd file.");
	}
	# remove the passwd cache for nscd (bug 24748)
        SCR::Execute (".target.bash", "/usr/sbin/nscd -i passwd");

	# check for homedir changes
        foreach my $type (keys %modified_users)  {
	    if ($type eq "ldap") {
		next; #homes for LDAP are ruled in WriteLDAP
	    }
	    foreach my $uid (keys %{$modified_users{$type}}) {
	    
		my %user	= %{$modified_users{$type}{$uid}};
		my $home 	= $user{"homeDirectory"} || "";
		my $username 	= $user{"username"} || "";
		my $command 	= "";
		my $user_mod 	= $user{"modified"} || "no";
		my $gid 	= $user{"gidNumber"};
       
		if ($user_mod eq "imported" || $user_mod eq "added") {
#FIXME "create_home" not correctly checked...
y2warning ("create: ", $user{"create_home"} || 0);
		    if ((($user{"create_home"} || 0) || $user_mod eq "imported")
			&& !%{SCR::Read (".target.stat", $home)})
		    {
			UsersRoutines::CreateHome ($useradd_defaults{"skel"},$home);
		    }
		    UsersRoutines::ChownHome ($uid, $gid, $home);
		    # call the useradd.local
		    $command = sprintf ("%s %s", $useradd_cmd, $username);
		    y2milestone ("'$command' return value: ", 
			SCR::Execute (".target.bash", $command));
		}
		elsif ($user_mod eq "edited") {
#		    my $org_home = $user{"org_homeDirectory"} || $home;
		    my $org_home = $user{"org_user"}{"homeDirectory"} || $home;
		    if ($home ne $org_home) {
			# move the home directory
			if ($user{"create_home"} || 0) {
			    UsersRoutines::MoveHome ($org_home, $home);
			}
		    }
		    UsersRoutines::ChownHome ($uid, $gid, $home);
		}
	    }
	}
    }

    # Write passwords
    if ($use_gui) { Progress::NextStage (); }

    if ($users_modified) {
        if (! WriteShadow ()) {
	    $ret = _("Cannot write shadow file.");
            Report::Error (_("Cannot write shadow file."));
        }
    }

    # Write LDAP users and groups
    if ($use_gui) { Progress::NextStage (); }

    if ($ldap_modified) {
	# TODO return value from UsersLDAP::Write
	if (defined ($removed_users{"ldap"})) {
	    UsersLDAP::WriteUsers ($removed_users{"ldap"});
	}
	
	if (defined ($modified_users{"ldap"})) {
	    UsersLDAP::WriteUsers ($modified_users{"ldap"});
	}

	if (defined ($removed_groups{"ldap"})) {
	    UsersLDAP::WriteGroups ($removed_groups{"ldap"});
	}

	if (defined ($modified_groups{"ldap"})) {
	    UsersLDAP::WriteGroups ($modified_groups{"ldap"});
	}
    }

    # call make on NIS server
    if (($users_modified || $groups_modified) && $nis_master) {
        my %out	= %{SCR::Execute (".target.bash_output",
	    "/usr/bin/make -C /var/yp")};
        if (!defined ($out{"exit"}) || $out{"exit"} != 0) {
            y2error ("Cannot make NIS database: ", %out);
        }
    }

    # Write the custom settings
    if ($use_gui) { Progress::NextStage (); }

    if ($customs_modified) {
        WriteCustomSets();
    }

    # Write the default login settings
    if ($use_gui) { Progress::NextStage (); }

    if ($defaults_modified) {
        WriteLoginDefaults();
    }

    if ($security_modified) {
	WriteSecurity();
    }

    # mail forward from root
    if (Mode::cont () && $root_mail ne "" &&
	!MailAliases::SetRootAlias ($root_mail)) {
        
	# error popup
        $ret =_("There was an error while setting forwarding for root's mail.");
    }

    Autologin::Write (Mode::cont () || $write_only);

    # do not show user in first dialog when all has been writen
    if (Mode::cont ()) {
        $use_next_time	= 0;
        undef %saved_user;
        undef %user_in_work;
    }

    return $ret;
}

##-------------------------------------------------------------------------
##----------------- check routines (TODO move outside...) ---------

# "-" means range! -> at the begining or at the end!
my $valid_logname_chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ._-";

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

    if (!defined $uid) {
	return _("There is no free UID for this type of user.");
    }

    if (("add_user" eq ($user_in_work{"what"} || "")) 	||
	($uid != ($user_in_work{"uidNumber"} || 0))	||
	(defined $user_in_work{"org_uidNumber"} && 
		 $user_in_work{"org_uidNumber"} != $uid)) {

	if (UsersCache::UIDExists ($uid)) {
	    return _("The user ID entered is already in use.
Select another user ID.");
	}
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
	return sprintf (_("The selected user ID is not allowed.
Select a valid integer between %i and %i."), $min, $max);
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
    my $type	= UsersCache::GetUserType ();
    my %ret	= ();

    if (($ui_map{"local"} || 0) != 1) {
	if ($type eq "system" &&
	    $uid > UsersCache::GetMinUID ("local") &&
	    $uid < UsersCache::GetMaxUID ("local"))
	{
	    $ret{"question_id"}	= "local";
	    $ret{"question"}	= sprintf(_("The selected user ID is a local ID,
because the ID is greater than %i.
Really change type of user to 'local'?"), UsersCache::GetMinUID ("local"));
	    return \%ret;
	}
    }

    if (($ui_map{"system"} || 0) != 1) {
	if ($type eq "local" &&
	    $uid > UsersCache::GetMinUID ("system") &&
	    $uid < UsersCache::GetMaxUID ("system"))
	{
	    $ret{"question_id"}	= "system";
	    $ret{"question"}	= sprintf (
_("The selected user ID is a system ID,
because the ID is smaller than %i.
Really change type of user to 'system'?"), UsersCache::GetMaxUID ("system"));
	    return \%ret;
	}
    }
    return \%ret;
    # SetUserType has to be called after this function...!
}

##------------------------------------
# check the username of current user
BEGIN { $TYPEINFO{CheckUsername} = ["function", "string", "string"]; }
sub CheckUsername {

    my $username	= $_[0];

    if (!defined $username || $username eq "") {
        return _("You didn't enter a username.
Please try again.");
    }
    
    if (length ($username) < $UsersCache::min_length_login ||
	length ($username) > $UsersCache::max_length_login ) {

	return sprintf (_("The user name must be between %i and %i characters in length.
Try again."), $UsersCache::min_length_login, $UsersCache::max_length_login);
    }
	
    my $filtered = $username;
    $filtered =~ s/[$valid_logname_chars]//g;

    my $first = substr ($username, 0, 1);
    if ($first ne "_" && ($first lt "A" || $first gt "z" ) || $filtered ne "") { 
	return _("The user login may contain only
letters, digits, \"-\", \".\", and \"_\"
and must begin with a letter or \"_\".
Try again.");
    }

    if (("add_user" eq ($user_in_work{"what"} || "")) ||
	($username ne ($user_in_work{"username"} || "")) ||
	(defined $user_in_work{"org_username"} && 
		 $user_in_work{"org_username"} ne $username)) {

	if (UsersCache::UsernameExists ($username)) {
	    return _("There is a conflict between the entered
user name and an existing user name.
Try another one.");
	}
    }
    return "";
    
}

##------------------------------------
# check fullname contents
BEGIN { $TYPEINFO{CheckFullname} = ["function", "string", "string"]; }
sub CheckFullname {

    my $fullname	= $_[0];

    if ($fullname =~ m/[:,]/) {
        return _("The full user name cannot contain
\":\" or \",\" characters.
Try again.");
    }
    return "";
}

##------------------------------------
# check 'additional information': part of gecos field without the fullname
BEGIN { $TYPEINFO{CheckGECOS} = ["function", "string", "string"]; }
sub CheckGECOS {

    my $gecos		= $_[0];

    if (!defined $gecos) {
	return "";
    }
    if ($gecos =~ m/:/) {
        return _("The \"Additional User Information\" entry cannot
contain a colon (:).  Try again.");
    }
    
    my @gecos_l = split (/,/, $gecos);
    if (@gecos_l > 3 ) {
        return _("The \"Additional User Information\" entry can consist
of up to three sections separated by commas.
Remove the surplus.");
    }
    
    return "";
}

##------------------------------------
# check the password of current user
BEGIN { $TYPEINFO{CheckPassword} = ["function", "string", "string"]; }
sub CheckPassword {

    my $pw 		= $_[0];
    my $type		= UsersCache::GetUserType ();
    my $min_length 	= $min_pass_length{$type};
    my $max_length 	= $max_pass_length{$type};

    if (($pw || "") eq "") {
            
	return _("You didn't enter a password.
Please try again.");
    }

    if (length ($pw) < $min_length) {
        return sprintf (_("The password must have between %i and %i characters.
Please try again."), $min_length, $max_length);
    }

    my $filtered = $pw;
    $filtered =~ s/$valid_password_chars//g;

    if ($filtered ne "") {
	return _("The password may only contain the following characters:
0..9, a..z, A..Z, and any of \"#* ,.;:._-+!\$%^&/|\?{[()]}\".
Please try again.");
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

    if (!defined $pw || $pw eq "") {
	return $ret;
    }
    if (!defined $cracklib_dictpath || $cracklib_dictpath eq "" ||
	SCR::Read (".target.size", "$cracklib_dictpath.pwd") == -1) {
	$ret = SCR::Execute (".crack", $pw);
    }
    else {
	$ret = SCR::Execute (".crack", $pw, $cracklib_dictpath);
    }
    if (!defined ($ret)) { $ret = ""; }

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
        return _("You have used the user name as a part of the password.
This is not good security practice. Are you sure?");
    }

    # check for lowercase
    my $filtered 	= $pw;
    $filtered 		=~ s/[a-z]//g;
    if ($filtered eq "") {
        return _("You have used only lowercase letters for the password.
This is not good security practice. Are you sure?");
    }

    # check for numbers
    $filtered 		= $pw;
    $filtered 		=~ s/[0-9]//g;
    if ($filtered eq "") {
        return _("You have used only digits for the password.
This is not good security practice. Are you sure?");
    }
    return "";
}

##------------------------------------
# Checks if password is not too long
# @param pw password
sub CheckPasswordMaxLength {

    my $pw 		= $_[0];
    my $type		= UsersCache::GetUserType ();
    my $max_length 	= $max_pass_length{$type};

    if (length ($pw) > $max_length) {
        return sprintf (_("The password is too long for the current encryption method.
Truncate it to %s characters?"), $max_length);
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
	    $ret{"question"}	= sprintf (_("Password is too simple:
%s
Really use it?"), $error);
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

    while (SCR::Read (".target.size", $tmpfile) != -1) {
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
    if ($home eq "") {
	return "";
    }

    my $type		= UsersCache::GetUserType ();
    my $first 		= substr ($home, 0, 1);
    my $filtered 	= $home;
    $filtered 		=~ s/$valid_home_chars//g;

    if ($filtered ne "" || $first ne "/" || $home =~ m/\/\./) {
        return _("The home directory may only contain the following characters:
a..zA..Z0..9_-/
Try again.");
    }

    # check if directory is writable
    if (!Mode::config () && ($type ne "ldap" || Ldap::file_server () )) {
	my $home_path = substr ($home, 0, rindex ($home, "/"));
        $home_path = IsDirWritable ($home_path);
        if ($home_path ne "") {
            return sprintf (_("The directory %s is not writable.
Choose another path for the home directory."), $home_path);
	}
    }

    if ($home eq GetDefaultHome ($type)) {
	return "";
    }

    if (("add_user" eq ($user_in_work{"what"} || ""))		||
	($home ne ($user_in_work{"homeDirectory"} || "")) 	||
	(defined $user_in_work{"org_homeDirectory"} && 
		 $user_in_work{"org_homeDirectory"} ne $home)) {

	if (UsersCache::HomeExists ($home)) {
	    # error message
	    return _("The home directory is used from another user.
Please try again.");
	}
    }
    return "";
}

##------------------------------------
# check atributes of an LDAP user
BEGIN { $TYPEINFO{CheckLDAPAttributes} = ["function",
    "string",
    ["map", "string", "any"]];
}
sub CheckLDAPAttributes {

    my $user	= $_[0];

    # TODO required attributes should be enhanced by all attributes
    # required by schema!
    foreach my $req (UsersLDAP::GetUserRequiredAttributes ()) {

	my $a = $ldap2yast_user_attrs{$req} || $req;
	if (!defined $user->{$a} || $user->{$a} eq "") {
	    return sprintf (_("The attribute '%s' is required for this object according
to its LDAP configuration, but it is currently empty."), $req);
	}
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

#    if ($home eq "" || $home eq ($user_in_work{"homeDirectory"} || "") ||
    if ($home eq "" || !($user_in_work{"create_home"} || 0)) {
	return \%ret;
    }

    if ((($ui_map{"chown"} || 0) != 1) &&
	!Mode::config () &&
	(SCR::Read (".target.size", $home) != -1)) {
#	($user_type ne "ldap" || $ldap_file_server)) TODO
        
	$ret{"question_id"}	= "chown";
	$ret{"question"}	= _("The home directory selected already exists.
Use it and change its owner?");

	my %stat 	= %{SCR::Read (".target.stat", $home)};
	my $dir_uid	= $stat{"uidNumber"} || -1;
                    
	if ($uid == $dir_uid) { # chown is not needed (#25200)
	    $ret{"question"}	= _("The home directory selected already exists
and is owned by the currently edited user.
Use this directory?");
	}
	# maybe it is home of some user marked to delete...
	elsif (defined $removed_homes{$home}) {
	    $ret{"question"}	= sprintf (_("The home directory selected (%s)
already exists as a former home directory of
a user previously marked for deletion.
Use this directory?"), $home);
	}
    }
    return \%ret;
}

##------------------------------------
# check the shell of current user
BEGIN { $TYPEINFO{CheckShellUI} = ["function",
    ["map", "string", "string"],
    "string", ["map", "string", "string"]];
}
sub CheckShellUI {

    my $shell	= $_[0];
    my %ui_map	= %{$_[1]};
    my %ret	= ();

    if (($ui_map{"shell"} || 0) != 1 &&
	($user_in_work{"loginShell"} || "") ne $shell ) {

	if (!defined ($all_shells{$shell})) {
	    $ret{"question_id"}	= "shell";
	    $ret{"question"}	= _("If you select a nonexistent shell, the user may be unable to log in.
Are you sure?");
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
    my $min 	= UsersCache::GetMinGID ($type);
    my $max	= UsersCache::GetMaxGID ($type);

    if (!defined $gid) {
	return _("There is no free GID for this type of group.");
    }

    if (("add_group" eq ($group_in_work{"what"} || "")) ||
	($gid != ($group_in_work{"gidNumber"} || 0))	||
	(defined $group_in_work{"org_gidNumber"} && 
		 $group_in_work{"org_gidNumber"} != $gid)) {

	if (UsersCache::GIDExists ($gid)) {
	    return _("The group ID entered is already in use.
Select another group ID.");
	}
    }

    if (($type ne "system" && $type ne "local" && ($gid < $min || $gid > $max))
	||
	# allow change of type: "local" <-> "system"
	(($type eq "system" || $type eq "local") &&
	 (
	    ($gid < UsersCache::GetMinGID ("local") &&
	    $gid < UsersCache::GetMinGID ("system")) ||
	    ($gid > UsersCache::GetMaxGID ("local") &&
	     $gid > UsersCache::GetMaxGID ("system"))
	 )
	)) 
    {
	return sprintf (_("The selected group ID is not allowed.
Select a valid integer between %i and %i."), $min, $max);
    }
    return "";
}

##------------------------------------
# check the gid of current group - part 2
BEGIN { $TYPEINFO{CheckGIDUI} = ["function",
    ["map", "string", "string"],
    "integer", ["map", "string", "string"]];
}
sub CheckGIDUI {

    my $gid	= $_[0];
    my %ui_map	= %{$_[1]};
    my $type	= UsersCache::GetGroupType ();
    my %ret	= ();

    if (($ui_map{"local"} || 0) != 1) {
	if ($type eq "system" &&
	    $gid > UsersCache::GetMinGID ("local") &&
	    $gid < UsersCache::GetMaxGID ("local"))
	{
	    $ret{"question_id"}	= "local";
	    $ret{"question"}	= sprintf (_("The selected group ID is a local ID,
because the ID is greater than %i.
Really change type of group to 'local'?"), UsersCache::GetMinGID ("local"));
	    return \%ret;
	}
    }

    if (($ui_map{"system"} || 0) != 1) {
	if ($type eq "local" &&
	    $gid > UsersCache::GetMinGID ("system") &&
	    $gid < UsersCache::GetMaxGID ("system"))
	{
	    $ret{"question_id"}	= "system";
	    $ret{"question"}	= sprintf(_("The selected group ID is a system ID,
because the ID is smaller than %i.
Really change type of group to 'system'?"), UsersCache::GetMaxGID ("system"));
	    return \%ret;
	}
    }
    return \%ret;
}

##------------------------------------
# check the groupname of current group
BEGIN { $TYPEINFO{CheckGroupname} = ["function", "string", "string"]; }
sub CheckGroupname {

    my $groupname	= $_[0];

    if (!defined $groupname || $groupname eq "") {
        return _("You didn't enter a groupname.
Please try again.");
    }
    
    if (length ($groupname) < $UsersCache::min_length_groupname ||
	length ($groupname) > $UsersCache::max_length_groupname ) {

	return sprintf (_("The group name must be between %i and %i characters in length.
Try again."), $UsersCache::min_length_groupname,
	     $UsersCache::max_length_groupname);
    }
	
    my $filtered = $groupname;
    $filtered =~ s/[$valid_logname_chars]//g;

    my $first = substr ($groupname, 0, 1);
    if ($first lt "A" || $first gt "z" || $filtered ne "") { 
	return _("The group name may contain only
letters, digits, \"-\", \".\", and \"_\"
and must begin with a letter.
Try again.");
    }
    
    if (("add_group" eq ($group_in_work{"what"} || "")) 	||
	($groupname ne ($group_in_work{"groupname"} || "")) 	||
	(defined $group_in_work{"org_groupname"} && 
		 $group_in_work{"org_groupname"} ne $groupname)) {

	if (UsersCache::GroupnameExists ($groupname)) {
	    return _("There is a conflict between the entered
group name and an existing group name.
Try another one.");
	}
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
    my $type	= $user{"type"} || "";

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

    if ($error eq "" && $type ne "ldap") {
	$error	= CheckFullname ($user{"cn"});
    }

    if ($error eq "" && $type ne "ldap") {
	$error	= CheckGECOS ($user{"addit_data"});
    }

    if ($error eq "" && $type eq "ldap") {
	$error	= CheckLDAPAttributes (\%user);
    }

#TODO Check*UI (?)

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

##-------------------------------------------------------------------------
## -------------------------------------------- password related routines 

BEGIN { $TYPEINFO{EncryptionMethod} = ["function", "string"];}
sub EncryptionMethod {
    return $encryption_method;
}

##------------------------------------
BEGIN { $TYPEINFO{SetEncryptionMethod} = ["function", "void", "string"];}
sub SetEncryptionMethod {
    if ($encryption_method ne $_[0]) {
	$encryption_method 		= $_[0];
	$security_modified 		= 1;
	my %max_lengths			= %{Security::PasswordMaxLengths ()};
	$max_pass_length{"local"}	= $max_lengths{$encryption_method};
	$max_pass_length{"system"}	= $max_pass_length{"local"};
    }
}

# code provided by Ralf Haferkamp
sub _hashPassword {

    use MIME::Base64 qw(encode_base64); #FIXME to requires...
    use Digest::MD5;
    use Digest::SHA1 qw(sha1);

    my ($mech, $password) = @_;
    if ($mech  eq "crypt" ) {
        my $salt =  pack("C2",(int(rand 26)+65),(int(rand 26)+65));
        $password = crypt $password,$salt;
	$password = "{crypt}".$password;
    }
    elsif ($mech eq "md5") {
        my $ctx = new Digest::MD5();
        $ctx->add($password);
        $password = "{md5}".encode_base64($ctx->digest, "");
    }
    elsif ($mech eq "smd5") {
        my $salt =  pack("C5",(int(rand 26)+65),
                              (int(rand 26)+65),
                              (int(rand 26)+65),
                              (int(rand 26)+65), 
                              (int(rand 26)+65)
                        );
        my $ctx = new Digest::MD5();
        $ctx->add($password);
        $ctx->add($salt);
        $password = "{smd5}".encode_base64($ctx->digest.$salt, "");
    }
    elsif( $mech eq "sha") {
        $password = sha1($password);
        $password = "{sha}".encode_base64($password, "");
    }
    elsif( $mech eq "ssha") {
        my $salt =  pack("C5", (int(rand 26)+65),
                               (int(rand 26)+65),
                               (int(rand 26)+65),
                               (int(rand 26)+65), 
                               (int(rand 26)+65)
                        );
        $password = sha1($password.$salt);
        $password = "{ssha}".encode_base64($password.$salt, "");
    }
    return $password;
}

##------------------------------------
BEGIN { $TYPEINFO{CryptPassword} = ["function",
    "string",
    "string", "string"];}
sub CryptPassword {

    my $pw	= $_[0];
    my $type	= $_[1];
    my $method	= lc ($encryption_method);
    
    if (!defined $pw || $pw eq "") {
	return $pw;
    }

    if ($type eq "ldap") {
	$method = lc (UsersLDAP::GetEncryption ());
	if ($method eq "clear") {
	    return $pw;
	}
	return _hashPassword ($method, $pw);
    }
    my %out = ();
    # FIXME do not use openssl
    if ($method eq "md5" ) {
	%out = %{SCR::Execute (".target.bash_output", "/usr/bin/openssl passwd -1 $pw")};
    }
#    elsif ($method eq "BLOWFISH" ) { TODO
#	return cryptblowfish (pw);
#    }
    else {
	%out = %{SCR::Execute (".target.bash_output", "/usr/bin/openssl passwd -crypt $pw")};
    }
    if (defined $out{"stdout"}) {
        my $crypted = $out{"stdout"};
	chomp $crypted;
        return $crypted;
    }
}


##------------------------------------
BEGIN { $TYPEINFO{SetRootPassword} = ["function", "void", "string"];}
sub SetRootPassword {

    $root_password = $_[0];
}

##------------------------------------
# Writes password of superuser
# @return true on success
BEGIN { $TYPEINFO{WriteRootPassword} = ["function", "boolean"];}
sub WriteRootPassword {

    return SCR::Write (".target.passwd.root", $root_password);
}

##------------------------------------
# Crypt the root password according to method defined in encryption_method
# This is called during install
BEGIN { $TYPEINFO{CryptRootPassword} = ["function", "void"];}
sub CryptRootPassword {

    if (!Mode::test ()) {
	$root_password = CryptPassword ($root_password, "system");
    }
}

##-------------------------------------------------------------------------
## -------------------------------------------- nis related routines 
##------- TODO move to some 'include' file! -------------------------------


##------------------------------------
# Check whether host is NIS master
BEGIN { $TYPEINFO{ReadNISMaster} = ["function", "boolean"];}
sub ReadNISMaster {
    if (SCR::Read (".target.size", "/usr/lib/yp/yphelper") != -1) {
        return 0;
    }
    return (SCR::Execute (".target.bash", "/usr/lib/yp/yphelper --domainname `domainname` --is-master passwd.byname > /dev/null 2>&1") == 0);
}

##------------------------------------
# Checks if set of NIS users is available
BEGIN { $TYPEINFO{ReadNISAvailable} = ["function", "boolean"];}
sub ReadNISAvailable {

    my $passwd_source = SCR::Read (".etc.nsswitch_conf.passwd");
    foreach my $source (split (/ /, $passwd_source)) {

	if ($source eq "nis" || $source eq "compat") {
	    return (Service::Status ("ypbind") == 0);
	}
    }
    return 0;
}
##-------------------------------------------------------------------------

BEGIN { $TYPEINFO{Import} = ["function",
    "boolean",
    ["map", "string", "any"]];
}
sub Import {
    
    y2error ("not yet");
    #FIXME
    return 1;
}

BEGIN { $TYPEINFO{Export} = ["function",
    ["map", "string", "any"]];
}
sub Export {
    
    y2error ("not yet");
    #FIXME
    return {};
}

BEGIN { $TYPEINFO{Summary} = ["function", "string"];}
sub Summary {
    
    y2error ("not yet");
    return "FIXME";
}

BEGIN { $TYPEINFO{SetWriteOnly} = ["function", "void", "boolean"];}
sub SetWriteOnly {
    $write_only = $_[0];
}

BEGIN { $TYPEINFO{SetGUI} = ["function", "void", "boolean"];}
sub SetGUI {
    $use_gui = $_[0];
    UsersLDAP::SetGUI ($use_gui);
}

# --- 
BEGIN { $TYPEINFO{SetPlusPasswd} = ["function", "void", "string"];}
sub SetPlusPasswd {
    $plus_passwd = $_[0];
    if (SCR::Write (".passwd.passwd.plusline", $plus_passwd)) {
	$users_modified 	= 1;
#TODO not necessary to write all passwd...
    }
}

# ---
BEGIN { $TYPEINFO{SetPlusShadow} = ["function", "void", "string"];}
sub SetPlusShadow {
    $plus_shadow = $_[0];
    if (SCR::Write (".passwd.shadow.plusline", $plus_shadow)) {
	$groups_modified	= 1;
    }
}

# --- 
BEGIN { $TYPEINFO{SetPlusGroup} = ["function", "void", "string"];}
sub SetPlusGroup {
    $plus_group = $_[0];
    if (SCR::Write (".passwd.group.plusline", $plus_group)) {
	$users_modified 	= 1;
    }
}

# EOF
