#! /usr/bin/perl -w
#
# Users module
#

package Users;

use strict;

use YaST::YCP qw(:LOGGING);
use YaPI;

textdomain("users");

# for password encoding:
use MIME::Base64 qw(encode_base64);
use Digest::MD5;
use Digest::SHA1 qw(sha1);
use Data::Dumper;

our %TYPEINFO;

# If YaST UI (Qt,ncurses) should be used. When this is off, some helper
# UI-related structures won't be generated.
my $use_gui			= 1;

# What client to call after authentication dialog during installation:
# could be "users","nis" or "ldap", for more see inst_auth.ycp
my $after_auth			= "users";

# Write only, keep progress turned off
my $write_only			= 0; 

# Export all users and groups (for autoinstallation purposes)
my $export_all			= 0; 

# Where the user/group/password data are stored (can be different on NIS server)
my $base_directory		= "/etc";

my $root_password		= "";

my %default_groupname		= ();

my @user_sources		= ();

my %users			= (
    "system"		=> {},
    "local"		=> {},
);

my %shadow			= (
    "system"		=> {},
    "local"		=> {},
);

my %groups			= (
    "system"		=> {},
    "local"		=> {},
);

my %users_by_name		= (
    "system"		=> {},
    "local"		=> {},
);
my %groups_by_name		= (
    "system"		=> {},
    "local"		=> {},
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


# if passwd/group/shadow entries should be read
my $read_local			= 1;

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

# check if config files were read before w try to write them
my $passwd_not_read 		= 1;
my $shadow_not_read 		= 1;
my $group_not_read 		= 1;

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

# User/group names must match the following regex expression. (/etc/login.defs)
my $character_class 		= "[A-Za-z_][A-Za-z0-9_.-]*[A-Za-z0-9_.\$-]\\?";

# the +/- entries in config files:
my @pluses_passwd		= ();
my @pluses_group		= ();
my @pluses_shadow 		= ();

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
my @user_custom_sets		= ("local");
my @group_custom_sets		= ("local");

# helper structures, filled from UsersLDAP
#my %ldap2yast_user_attrs	= ();
#my %ldap2yast_group_attrs	= ();

# list of available plugin modules for local and system users (groups)
my @local_plugins		= ();
 
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
YaST::YCP::Import ("ProductFeatures");
YaST::YCP::Import ("Progress");
YaST::YCP::Import ("Report");
YaST::YCP::Import ("UsersCache");
YaST::YCP::Import ("UsersLDAP");
YaST::YCP::Import ("UsersPlugins");
YaST::YCP::Import ("UsersRoutines");
YaST::YCP::Import ("UsersUI");

##-------------------------------------------------------------------------
##----------------- various routines --------------------------------------

sub contains {
    my ( $list, $key, $ignorecase ) = @_;
    if (!defined $list || ref ($list) ne "ARRAY" || @{$list} == 0) {
	return 0;
    }
    if ( $ignorecase ) {
        if ( grep /^\Q$key\E$/i, @{$list} ) {
            return 1;
        }
    } else {
        if ( grep /^\Q$key\E$/, @{$list} ) {
            return 1;
        }
    }
    return 0;
}

# check the boolean value, return 0 or 1
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

sub DebugMap {
    UsersCache->DebugMap ($_[0]);
}

##------------------------------------
BEGIN { $TYPEINFO{LastChangeIsNow} = ["function", "string"]; }
sub LastChangeIsNow {
    if (Mode->test ()) { return "0";}

    my %out = %{SCR->Execute (".target.bash_output", "date +%s")};
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
    my $self		= shift;
    $ldap_not_read	= $_[0];
}

BEGIN { $TYPEINFO{GetRootMail} = ["function", "string"]; }
sub GetRootMail {
    return $root_mail;
}

BEGIN { $TYPEINFO{SetRootMail} = ["function", "void", "string"]; }
sub SetRootMail {
    my $self		= shift;
    $root_mail 		= $_[0];
}


BEGIN { $TYPEINFO{GetStartDialog} = ["function", "string"]; }
sub GetStartDialog {
    return $start_dialog;
}

BEGIN { $TYPEINFO{StartDialog} = ["function", "boolean", "string"]; }
sub StartDialog {
    my $self		= shift;
    return $start_dialog eq $_[0];
}

BEGIN { $TYPEINFO{SetStartDialog} = ["function", "void", "string"]; }
sub SetStartDialog {
    my $self		= shift;
    $start_dialog	= $_[0];
}

BEGIN { $TYPEINFO{UseNextTime} = ["function", "boolean"]; }
sub UseNextTime {
    return $use_next_time;
}

BEGIN { $TYPEINFO{SetUseNextTime} = ["function", "void", "boolean"]; }
sub SetUseNextTime {
    my $self		= shift;
    $use_next_time 	= $_[0];
}


BEGIN { $TYPEINFO{GetAvailableUserSets} = ["function", ["list", "string"]]; }
sub GetAvailableUserSets {
    return \@available_usersets;
}

BEGIN { $TYPEINFO{GetAvailableGroupSets} = ["function", ["list", "string"]]; }
sub GetAvailableGroupSets {
    return \@available_groupsets;
}

##------------------------------------
BEGIN { $TYPEINFO{GetCurrentUsers} = ["function", ["list", "string"]]; }
sub GetCurrentUsers {
    return \@current_users;
}

BEGIN { $TYPEINFO{SetCurrentUsers} = ["function", "void", ["list", "string"]]; }
sub SetCurrentUsers {
    my $self	= shift;
    my $new	= shift;
    if (ref ($new) eq "ARRAY") {
	@current_users	= @$new;
    }
}

BEGIN { $TYPEINFO{GetCurrentGroups} = ["function", ["list", "string"]]; }
sub GetCurrentGroups {
    return \@current_groups;
}

BEGIN { $TYPEINFO{SetCurrentGroups} = ["function", "void", ["list", "string"]];}
sub SetCurrentGroups {
    my $self	= shift;
    my $new	= shift;
    if (ref ($new) eq "ARRAY") {
	@current_groups	= @$new;
    }
}

##------------------------------------
# Change the current users set, additional reading could be necessary
# @param new the new current set
BEGIN { $TYPEINFO{ChangeCurrentUsers} = ["function", "boolean", "string"];}
sub ChangeCurrentUsers {

    my $self	= shift;
    my $new 	= $_[0];
    my @backup	= @current_users;

    if ($new eq "custom") {
        @current_users = @user_custom_sets;
    }
    else {
        @current_users = ( $new );
    }
    if (contains (\@current_users, "ldap") && $ldap_not_read) {
        if (!$self->ReadNewSet ("ldap")) {
            @current_users = @backup;
            return 0;
        }
    }

    if (contains (\@current_users, "nis") && $nis_not_read) {
        if (!$self->ReadNewSet ("nis")) {
            @current_users = @backup;
            return 0;
        }
    }

    # correct also possible change in custom itemlist
    if ($new eq "custom") {
	UsersCache->SetCustomizedUsersView (1);
    }

    UsersCache->SetCurrentUsers (\@current_users);
    return 1;
}

##------------------------------------
# Change the current group set, additional reading could be necessary
# @param new the new current set
BEGIN { $TYPEINFO{ChangeCurrentGroups} = ["function", "boolean", "string"];}
sub ChangeCurrentGroups {

    my $self	= shift;
    my $new 	= $_[0];
    my @backup	= @current_groups;

    if ($new eq "custom") {
        @current_groups = @group_custom_sets;
    }
    else {
        @current_groups = ( $new );
    }

    if (contains (\@current_groups, "ldap") && $ldap_not_read) {
        if (!$self->ReadNewSet ("ldap")) {
            @current_groups = @backup;
            return 0;
        }
    }

    if (contains (\@current_groups, "nis") && $nis_not_read) {
        if (!$self->ReadNewSet ("nis")) {
            @current_groups = @backup;
            return 0;
        }
    }

    # correct also possible change in custom itemlist
    if ($new eq "custom") {
	UsersCache->SetCustomizedGroupsView (1);
    }

    UsersCache->SetCurrentGroups (\@current_groups);
    return 1;
}


##------------------------------------
BEGIN { $TYPEINFO{ChangeCustoms} = ["function",
    "boolean",
    "string", ["list","string"]];
}
sub ChangeCustoms {

    my $self	= shift;
    my @new	= @{$_[1]};
    if ($_[0] eq "users") {
        my @old			= @user_custom_sets;
        @user_custom_sets 	= @new;
        $customs_modified	= $self->ChangeCurrentUsers ("custom");
        if (!$customs_modified) {
            @user_custom_sets 	= @old;
	}
    }
    else
    {
        my @old			= @group_custom_sets;
        @group_custom_sets 	= @new;
        $customs_modified	= $self->ChangeCurrentGroups ("custom");
        if (!$customs_modified) {
            @group_custom_sets 	= @old;
	}
    }
    return $customs_modified;
}


BEGIN { $TYPEINFO{AllShells} = ["function", ["list", "string"]];}
sub AllShells {
    my @shells = sort keys %all_shells;
    return \@shells;
}

BEGIN { $TYPEINFO{AfterAuth} = ["function", "string"];}
sub AfterAuth {
    return $after_auth;
}

BEGIN { $TYPEINFO{SetAfterAuth} = ["function", "void", "string"];}
sub SetAfterAuth {
    my $self	= shift;
    $after_auth = $_[0];
}

BEGIN { $TYPEINFO{NotAskUppercase} = ["function", "boolean"];}
sub NotAskUppercase {
    return $not_ask_uppercase;
}

BEGIN { $TYPEINFO{SetAskUppercase} = ["function", "void", "boolean"];}
sub SetAskUppercase {
    my $self	= shift;
    if ($not_ask_uppercase != $_[0]) {
        $not_ask_uppercase 	= $_[0];
	$customs_modified	= 1;
    }
}
    
    
##------------------------------------
BEGIN { $TYPEINFO{CheckHomeMounted} = ["function", "void"]; }
# Checks if the home directory is properly mounted (bug #20365)
sub CheckHomeMounted {

    if ( Mode->live_eval() || Mode->test() || Mode->config() ) {
	return "";
    }

    my $self		= shift;
    my $ret 		= "";
    my $mountpoint_in	= "";
    my $home 		= $self->GetDefaultHome ("local");
    if (substr ($home, -1, 1) eq "/") {
	chop $home;
    }

    my $fstab = SCR->Read (".etc.fstab");
    if (defined $fstab && ref ($fstab) eq "ARRAY") {
	foreach my $line (@{$fstab}) {
	    my %line	= %{$line};
	    if ($line{"file"} eq $home) {
		$mountpoint_in = "/etc/fstab";
	    }
	}
    }

    if (SCR->Read (".target.size", "/etc/cryptotab") != -1) {
        my $cryptotab = SCR->Read (".etc.cryptotab");
	if (defined $cryptotab && ref ($cryptotab) eq "ARRAY") {
	    foreach my $line (@{$cryptotab}) {
		my %line	= %{$line};
		if ($line{"mount"} eq $home) {
		    $mountpoint_in = "/etc/cryptotab";
		}
	    }
	}
    }

    if ($mountpoint_in ne "") {
        my $mounted	= 0;
        my $mtab	= SCR->Read (".etc.mtab");
	if (defined $mtab && ref ($mtab) eq "ARRAY") {
	    foreach my $line (@{$mtab}) {
		my %line	= %{$line};
		if ($line{"file"} eq $home) {
		    $mounted = 1;
		}
	    }
        }

        if (!$mounted) {
            return sprintf (
# Popup text: first and third %s is the directory (e.g. /home),
# second %s the file name (e.g. /etc/fstab)
__("In %s, there is a mount point for the directory
%s, which is used as a default home directory for new
users, but this directory is not currently mounted.
If you add new users using the default values,
their home directories will be created in the current %s.
This can result in these directories not being accessible
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

    my $self		= shift;
    if (defined ($min_pass_length{$_[0]})) {
	return $min_pass_length{$_[0]};
    }
    else { return 5;}
}

##------------------------------------
BEGIN { $TYPEINFO{GetMaxPasswordLength} = ["function", "integer", "string"]; }
sub GetMaxPasswordLength {
    my $self		= shift;
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

    my $self		= shift;
    my $type		= $_[0];
    my %grouplist	= ();
    my $grouplist	= "";

    if ($type eq "ldap") {
	$grouplist	= UsersLDAP->GetDefaultGrouplist ();
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

    my $self	= shift;
    my $type	= $_[0];
    my $gid	= $useradd_defaults{"group"};

    if ($type eq "ldap") {
	$gid	= UsersLDAP->GetDefaultGID ();
    }
    return $gid;
}

##------------------------------------
BEGIN { $TYPEINFO{GetDefaultShell} = ["function", "string", "string"]; }
sub GetDefaultShell {

    my $self	= shift;
    my $type 	= $_[0];

    if ($type eq "ldap") {
	return UsersLDAP->GetDefaultShell ();
    }
    else {
        return $useradd_defaults{"shell"};
    }
}

##------------------------------------
BEGIN { $TYPEINFO{GetDefaultHome} = ["function", "string", "string"]; }
sub GetDefaultHome {

    my $self	= shift;
    my $home 	= $useradd_defaults{"home"} || "";

    if ($_[0] eq "ldap") {
	$home	= UsersLDAP->GetDefaultHome ();
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

    my $self	= shift;
    my $type	= $_[0];
    my %ret 	= (
            "shadowinactive"	=> $useradd_defaults{"inactive"},
            "shadowexpire"      => $useradd_defaults{"expire"},
            "shadowwarning"     => $pass_warn_age,
            "shadowmin"         => $pass_min_days,
            "shadowmax"         => $pass_max_days,
            "shadowflag"        => "",
            "shadowlastchange"	=> "",
	    "userpassword"	=> ""
    );
    if ($type eq "ldap") {
	%ret	= %{UsersLDAP->GetDefaultShadow()};
    }
    return \%ret;
}


##------------------------------------
BEGIN { $TYPEINFO{GetDefaultGroupname} = ["function", "string", "string"]; }
sub GetDefaultGroupname {

    my $self	= shift;
    my $type 	= $_[0];

    if (defined $default_groupname{$type}) {
        return $default_groupname{$type};
    }
	
    my $gid	= $self->GetDefaultGID ($type);
    my %group	= ();
    if ($type eq "ldap") {
	%group	= %{$self->GetGroup ($gid, "ldap")};
    }
    if (!%group) {
	%group	= %{$self->GetGroup ($gid, "local")};
    }
    if (!%group) {
	%group	= %{$self->GetGroup ($gid, "system")};
    }
    if (%group) {
	$default_groupname{$type}	= $group{"cn"};
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

    my $self			= shift;
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

    my $self		= shift;
    my $uid		= $_[0];
    my @types_to_look	= ($_[1]);
    if ($_[1] eq "") {
	@types_to_look = keys %users;
	unshift @types_to_look, UsersCache->GetUserType ();
    }

    foreach my $type (@types_to_look) {
	if (defined $users{$type}{$uid}) {
	    return $users{$type}{$uid};
	}
    }
    return {};
}

##------------------------------------
# get set of users of given type indexed by given key
BEGIN { $TYPEINFO{GetUsers} = [ "function",
    ["map", "any", "any" ],
    "string", "string"]; # index key, type
}
sub GetUsers {

    my $self	= shift;
    my $key	= shift;
    my $type	= shift;
    my $ret	= {};
    
    foreach my $uid (keys %{$users{$type}}) {
	my $user	= $users{$type}{$uid};
	if (ref ($user) eq "HASH" && defined $user->{$key}) {
	    $ret->{$user->{$key}}	= $user;
	}
    }
    return $ret;
    # error message
    my $msg = __("There are multiple users satisfying the input conditions.");
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

    my $self		= shift;
    my $username	= $_[0];
    if ($username =~ m/=/) {
	$username = UsersCache->get_first ($username);
# TODO maybe we should have users_by_dn set!
    }

    my @types_to_look	= ($_[1]);
    if ($_[1] eq "") {
	@types_to_look = keys %users_by_name;
	unshift @types_to_look, UsersCache->GetUserType ();
    }
    
    foreach my $type (@types_to_look) {
	if (defined $users_by_name{$type}{$username}) {
	    return $self->GetUser ($users_by_name{$type}{$username}, $type);
	}
    }
    return {};
}

##------------------------------------
# get set of groups of given type indexed by given key
BEGIN { $TYPEINFO{GetGroups} = [ "function",
    ["map", "any", "any" ],
    "string", "string"]; # index key, type
}
sub GetGroups {

    my $self	= shift;
    my $key	= shift;
    my $type	= shift;
    my $ret	= {};
    
    foreach my $id (keys %{$groups{$type}}) {
	
	my $group	= $groups{$type}{$id};
	if (defined $group->{$key}) {
	    $ret->{$group->{$key}}	= $group;
	}
    }
    return $ret;
}


##------------------------------------
BEGIN { $TYPEINFO{GetGroup} = [ "function",
    ["map", "string", "any" ],
    "integer", "string"];
}
sub GetGroup {

    my $self		= shift;
    my $gid		= $_[0];
    my @types_to_look	= ($_[1]);
    if ($_[1] eq "") {
	@types_to_look = sort keys %groups;
	unshift @types_to_look, UsersCache->GetGroupType ();
    }

    foreach my $type (@types_to_look) {
	if (defined ($groups{$type}{$gid})) {
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

    my $self		= shift;
    my $groupname	= $_[0];
    my $type		= $_[1];

    # NOTE: different behaviour than GetUserByName:
    # Given user type is checked for first, but the other follow.
    # The only reason for "type" argument is to get the (probably) right
    # group as first (e.g. there are 2 'users' groups - local and ldap).
    my @types_to_look	= keys %groups_by_name;
    if ($type ne "") {
	unshift @types_to_look, $type;
    }
    foreach my $type (@types_to_look) {
	if (defined $groups_by_name{$type}{$groupname}) {
	    return $self->GetGroup ($groups_by_name{$type}{$groupname}, $type);
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

	my $uname	= $user->{"uid"};
	if ($type eq "ldap") {# LDAP groups have list of user DN's
	    $uname	= $user->{"dn"};
	}
	if (!defined $uname) { next; }
        foreach my $gid (keys %{$groups{$type}}) {

	    my $group	= $groups{$type}{$gid};
            my $userlist = $group->{"userlist"};
	    if ($type eq "ldap") { 
		my $member_attribute	= UsersLDAP->GetMemberAttribute ();
		$userlist = $group->{$member_attribute};
	    }
            if (defined $userlist->{$uname}) {
		$grouplist{$group->{"cn"}}	= 1;
            }
        };
    };
    return \%grouplist;
}

##-------------------------------------------------------------------------
##----------------- read routines -----------------------------------------

BEGIN { $TYPEINFO{GetUserCustomSets} = [ "function", ["list", "string"]]; }
sub GetUserCustomSets {
    return \@user_custom_sets;
}

BEGIN { $TYPEINFO{GetGroupCustomSets} = [ "function", ["list", "string"]]; }
sub GetGroupCustomSets {
    return \@group_custom_sets;
}

##------------------------------------
# Reads the set of values in "Custom" filter from disk and other internal
# variables ("not_ask")
sub ReadCustomSets {

    my $file = Directory->vardir()."/users.ycp";
    if (SCR->Read (".target.size", $file) == -1) {
	SCR->Execute (".target.bash", "/bin/touch $file");
	$customs_modified	= 1;

	if ($ldap_available && !Mode->config ()) {
	    @user_custom_sets	= ("ldap");
	    @group_custom_sets	= ("ldap");
	}
    }
    else {
	my $customs = SCR->Read (".target.ycp", $file);

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
	    if (defined ($custom_map{"plugins"}) &&
		ref ($custom_map{"plugins"}) eq "ARRAY") {
		@local_plugins	= @{$custom_map{"plugins"}};
	    }
	}
    }
    if (@user_custom_sets == 0) {
	@user_custom_sets = ("local");
    }
    if (@group_custom_sets == 0) {
	@group_custom_sets = ("local");
    }
    # LDAP is not set in nsswitch, but in customs
    if (contains (\@user_custom_sets, "ldap") ||
	contains (\@group_custom_sets, "ldap")) {
	$ldap_available	= 1;
        if (!contains (\@available_usersets, "ldap")) {
	    push @available_usersets, "ldap";
	}
        if (!contains (\@available_groupsets, "ldap")) {
	    push @available_groupsets, "ldap";
	}
    }
}

##------------------------------------
# Read the /etc/shells file and return a item list or a string shell list.
# @param todo `items or `stringlist
# @return list of shells
BEGIN { $TYPEINFO{ReadAllShells} = ["function", "void"]; }
sub ReadAllShells {

    my @available_shells	= ();
    my $shells_s = SCR->Read (".target.string", "/etc/shells");
    my @shells_read = split (/\n/, $shells_s);

    foreach my $shell_entry (@shells_read) {

	if ($shell_entry eq "" || $shell_entry =~ m/^passwd|bash1$/) {
	    next;
	}
	if (SCR->Read (".target.size", $shell_entry) != -1) {
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
    $ldap_available 		= UsersLDAP->ReadAvailable ();

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

    if (Mode->test ()) { return; }

    my $self		= shift;

    Progress->off ();
    Security->Read ();

    if ($use_gui) { Progress->on (); }

    my %security	= %{Security->Export ()};
    $pass_warn_age	= $security{"PASS_WARN_AGE"}	|| $pass_warn_age;
    $pass_min_days	= $security{"PASS_MIN_DAYS"}	|| $pass_min_days;
    $pass_max_days	= $security{"PASS_MAX_DAYS"}	|| $pass_max_days;

    # command running before/after adding/deleting user
    $useradd_cmd 	= $security{"USERADD_CMD"};
    $userdel_precmd 	= $security{"USERDEL_PRECMD"};
    $userdel_postcmd 	= $security{"USERDEL_POSTCMD"};

    $encryption_method	= $security{"PASSWD_ENCRYPTION"} || $encryption_method;
    $cracklib_dictpath	= $security{"CRACKLIB_DICTPATH"};
    $use_cracklib 	= ($security{"PASSWD_USE_CRACKLIB"} eq "yes");
    $obscure_checks 	= ($security{"OBSCURE_CHECKS_ENAB"} eq "yes");

    $min_pass_length{"local"}	= $security{"PASS_MIN_LEN"} || $min_pass_length{"local"};
    $min_pass_length{"system"}	= $security{"PASS_MIN_LEN"} || $min_pass_length{"system"};

    $character_class 	= SCR->Read (".etc.login_defs.CHARACTER_CLASS");

    my %max_lengths		= %{Security->PasswordMaxLengths ()};
    if (defined $max_lengths{$encryption_method}) {
	$max_pass_length{"local"}	= $max_lengths{$encryption_method};
	$max_pass_length{"system"}	= $max_pass_length{"local"};
    }

    UsersCache->InitConstants (\%security);
}

##------------------------------------
BEGIN { $TYPEINFO{ReadLoginDefaults} = ["function", "boolean"]; }
sub ReadLoginDefaults {

    my $self		= shift;
    foreach my $key (sort keys %useradd_defaults) {
        my $entry = SCR->Read (".etc.default.useradd.\"\Q$key\E\"");
        if (!$entry) {
	    $entry = "";
	}
	$entry =~ s/\"//g;
        $useradd_defaults{$key} = $entry;
    }

    UsersLDAP->InitConstants (\%useradd_defaults);
    UsersLDAP->SetDefaultShadow ($self->GetDefaultShadow ("local"));

    if (%useradd_defaults) {
        return 1;
    }
    return 0;
}

##------------------------------------
BEGIN { $TYPEINFO{ReadLDAPSet} = ["function", "string", "string"]; }
sub ReadLDAPSet {
    
    my $self	= shift;
    my $type	= "ldap";
    # generate ldap users/groups list in the agent:
    my $ldap_mesg = UsersLDAP->Read();
    if ($ldap_mesg ne "") {
        Ldap->LDAPErrorMessage ("read", $ldap_mesg);
        return $ldap_mesg;
    }
    # read the LDAP data (users, groups, items)
    $users{$type}		= \%{SCR->Read (".ldap.users")};
    $users_by_name{$type}	= \%{SCR->Read (".ldap.users.by_name")};
    $groups{$type}		= \%{SCR->Read (".ldap.groups")};
    $groups_by_name{$type}	= \%{SCR->Read (".ldap.groups.by_name")};
    # read the necessary part of LDAP user configuration
    $min_pass_length{"ldap"}= UsersLDAP->GetMinPasswordLength ();
    $max_pass_length{"ldap"}= UsersLDAP->GetMaxPasswordLength ();

    if ($use_gui) {
	UsersCache->BuildUserItemList ($type, $users{$type});
	UsersCache->BuildGroupItemList ($type, $groups{$type});
    }
    
    UsersCache->ReadUsers ($type);
    UsersCache->ReadGroups ($type);

    $ldap_not_read = 0;

    return $ldap_mesg;
}

##------------------------------------
# Read new set of users - "on demand" (called from running module)
# @param type the type of users, currently "ldap" or "nis"
# @return success
BEGIN { $TYPEINFO{ReadNewSet} = ["function", "boolean", "string"]; }
sub ReadNewSet {

    my $self	= shift;
    my $type	= $_[0];
    if ($type eq "nis") {

        $nis_not_read = 0;
	
	$users{$type}		= \%{SCR->Read (".nis.users")};
	$users_by_name{$type}	= \%{SCR->Read (".nis.users.by_name")};
	$groups{$type}		= \%{SCR->Read (".nis.groups")};
	$groups_by_name{$type}	= \%{SCR->Read (".nis.groups.by_name")};

	if ($use_gui) {
	    UsersCache->BuildUserItemList ($type, $users{$type});
	    UsersCache->BuildGroupItemList ($type, $groups{$type});
	}
	UsersCache->ReadUsers ($type);
	UsersCache->ReadGroups ($type);
    }
    elsif ($type eq "ldap") {

	# read all needed LDAP settings now:
	if (UsersLDAP->ReadSettings () ne "") {
	    return 0;
	}
	
	# and now the real user/group data
	if ($self->ReadLDAPSet () ne "") {
	    return 0;
	}
    }
    return 1;
}


##------------------------------------
BEGIN { $TYPEINFO{ReadLocal} = ["function", "string"]; }
sub ReadLocal {

    my $self		= shift;
    my %configuration 	= (
	"max_system_uid"	=> UsersCache->GetMaxUID ("system"),
	"max_system_gid"	=> UsersCache->GetMaxGID ("system"),
	"base_directory"	=> $base_directory
    );
    # id limits are necessary for differ local and system users
    my $init = SCR->Execute (".passwd.init", \%configuration);
    if (!$init) {
	my $error 	= SCR->Read (".passwd.error");
	my $error_info	= SCR->Read (".passwd.error.info");
	return UsersUI->GetPasswdErrorMessage ($error, $error_info);
    }
    $passwd_not_read 		= 0;
    $shadow_not_read 		= 0;
    $group_not_read 		= 0;

    foreach my $type ("local", "system") {
	$users{$type}		= \%{SCR->Read (".passwd.$type.users")};
	$users_by_name{$type}	= \%{SCR->Read (".passwd.$type.users.by_name")};
	$shadow{$type}		= \%{SCR->Read (".passwd.$type.shadow")};
	$groups{$type}		= \%{SCR->Read (".passwd.$type.groups")};
	$groups_by_name{$type}	= \%{SCR->Read(".passwd.$type.groups.by_name")};
    }

    my $pluses		= SCR->Read (".passwd.passwd.pluslines");
    if (ref ($pluses) eq "ARRAY") {
	@pluses_passwd	= @{$pluses};
    }
    $pluses		= SCR->Read (".passwd.shadow.pluslines");
    if (ref ($pluses) eq "ARRAY") {
	@pluses_shadow	= @{$pluses};
    }
    $pluses		= SCR->Read (".passwd.group.pluslines");
    if (ref ($pluses) eq "ARRAY") {
	@pluses_group	= @{$pluses};
    }
    return "";
}

# Initialize cache structures (lists of table items, lists of usernames etc.)
# for local users and groups
sub ReadUsersCache {
    
    my $self	= shift;

    UsersCache->Read ();

    UsersCache->BuildUserItemList ("local", $users{"local"});
    UsersCache->BuildUserItemList ("system", $users{"system"});

    UsersCache->BuildGroupItemList ("local", $groups{"local"});
    UsersCache->BuildGroupItemList ("system", $groups{"system"});
}

# initialize list of available plugins
sub ReadAvailablePlugins {

    if (Mode->test ()) { return; }

    UsersPlugins->Read ();

    # update internal keys with the values from plugins

    my @user_internals	= @{UsersLDAP->GetUserInternal ()};
    my $internals	= UsersPlugins->Apply ("InternalAttributes", {
	"what" 	=> "user" }, {});
    if (defined $internals && ref ($internals) eq "HASH") {
	foreach my $plugin (keys %{$internals}) {
	    if (ref ($internals->{$plugin}) eq "ARRAY") {
		foreach my $int (@{$internals->{$plugin}}) {
		    if (!contains (\@user_internals, $int)) {
			push @user_internals, $int;
		    }
		}
	    }
	}
	UsersLDAP->SetUserInternal (\@user_internals);
    }
    my @group_internals	= @{UsersLDAP->GetGroupInternal ()};
    $internals		= UsersPlugins->Apply ("InternalAttributes", {
	"what" 	=> "group" }, {});
    if (defined $internals && ref ($internals) eq "HASH") {
	foreach my $plugin (keys %{$internals}) {
	    if (ref ($internals->{$plugin}) eq "ARRAY") {
		foreach my $int (@{$internals->{$plugin}}) {
		    if (!contains (\@group_internals, $int)) {
			push @group_internals, $int;
		    }
		}
	    }
	}
	UsersLDAP->SetGroupInternal (\@group_internals);
    }
}

##------------------------------------
BEGIN { $TYPEINFO{Read} = ["function", "string"]; }
sub Read {

    my $self		= shift;
    my $error_msg 	= "";

    # progress caption
    my $caption 	= __("Initializing user and group configuration");
    my $no_of_steps 	= 5;

    if ($use_gui) {
	Progress->New ($caption, " ", $no_of_steps,
	    [
		# progress stage label
		__("Read the default login settings"),
		# progress stage label
		__("Read the default system settings"),
		# progress stage label
		__("Read the configuration type"),
		# progress stage label
		__("Read the user custom settings"),
		# progress stage label
		__("Read users and groups"),
		# progress stage label
		__("Build the cache structures")
           ],
	   [
		# progress step label
		__("Reading the default login settings..."),
		# progress step label
		 __("Reading the default system setttings..."),
		# progress step label
		 __("Reading the configuration type..."),
		# progress step label
		 __("Reading custom settings..."),
		# progress step label
		 __("Reading users and groups..."),
		# progress step label
		 __("Building the cache structures..."),
		# final progress step label
		 __("Finished")
	    ], "" );
    }

    $tmpdir = SCR->Read (".target.tmpdir");

    # default login settings
    if ($use_gui) { Progress->NextStage (); }

    $self->ReadLoginDefaults ();

    $error_msg = $self->CheckHomeMounted();

    if ($use_gui && $error_msg ne "" && !Popup->YesNo ($error_msg)) {
	return $error_msg; # problem with home directory: do not continue
    }

    # default system settings
    if ($use_gui) { Progress->NextStage (); }

    $self->ReadSystemDefaults();

    $self->ReadAllShells();

    # configuration type
    if ($use_gui) { Progress->NextStage (); }

    $self->ReadSourcesSettings();

    if ($nis_master && $use_gui && !Mode->cont()) {
	my $directory = UsersUI->ReadNISConfigurationType ($base_directory);
	if (!defined ($directory)) {
	    return "read error"; # aborted in NIS server dialog
	}
	else {
	    $base_directory = $directory;
	}
    }

    # custom settings
    if ($use_gui) { Progress->NextStage (); }

    $self->ReadCustomSets();

    # users and group
    if ($use_gui) { Progress->NextStage (); }

    if ($read_local) {
	$error_msg = $self->ReadLocal ();
    }

    if ($error_msg ne "") {
	Report->Error ($error_msg);
	return $error_msg;# problem with reading config files( /etc/passwd etc.)
	# TODO enable to continue at "users risk"?
    }

    # read shadow settings during cloning users (#41026)
    if (Mode->config ()) {
	foreach my $type ("system", "local") {
	    foreach my $id (keys %{$users{$type}}) {
		$self->SelectUser ($id); # SelectUser does LoadShadow
		my %user		= %user_in_work;
		undef %user_in_work;
		$users{$type}{$id}	= \%user;
	    }
	}
    }

    # Build the cache structures
    if ($use_gui) { Progress->NextStage (); }

    $self->ReadUsersCache ();

    Autologin->Read ();

    if (Mode->cont () && Autologin->available () &&
	ProductFeatures->enable_autologin ()) {
	Autologin->Use (YaST::YCP::Boolean (1));
    }

    $self->ReadAvailablePlugins ();

    return $error_msg;
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
    
    my $self		= shift;
    my %user		= %{$_[0]};
    my %shadow_map	= ();
    
    my %default_shadow = %{$self->GetDefaultShadow ($user{"type"} || "local")};
    foreach my $shadow_item (keys %default_shadow) {
	if (defined $user{$shadow_item}) {
	    $shadow_map{$shadow_item}	= $user{$shadow_item};
	}
    };
    return \%shadow_map;
}

##------------------------------------
# Remove user from the list of members of current group
BEGIN { $TYPEINFO{RemoveUserFromGroup} = ["function", "boolean", "string"]; }
sub RemoveUserFromGroup {

    my $self		= shift;
    my $user		= $_[0];
    my $ret		= 0;
    my $group_type	= $group_in_work{"type"};

    if ($group_type eq "ldap") {
        $user           = $user_in_work{"dn"};
	if (defined $user_in_work{"org_dn"}) {
	    $user	= $user_in_work{"org_dn"};
	}
	my $member_attribute	= UsersLDAP->GetMemberAttribute ();
	if (defined $group_in_work{$member_attribute}{$user}) {
	    delete $group_in_work{$member_attribute}{$user};
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

    my $self		= shift;
    my $ret		= 0;
    my $user		= $_[0];
    my $group_type	= $group_in_work{"type"};

    if ($group_type eq "ldap") {
        $user           = $user_in_work{"dn"};
	my $member_attribute	= UsersLDAP->GetMemberAttribute ();
	if (!defined $group_in_work{$member_attribute}{$user}) {
            $group_in_work{$member_attribute}{$user}	= 1;
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

    if (%user_in_work && ($user_in_work{"type"} || "") ne "ldap") {
	my $username	= $user_in_work{"uid"};
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

    my $self		= shift;
    %user_in_work	= %{$self->GetUserByName ($_[0], "")};
    LoadShadow ();
}

##------------------------------------
BEGIN { $TYPEINFO{SelectUser} = [ "function",
    "void",
    "integer"];
}
sub SelectUser {

    my $self		= shift;
    %user_in_work 	= %{$self->GetUser ($_[0], "")};
    LoadShadow ();
    UsersCache->SetUserType ($user_in_work{"type"});
}

##------------------------------------
# this is hacked a bit; there probably could be a case when more groups have
# different DN, but same 'cn'
# (let's rule out this case with properly set "group_base")
BEGIN { $TYPEINFO{SelectGroupByDN} = [ "function",
    "void",
    "string"];
}
sub SelectGroupByDN {

    my $self		= shift;
    my $cn		= UsersCache->get_first ($_[0]);
    my $group		= $self->GetGroupByName ($cn, "ldap");
    if (defined $group->{"dn"} && $group->{"dn"} eq $_[0]) {
	%group_in_work	= %$group;
    }
}


##------------------------------------
BEGIN { $TYPEINFO{SelectGroupByName} = [ "function",
    "void",
    "string"];
}
sub SelectGroupByName {

    my $self		= shift;
    %group_in_work	= %{$self->GetGroupByName($_[0], "local")};
}

##------------------------------------
BEGIN { $TYPEINFO{SelectGroup} = [ "function",
    "void",
    "integer"];
}
sub SelectGroup {

    my $self		= shift;
    %group_in_work 	= %{$self->GetGroup ($_[0], "")};
    UsersCache->SetGroupType ($group_in_work{"type"});
}


##------------------------------------
# boolean parameter means "delete home directory"
BEGIN { $TYPEINFO{DeleteUser} = ["function", "boolean", "boolean" ]; }
sub DeleteUser {

    my $self		= shift;
    if (%user_in_work) {
	$user_in_work{"what"}		= "delete_user";
	$user_in_work{"delete_home"}	= YaST::YCP::Boolean (bool ($_[0]));
	return 1;
    }
    y2warning ("no such user");
    return 0;
}

##------------------------------------
BEGIN { $TYPEINFO{DeleteGroup} = ["function", "boolean" ]; }
sub DeleteGroup {

    my $self		= shift;
    if (%group_in_work) {
	$group_in_work{"what"}	= "delete_group";
	return 1;
    }
    y2warning ("no such group");
    return 0;
}

##------------------------------------
BEGIN { $TYPEINFO{GetUserPlugins} = ["function", ["list", "string"], "string"]};
sub GetUserPlugins {

    my $self		= shift;
    if ($_[0] eq "ldap") {
	return UsersLDAP->GetUserPlugins ();
    }
    else {
	return \@local_plugins;
    }
}

##------------------------------------
BEGIN { $TYPEINFO{DisableUser} = ["function",
    "string",
    ["map", "string", "any" ]];
}
sub DisableUser {
    
    my $self		= shift;
    my %user		= %{$_[0]};
    my $type		= $user{"type"} || "";
    my $plugins		= $self->GetUserPlugins ($type);
    my $no_plugin	= 1;
 
    if (defined $user{"plugins"} && ref ($user{"plugins"}) eq "ARRAY") {
	$plugins	= $user{"plugins"};
    }
    else {
	my $result = UsersPlugins->Apply ("PluginPresent", {
	    "what"	=> "user",
	    "type"	=> $type,
	}, \%user);
	if (defined ($result) && ref ($result) eq "HASH") {
	    $plugins = [];
	    foreach my $plugin (keys %{$result}) {
		# check if plugin has done the 'PluginPresent' action
		if (bool ($result->{$plugin}) && !contains ($plugins, $plugin)){
		    push @{$plugins}, $plugin;
		}
	    }
	}
    }

    my $plugin_error	= "";
    foreach my $plugin (sort @{$plugins}) {
	if ($plugin_error) { last; }
	my $result = UsersPlugins->Apply ("Disable", {
	    "what"	=> "user",
	    "type"	=> $type,
	    "plugins"	=> [ $plugin ]
	}, \%user);
	# check if plugin has done the 'Disable' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    %user	= %{$result->{$plugin}};
	    $no_plugin	= 0;
	}
	else {
	    $result = UsersPlugins->Apply ("Error", {
		"what"	=> "user",
		"type"	=> $type,
		"plugins"	=> [ $plugin ] }, {});
	    $plugin_error = $result->{$plugin} || "";
	}
    }
    if ($plugin_error) { return $plugin_error; }

    if ($no_plugin && ($type eq "local" || $type eq "system")) {
	# no plugins available: local user
	# TODO not ready? shadowexpire
	my $pw			= $user{"userpassword"} || "";
	if ($pw eq "x") { $pw	= ""; } # no not allow "!x"
	if ($pw !~ m/^\!/) {
	    $user{"userpassword"}	= "!".$pw;
	}
    }

    if (!defined $user{"disabled"} || ! bool ($user{"disabled"})) {
	$user{"disabled"}	= YaST::YCP::Boolean (1);
    }
    if (defined $user{"enabled"}) {
	delete $user{"enabled"};
    }
    if (!defined $user{"what"}) {
	$user{"what"}		= "edit_user";
    }
    %user_in_work	= %user;
    return "";
}

##------------------------------------
BEGIN { $TYPEINFO{EnableUser} = ["function",
    "string",
    ["map", "string", "any" ]];
}
sub EnableUser {
    
    my $self		= shift;
    my %user		= %{$_[0]};
    my $type		= $user{"type"} || "";
    my $plugins		= $self->GetUserPlugins ($type);
    my $no_plugin	= 1;
    
    if (defined $user{"plugins"} && ref ($user{"plugins"}) eq "ARRAY") {
	$plugins	= $user{"plugins"};
    }
    else {
	my $result = UsersPlugins->Apply ("PluginPresent", {
	    "what"	=> "user",
	    "type"	=> $type,
	}, \%user);
	if (defined ($result) && ref ($result) eq "HASH") {
	    $plugins = [];
	    foreach my $plugin (keys %{$result}) {
		# check if plugin has done the 'PluginPresent' action
		if (bool ($result->{$plugin}) && !contains ($plugins, $plugin)){
		    push @{$plugins}, $plugin;
		}
	    }
	}
    }

    my $plugin_error	= "";
    foreach my $plugin (sort @{$plugins}) {
	if ($plugin_error) { last; }
	my $result = UsersPlugins->Apply ("Enable", {
	    "what"	=> "user",
	    "type"	=> $type,
	    "plugins"	=> [ $plugin ]
	}, \%user);
	# check if plugin has done the 'Enable' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    %user	= %{$result->{$plugin}};
	    $no_plugin	= 0;
	}
	else {
	    $result = UsersPlugins->Apply ("Error", {
		"what"	=> "user",
		"type"	=> $type,
		"plugins"	=> [ $plugin ] }, {});
	    $plugin_error = $result->{$plugin} || "";
	}
    }
    if ($plugin_error) { return $plugin_error; }

    if ($no_plugin && ($type eq "local" || $type eq "system")) {
	# no plugins available: local user
	my $pw	= $user{"userpassword"} || "";
	$pw	=~ s/^\!//;
	if ($pw eq "") { $pw	= "x"; }
	$user{"userpassword"}	= $pw;
    }

    if (!defined $user{"enabled"} || ! bool ($user{"enabled"})) {
	$user{"enabled"}	= YaST::YCP::Boolean (1);
    }
    if (defined $user{"disable"}) {
	delete $user{"disabled"};
    }
    if (!defined $user{"what"}) {
	$user{"what"}		= "edit_user";
    }
    %user_in_work	= %user;
    return "";
}

# read the rest of attributes of LDAP user which will be edited
sub ReadLDAPUser {

    my $dn	= $user_in_work{"dn"} || "";
    my $res 	= SCR->Read (".ldap.search", {
	"base_dn"       => $dn,
	"scope"         => YaST::YCP::Integer (0),
        "single_values" => YaST::YCP::Boolean (1)
    });
    my $u	= {};
    if (defined $res && ref ($res) eq "ARRAY" && ref ($res->[0]) eq "HASH") {
	$u	= $res->[0];
    }
    
    foreach my $key (keys %$u) {
	if (!defined $user_in_work{$key}) {
	    $user_in_work{$key}	= $u->{$key};
	    next;
	}
	if ($key eq "userpassword" && ($user_in_work{$key} || "x") eq "x" &&
	    $user_in_work{$key} ne $u->{$key}) {
	    $user_in_work{$key} = $u->{$key};
	}
    }
}


##------------------------------------
#Edit is used in 2 diffr. situations
#	1. initialization (creates "org_user")	- could be in SelectUser?
#	2. save changed values into user_in_work
BEGIN { $TYPEINFO{EditUser} = ["function",
    "string",
    ["map", "string", "any" ]];		# data to change in user_in_work
}
sub EditUser {

    if (!%user_in_work) { return __("There is no such user."); }
    my $self		= shift;
    my %data		= %{$_[0]};
    my $type		= $user_in_work{"type"} || "";
    if (defined $data{"type"}) {
	$type 	= $data{"type"};
    }
    my $username	= $data{"uid"};

    # check if user is edited for first time
    if (!defined $user_in_work{"org_user"} &&
	($user_in_work{"what"} || "") ne "add_user") {
	# read the rest of LDAP if necessary
	if ($type eq "ldap" && ($user_in_work{"modified"} || "") ne "added") {
	    ReadLDAPUser ();
	}

	# password we have read was real -> set "encrypted" flag
	my $pw	= $user_in_work{"userpassword"} || "";
	if ($pw ne "" && $pw ne "x" &&
	    (!defined $user_in_work{"encrypted"} ||
	     bool ($user_in_work{"encrypted"}))) {
	    $user_in_work{"encrypted"}	= YaST::YCP::Boolean (1);
	}

	# save first map for later checks of modification (in Commit)
	my %org_user			= %user_in_work;
	$user_in_work{"org_user"}	= \%org_user;
	# grouplist wasn't fully generated while reading nis & ldap users
	if ($type eq "nis" || $type eq "ldap") {
	    $user_in_work{"grouplist"} = FindGroupsBelongUser (\%org_user);
	}
	# empty password entry for autoinstall config (do not want to
	# read password from disk: #30573)
	if (Mode->config () && ($user_in_work{"modified"} || "") ne "imported"){
	    $user_in_work{"userpassword"} = "";
	}
    }
    # ------------------------- initialize list of current user plugins
    if (!defined $user_in_work{"plugins"}) {
	$user_in_work{"plugins"}	= $self->GetUserPlugins ($type);
    }
    my $plugins		= $user_in_work{"plugins"};
    # --------- call PluginPresent: check which plugins are in use for this user
    my $result = UsersPlugins->Apply ("PluginPresent", {
	"what"	=> "user",
	"type"	=> $type,
    }, \%user_in_work);
    if (defined ($result) && ref ($result) eq "HASH") {
        $plugins = [];
	foreach my $plugin (keys %{$result}) {
	    # check if plugin has done the 'PluginPresent' action
	    if (bool ($result->{$plugin}) && ! contains ($plugins, $plugin)) {
		push @{$plugins}, $plugin;
	    }
	}
	$user_in_work{"plugins"}	= $plugins;
    }

    # We must use new list of plugins if provided
    if (defined $data{"plugins"} && ref ($data{"plugins"}) eq "ARRAY") {
	$plugins	= $data{"plugins"};
    }

    # plugin has to know if it should be removed...
    my $plugins_to_remove	= [];
    if (defined $data{"plugins_to_remove"}) {
	$plugins_to_remove	= $data{"plugins_to_remove"};
    }
    
    # -------------------------- now call EditBefore function from plugins
    my $plugin_error	= "";
    foreach my $plugin (sort @{$plugins}) {
	if ($plugin_error) { last; }
	my $result = UsersPlugins->Apply ("EditBefore", {
	    "what"		=> "user",
	    "type"		=> $type,
	    "org_data"		=> \%user_in_work,
	    "plugins"		=> [ $plugin ],
	    "plugins_to_remove"	=> $plugins_to_remove
	}, \%data);
	# check if plugin has done the 'EditBefore' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    %data	= %{$result->{$plugin}};
	}
	else {
	    $result = UsersPlugins->Apply ("Error", {
		"what"	=> "user",
		"type"	=> $type,
		"plugins"	=> [ $plugin ] }, {});
	    $plugin_error = $result->{$plugin} || "";
	}
    }
    if ($plugin_error) {
	return $plugin_error;
    }
    # ----------------------------------------------------------------
    
    # update the settings which should be changed
    foreach my $key (keys %data) {
	if ($key eq "uid" || $key eq "homedirectory" ||
	    $key eq "uidnumber" || $key eq "type" || $key eq "groupname")
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

	    my $new_dn	= UsersLDAP->CreateUserDN (\%data);
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
	if ($key eq "create_home" || $key eq "delete_home" ||
	    $key eq "encrypted" ||$key eq "no_skeleton" ||
	    $key eq "disabled" || $key eq "enabled") {
	    if (ref $data{$key} eq "YaST::YCP::Boolean") {
		$user_in_work{$key}	= $data{$key};
	    }
	    else {
		$user_in_work{$key}	= YaST::YCP::Boolean ($data{$key});
	    }
	    next;
	}
	if ($key eq "org_user") {
	    next;
	}
	if ($key eq "userpassword" && $data{$key} ne "" &&
	    $data{$key} ne "x" && $data{$key} ne "!" &&
	    $data{$key} ne $user_in_work{$key}) {
	    # crypt password only once (when changed)
	    if (!defined $data{"encrypted"} || !bool ($data{"encrypted"})) {
		$user_in_work{$key} = $self->CryptPassword ($data{$key}, $type);
		$user_in_work{"encrypted"}	= YaST::YCP::Boolean (1);
		$user_in_work{"text_userpassword"} = $data{$key};
		$data{"text_userpassword"} 	= $data{$key};
		$data{"encrypted"}		= YaST::YCP::Boolean (1);
		next;
	    }
	}
	$user_in_work{$key}	= $data{$key};
    }
    $user_in_work{"what"}	= "edit_user";
    UsersCache->SetUserType ($type);
    # --------------------------------- now call Edit function from plugins
    foreach my $plugin (sort @{$plugins}) {
	if ($plugin_error) { last; }
	my $result = UsersPlugins->Apply ("Edit", {
	    "what"	=> "user",
	    "type"	=> $type,
	    "plugins"	=> [ $plugin ],
	    "plugins_to_remove"	=> $plugins_to_remove
	}, \%user_in_work);
	# check if plugin has done the 'Edit' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    %user_in_work= %{$result->{$plugin}};
	}
	else {
	    $result = UsersPlugins->Apply ("Error", {
		"what"	=> "user",
		"type"	=> $type,
		"plugins"	=> [ $plugin ] }, {});
	    $plugin_error = $result->{$plugin} || "";
	}
    }
    if ($plugin_error) {
	return $plugin_error;
    }
    # ---------------------------------------------------------------------
    # now handle possible login disabling
    if (bool ($user_in_work{"disabled"})) {
	$plugin_error = $self->DisableUser (\%user_in_work);
    }
    if (bool ($user_in_work{"enabled"})) {
	$plugin_error = $self->EnableUser (\%user_in_work);
    }
    return $plugin_error;
}

##------------------------------------
BEGIN { $TYPEINFO{EditGroup} = ["function",
    "string",
    ["map", "string", "any" ]];		# data to change in group_in_work
}
sub EditGroup {

    # error message
    if (!%group_in_work) { return __("There is no such group."); }

    my $self	= shift;
    my %data	= %{$_[0]};
    my $type	= $group_in_work{"type"};

    if (defined $data{"type"}) {
	$type = $data{"type"};
    }

    # check if group is edited for first time
    if (!defined $group_in_work{"org_group"} &&
	($group_in_work{"what"} || "") ne "add_group") {

	# password we have read was real -> set "encrypted" flag
	my $pw	= $group_in_work{"userpassword"} || "";
	if ($pw ne "" && $pw ne "x" &&
	    (!defined $group_in_work{"encrypted"} ||
	     bool ($group_in_work{"encrypted"}))) {
	    $group_in_work{"encrypted"}	= YaST::YCP::Boolean (1);
	}

	# save first map for later checks of modification (in Commit)
	my %org_group			= %group_in_work;
	$group_in_work{"org_group"}	= \%org_group;
    }

    # ------------------------- initialize list of current user plugins
    if (!defined $group_in_work{"plugins"}) {
	$group_in_work{"plugins"}	= $self->GetUserPlugins ($type);
    }
    my $plugins		= $group_in_work{"plugins"};

    # --------- call PluginPresent: check which plugins are in use for this user
    my $result = UsersPlugins->Apply ("PluginPresent", {
	"what"	=> "group",
	"type"	=> $type,
    }, \%group_in_work);
    if (defined ($result) && ref ($result) eq "HASH") {
        $plugins = [];
	foreach my $plugin (keys %{$result}) {
	    # check if plugin has done the 'PluginPresent' action
	    if (bool ($result->{$plugin}) && ! contains ($plugins, $plugin)) {
		push @{$plugins}, $plugin;
	    }
	}
	$group_in_work{"plugins"}	= $plugins;
    }
 
    if (defined $data{"plugins"} && ref ($data{"plugins"}) eq "ARRAY") {
	$plugins	= $data{"plugins"};
    }

    # plugin has to know if it should be removed...
    my $plugins_to_remove	= [];
    if (defined $data{"plugins_to_remove"}) {
	$plugins_to_remove	= $data{"plugins_to_remove"};
    }
    
    # -------------------------- now call EditBefore function from plugins
    my $plugin_error	= "";
    foreach my $plugin (sort @{$plugins}) {
	if ($plugin_error) { last; }
	my $result = UsersPlugins->Apply ("EditBefore", {
	    "what"	=> "group",
	    "type"	=> $type,
	    "org_data"	=> \%group_in_work,
	    "plugins"	=> [ $plugin ],
	    "plugins_to_remove"	=> $plugins_to_remove,
	}, \%data);
	# check if plugin has done the 'EditBefore' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    %data	= %{$result->{$plugin}};
	}
	else {
	    $result = UsersPlugins->Apply ("Error", {
		"what"	=> "group",
		"type"	=> $type,
		"plugins"	=> [ $plugin ] }, {});
	    $plugin_error = $result->{$plugin} || "";
	}
    }
    if ($plugin_error) {
	return $plugin_error;
    }
    # ----------------------------------------------------------------

    # update the settings which should be changed
    foreach my $key (keys %data) {
	if ($key eq "cn" || $key eq "gidnumber" || $key eq "type") {
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

	    my $new_dn	= UsersLDAP->CreateGroupDN (\%data);
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
	my $member_attribute	= UsersLDAP->GetMemberAttribute ();
	if ($key eq $member_attribute &&
	    defined $group_in_work{$member_attribute})
	{
	    my %removed = ();
	    foreach my $user (keys %{$group_in_work{$member_attribute}}) {
		if (!defined $data{$member_attribute}{$user}) {
		    $removed{$user} = 1;
		}
	    }
	    if (%removed) {
		$group_in_work{"removed_userlist"} = \%removed;
	    }
	}
	if ($key eq "userpassword" && $data{$key} ne "" && $data{$key} ne "x"
	    && $data{$key} ne "!") {
	    # crypt password only once (when changed)
	    if (!defined $data{"encrypted"} || !bool ($data{"encrypted"})) {
		$group_in_work{$key} = $self->CryptPassword ($data{$key},$type);
		$group_in_work{"encrypted"}	= YaST::YCP::Boolean (1);
		$data{"encrypted"}		= YaST::YCP::Boolean (1);
		next;
	    }
	}
	$group_in_work{$key}	= $data{$key};
    }
    $group_in_work{"what"}	= "edit_group";
    UsersCache->SetGroupType ($type);
    # --------------------------------- now call Edit function from plugins
    foreach my $plugin (sort @{$plugins}) {
	if ($plugin_error) { last; }
	my $result = UsersPlugins->Apply ("Edit", {
	    "what"	=> "group",
	    "type"	=> $type,
	    "plugins"	=> [ $plugin ],
	    "plugins_to_remove"	=> $plugins_to_remove,
	}, \%group_in_work);
	# check if plugin has done the 'Edit' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    %group_in_work= %{$result->{$plugin}};
	}
	else {
	    $result = UsersPlugins->Apply ("Error", {
		"what"	=> "group",
		"type"	=> $type,
		"plugins"	=> [ $plugin ] }, {});
	    $plugin_error = $result->{$plugin} || "";
	}
    }
    if ($plugin_error) {
	return $plugin_error;
    }
    # ---------------------------------------------------------------------
    return "";
}

##------------------------------------
# Adds a plugin to the group
BEGIN { $TYPEINFO{AddGroupPlugin} = ["function", "string", "string"];}
sub AddGroupPlugin {

    my $self	= shift;
    my $plugin	= shift;
   
    # do the work on local copy...
    my %group	= %group_in_work;

    my $plugins = $group{"plugins"};
    my @plugins	= ();
    if (!defined $plugins) {
	$plugins	= [];
    }
    @plugins	= @{$plugins};

    push @plugins, $plugin;
    $group{"plugins"}	= \@plugins;

    my $plugin_error	= "";

    my $args		= {
	"what"	=> "group",
	"type"	=> $group{"type"},
	"plugins"	=> [ $plugin ]
    };

    if (($group{"what"} || "") eq "add_group") {

	my $result = UsersPlugins->Apply ("AddBefore", $args, \%group);
	# check if plugin has done the 'AddBefore' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    %group= %{$result->{$plugin}};
	}
	else {
	    $result = UsersPlugins->Apply ("Error", $args, {});
	    $plugin_error = $result->{$plugin} || "";
	}

	if ($plugin_error) { return $plugin_error; }

	$result = UsersPlugins->Apply ("Add", $args, \%group);
	# check if plugin has done the 'AddBefore' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    %group= %{$result->{$plugin}};
	}
	else {
	    $result = UsersPlugins->Apply ("Error", $args, {});
	    $plugin_error = $result->{$plugin} || "";
	}
    }
    else {
	my $result = UsersPlugins->Apply ("EditBefore", $args, \%group);
	# check if plugin has done the 'EditBefore' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    %group= %{$result->{$plugin}};
	}
	else {
	    $result = UsersPlugins->Apply ("Error", $args, {});
	    $plugin_error = $result->{$plugin} || "";
	}
	if ($plugin_error) { return $plugin_error; }

	$result = UsersPlugins->Apply ("Edit", $args, \%group);
	# check if plugin has done the 'EditBefore' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    %group= %{$result->{$plugin}};
	}
	else {
	    $result = UsersPlugins->Apply ("Error", $args, {});
	    $plugin_error = $result->{$plugin} || "";
	}
	if (!defined $group{"what"}) {
	    $group{"what"}	= "edit_group";
	}
    }
    if ($plugin_error) { return $plugin_error; }
    %group_in_work	= %group;
    return "";
}


##------------------------------------
# Adds a plugin to the user
BEGIN { $TYPEINFO{AddUserPlugin} = ["function", "string", "string"];}
sub AddUserPlugin {

    my $self	= shift;
    my $plugin	= shift;

    # do the work on local copy...
    my %user	= %user_in_work;

    my $plugins = $user{"plugins"};
    my @plugins	= ();
    if (!defined $plugins) {
	$plugins	= [];
    }
    @plugins	= @{$plugins};
    push @plugins, $plugin;
    $user{"plugins"}	= \@plugins;

    my $plugin_error	= "";

    my $args		= {
	"what"		=> "user",
	"type"		=> $user{"type"},
	"plugins"	=> [ $plugin ]
    };

    if (($user{"what"} || "") eq "add_user") {

	my $result = UsersPlugins->Apply ("AddBefore", $args, \%user);
	# check if plugin has done the 'AddBefore' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    %user= %{$result->{$plugin}};
	}
	else {
	    $result = UsersPlugins->Apply ("Error", $args, {});
	    $plugin_error = $result->{$plugin} || "";
	}
	if ($plugin_error) { return $plugin_error; }

	$result = UsersPlugins->Apply ("Add", $args, \%user);
	# check if plugin has done the 'AddBefore' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    %user= %{$result->{$plugin}};
	}
	else {
	    $result = UsersPlugins->Apply ("Error", $args, {});
	    $plugin_error = $result->{$plugin} || "";
	}
    }
    else {
	my $result = UsersPlugins->Apply ("EditBefore", $args, \%user);
	# check if plugin has done the 'EditBefore' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    %user= %{$result->{$plugin}};
	}
	else {
	    $result = UsersPlugins->Apply ("Error", $args, {});
	    $plugin_error = $result->{$plugin} || "";
	}
	if ($plugin_error) { return $plugin_error; }

	$result = UsersPlugins->Apply ("Edit", $args, \%user);
	# check if plugin has done the 'EditBefore' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    %user= %{$result->{$plugin}};
	}
	else {
	    $result = UsersPlugins->Apply ("Error", $args, {});
	    $plugin_error = $result->{$plugin} || "";
	}
	if (!defined $user{"what"}) {
	    $user{"what"}	= "edit_user";
	}
    }

    if ($plugin_error) { return $plugin_error; }

    %user_in_work	= %user;
    return "";
}

##------------------------------------
# Removes a plugin from the group
BEGIN { $TYPEINFO{RemoveGroupPlugin} = ["function", "string", "string"];}
sub RemoveGroupPlugin {

    my $self	= shift;
    my $plugin	= shift;
      
    # do the work on local copy...
    my %group	= %group_in_work;
 
    my $plugins = $group{"plugins"};
    if (defined $plugins && contains ($plugins, $plugin)) {

	my @new_plugins	= ();
	foreach my $p (@$plugins) {
	    if ($p ne $plugin) {
		push @new_plugins, $p;
	    }
	}
	$group{"plugins"}	= \@new_plugins;
    }

    my $plugins_to_remove = $group{"plugins_to_remove"};
    if (!defined $plugins_to_remove) {
	$plugins_to_remove	= [];
    }
    my @plugins_to_remove	= @{$plugins_to_remove};
    push @plugins_to_remove, $plugin;
    $group{"plugins_to_remove"}	= \@plugins_to_remove;

    my $plugin_error	= "";
	
    my $args		= {
	"what"		=> "group",
	"type"		=> $group{"type"},
	"plugins"	=> [ $plugin ]
    };

    if (($group{"what"} || "") eq "add_group") {

	my $result = UsersPlugins->Apply ("AddBefore", $args, \%group);
	# check if plugin has done the 'AddBefore' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    %group= %{$result->{$plugin}};
	}
	else {
	    $result = UsersPlugins->Apply ("Error", $args, {});
	    $plugin_error = $result->{$plugin} || "";
	}
	if ($plugin_error) { return $plugin_error; }

	$result = UsersPlugins->Apply ("Add", $args, \%group);
	# check if plugin has done the 'AddBefore' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    %group= %{$result->{$plugin}};
	}
	else {
	    $result = UsersPlugins->Apply ("Error", $args, {});
	    $plugin_error = $result->{$plugin} || "";
	}
    }
    else {
	my $result = UsersPlugins->Apply ("EditBefore", $args, \%group);
	# check if plugin has done the 'EditBefore' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    %group= %{$result->{$plugin}};
	}
	else {
	    $result = UsersPlugins->Apply ("Error", $args, {});
	    $plugin_error = $result->{$plugin} || "";
	}
	if ($plugin_error) { return $plugin_error; }

	$result = UsersPlugins->Apply ("Edit", $args, \%group);
	# check if plugin has done the 'EditBefore' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    %group= %{$result->{$plugin}};
	}
	else {
	    $result = UsersPlugins->Apply ("Error", $args, {});
	    $plugin_error = $result->{$plugin} || "";
	}
	if (!defined $group{"what"}) {
	    $group{"what"}	= "edit_group";
	}
    }
    if ($plugin_error) { return $plugin_error; }
    
    %group_in_work	= %group;
    return "";
}

##------------------------------------
# Removes a plugin from the user
BEGIN { $TYPEINFO{RemoveUserPlugin} = ["function", "string", "string"];}
sub RemoveUserPlugin {

    my $self	= shift;
    my $plugin	= shift;

    # do the work on local copy...
    my %user	= %user_in_work;
   
    my $plugins = $user{"plugins"};
    if (defined $plugins && contains ($plugins, $plugin)) {

	my @new_plugins	= ();
	foreach my $p (@$plugins) {
	    if ($p ne $plugin) {
		push @new_plugins, $p;
	    }
	}
	$user{"plugins"}	= \@new_plugins;
    }

    my $plugins_to_remove = $user{"plugins_to_remove"};
    if (!defined $plugins_to_remove) {
	$plugins_to_remove	= [];
    }
    my @plugins_to_remove = @{$plugins_to_remove};
    push @plugins_to_remove, $plugin;
    $user{"plugins_to_remove"}	= \@plugins_to_remove;

    my $plugin_error	= "";

    my $args		= {
	"what"		=> "user",
	"type"		=> $user{"type"},
	"plugins"	=> [ $plugin ]
    };

    if (($user{"what"} || "") eq "add_user") {

	my $result = UsersPlugins->Apply ("AddBefore", $args, \%user);
	# check if plugin has done the 'AddBefore' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    %user= %{$result->{$plugin}};
	}
	else {
	    $result = UsersPlugins->Apply ("Error", $args, {});
	    $plugin_error = $result->{$plugin} || "";
	}
	if ($plugin_error) { return $plugin_error; }

	$result = UsersPlugins->Apply ("Add", $args, \%user);
	# check if plugin has done the 'AddBefore' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    %user= %{$result->{$plugin}};
	}
	else {
	    $result = UsersPlugins->Apply ("Error", $args, {});
	    $plugin_error = $result->{$plugin} || "";
	}
    }
    else {
	my $result = UsersPlugins->Apply ("EditBefore", $args, \%user);
	# check if plugin has done the 'EditBefore' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    %user= %{$result->{$plugin}};
	}
	else {
	    $result = UsersPlugins->Apply ("Error", $args, {});
	    $plugin_error = $result->{$plugin} || "";
	}
	if ($plugin_error) { return $plugin_error; }

	$result = UsersPlugins->Apply ("Edit", $args, \%user);
	# check if plugin has done the 'EditBefore' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    %user= %{$result->{$plugin}};
	}
	else {
	    $result = UsersPlugins->Apply ("Error", $args, {});
	    $plugin_error = $result->{$plugin} || "";
	}
	if (!defined $user{"what"}) {
	    $user{"what"}	= "edit_user";
	}
    }
    if ($plugin_error) { return $plugin_error; }
    %user_in_work	= %user;
    return "";
}

##------------------------------------
# Initializes user_in_work map with default values
# @param data user initial data (could be an empty map)
BEGIN { $TYPEINFO{AddUser} = ["function",
    "string",
    ["map", "string", "any" ]];		# data to fill in
}
sub AddUser {

    my $self	= shift;
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
	while ($i >= 0 ) {
	    # nis user cannot be added from client
	    if ($current_users[$i] ne "nis") {
		$type = $current_users[$i];
	    }
	    $i --;
	}
    }

    # -------------------------- now call AddBefore function from plugins
    if (!defined $user_in_work{"plugins"}) {
	$user_in_work{"plugins"}	= $self->GetUserPlugins ($type);
    }
    my $plugins		= $user_in_work{"plugins"};
    if (defined $data{"plugins"} && ref ($data{"plugins"}) eq "ARRAY") {
	$plugins	= $data{"plugins"};
    }
    my $plugin_error	= "";
    foreach my $plugin (sort @{$plugins}) {#FIXME sort: default LDAP plugin shoul be first!!! (or Samba plugin must add object classes every time)
	if ($plugin_error) { last; }
	my $result = UsersPlugins->Apply ("AddBefore", {
	    "what"	=> "user",
	    "type"	=> $type,
	    "plugins"	=> [ $plugin ]
	}, \%data);
	# check if plugin has done the 'AddBefore' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    %data	= %{$result->{$plugin}};
	}
	else {
	    $result = UsersPlugins->Apply ("Error", {
		"what"	=> "user",
		"type"	=> $type,
		"plugins"	=> [ $plugin ] }, {});
	    $plugin_error = $result->{$plugin} || "";
	}
    }
    if ($plugin_error) {
	return $plugin_error;
    }

    # ----------------------------------------------------------------

    # now copy the data to map of current user
    foreach my $key (keys %data) {
	if ($key eq "create_home" || $key eq "encrypted" ||
	    $key eq "delete_home" || $key eq "no_skeleton" ||
	    $key eq "disabled" || $key eq "enabled") {
	    $user_in_work{$key}	= YaST::YCP::Boolean ($data{$key});
	}
	# crypt password only once
	elsif ($key eq "userpassword" &&
	      (!defined $data{"encrypted"} || !bool ($data{"encrypted"})) &&
	      $data{$key} ne "" && $data{$key} ne "x" && $data{$key} ne "!")
	{
	    $user_in_work{$key} = $self->CryptPassword ($data{$key}, $type);
	    $user_in_work{"encrypted"}	= YaST::YCP::Boolean (1);
	    $user_in_work{"text_userpassword"} = $data{$key};
	}
	else {
	    $user_in_work{$key}	= $data{$key};
	}
    }
    $user_in_work{"type"}	= $type;
    $user_in_work{"what"}	= "add_user";

    UsersCache->SetUserType ($type);

    if (!defined $user_in_work{"uidnumber"}) {
	$user_in_work{"uidnumber"} = UsersCache->NextFreeUID ();
    }
    my $username		= $data{"uid"} || $data{"username"};
    if (defined $username) {
	$user_in_work{"uid"}	= $username;
    }

    if (!defined $user_in_work{"cn"}) {
	$user_in_work{"cn"}	= "";
    }
    if (!defined $user_in_work{"gidnumber"}) {
	$user_in_work{"gidnumber"}	= $self->GetDefaultGID ($type);
    }
    if (!defined $user_in_work{"groupname"}) {
	my %group	= %{$self->GetGroup ($user_in_work{"gidnumber"}, "")};
	if (%group) {
	    $user_in_work{"groupname"}	= $group{"cn"};
	}
	else {
	    $user_in_work{"groupname"}	= $self->GetDefaultGroupname ($type);
	}
    }
    if (!defined $user_in_work{"grouplist"}) {
	$user_in_work{"grouplist"}	= $self->GetDefaultGrouplist ($type);
    }
    if (!defined $user_in_work{"homedirectory"} && defined ($username)) {
	$user_in_work{"homedirectory"} = $self->GetDefaultHome ($type).$username;
    }
    if (!defined $user_in_work{"loginshell"}) {
	$user_in_work{"loginshell"}	= $self->GetDefaultShell ($type);
    }
    if (!defined $user_in_work{"create_home"}) {
	$user_in_work{"create_home"}	= YaST::YCP::Boolean (1);
    }
    my %default_shadow = %{$self->GetDefaultShadow ($type)};
    foreach my $shadow_item (keys %default_shadow) {
	if (!defined $user_in_work{$shadow_item}) {
	    $user_in_work{$shadow_item}	= $default_shadow{$shadow_item};
	}
    }
    if (!defined $user_in_work{"shadowlastchange"} ||
	$user_in_work{"shadowlastchange"} eq "") {
        $user_in_work{"shadowlastchange"} = LastChangeIsNow ();
    }
    if (!defined $user_in_work{"userpassword"}) {
	$user_in_work{"userpassword"}	= "";
    }
    if (!defined $user_in_work{"no_skeleton"} && $type eq "system") {
	$user_in_work{"no_skeleton"}	= YaST::YCP::Boolean (1);
    }

    if ($type eq "ldap") {
        # add other default values
	my %ldap_defaults	= %{UsersLDAP->GetUserDefaults()};
	foreach my $attr (keys %ldap_defaults) {
	    if (!defined ($user_in_work{$attr})) {
		$user_in_work{$attr}	= $ldap_defaults{$attr};
	    }
	};
	# created DN if not present yet
	if (!defined $user_in_work{"dn"}) {
	    my $dn = UsersLDAP->CreateUserDN (\%data);
	    if (defined $dn) {
		$user_in_work{"dn"} = $dn;
	    }
	}
    }
    # --------------------------------- now call Add function from plugins
    foreach my $plugin (sort @{$plugins}) {
	if ($plugin_error) { last; }
	my $result = UsersPlugins->Apply ("Add", {
	    "what"	=> "user",
	    "type"	=> $type,
	    "plugins"	=> [ $plugin ]
	}, \%user_in_work);
	# check if plugin has done the 'Add' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    %user_in_work= %{$result->{$plugin}};
	}
	else {
	    $result = UsersPlugins->Apply ("Error", {
		"what"	=> "user",
		"type"	=> $type,
		"plugins"	=> [ $plugin ] }, {});
	    $plugin_error = $result->{$plugin} || "";
	}
    }
    if ($plugin_error) {
	return $plugin_error;
    }
    # ---------------------------------------------------------------------

    # now handle possible login disabling
    # should it really be called from Add/Edit functions...?
    if (bool ($user_in_work{"disabled"})) {
	$plugin_error = $self->DisableUser (\%user_in_work);
    }
    if (bool ($user_in_work{"enabled"})) {
	$plugin_error = $self->EnableUser (\%user_in_work);
    }
    return $plugin_error;
}

##------------------------------------
# Simplified version of Add/Edit user: just take arguments and copy them
# to current user map; doesn't do any checks or default adds
BEGIN { $TYPEINFO{UpdateUser} = ["function",
    "void",
    ["map", "string", "any" ]];		# data to change in user_in_work
}
sub UpdateUser {

    my $self	= shift;
    my %data	= %{$_[0]};
    foreach my $key (keys %data) {
	$user_in_work{$key}	= $data{$key};
    }
}

##------------------------------------
BEGIN { $TYPEINFO{UpdateGroup} = ["function",
    "void",
    ["map", "string", "any" ]];		# data to change in user_in_work
}
sub UpdateGroup {

    my $self	= shift;
    my %data	= %{$_[0]};
    foreach my $key (keys %data) {
	$group_in_work{$key}	= $data{$key};
    }
}    

##------------------------------------
# Initializes group_in_work map with default values
# @param data group initial data (could be an empty map)
BEGIN { $TYPEINFO{AddGroup} = ["function",
    "string",
    ["map", "string", "any" ]];		# data to fill in
}
sub AddGroup {

    my $self	= shift;
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

    # ----------------------- now call AddBefore function from plugins
    my $plugin_error	= "";
    if (!defined $group_in_work{"plugins"}) {
	$group_in_work{"plugins"}	= $self->GetUserPlugins ($type);
    }
    my $plugins		= $group_in_work{"plugins"};
    
    if (defined $data{"plugins"} && ref ($data{"plugins"}) eq "ARRAY") {
	$plugins	= $data{"plugins"};
    }
    foreach my $plugin (sort @{$plugins}) {
	if ($plugin_error) { last; }
	my $result = UsersPlugins->Apply ("AddBefore", {
	    "what"	=> "group",
	    "type"	=> $type,
	    "plugins"	=> [ $plugin ]
	}, \%data);
	# check if plugin has done the 'AddBefore' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    %data	= %{$result->{$plugin}};
	}
	else {
	    $result = UsersPlugins->Apply ("Error", {
		"what"	=> "group",
		"type"	=> $type,
		"plugins"	=> [ $plugin ] }, {});
	    $plugin_error = $result->{$plugin} || "";
	}
    }
    if ($plugin_error) {
	return $plugin_error;
    }
    # ----------------------------------------------------------------

    foreach my $key (keys %data) {
	if ($key eq "userpassword" && !bool ($data{"encrypted"}) &&
	    $data{$key} ne "" && $data{$key} ne "x" && $data{$key} ne "!") {
	    
	    # crypt password only once
	    $group_in_work{$key} = $self->CryptPassword ($data{$key},$type);
	    $group_in_work{"encrypted"}	= YaST::YCP::Boolean (1);
	}
	else {
	    $group_in_work{$key}	= $data{$key};
	}
    }

    $group_in_work{"type"}		= $type;
    $group_in_work{"what"}		= "add_group";
	
    UsersCache->SetGroupType ($type);

    if (!defined $group_in_work{"gidnumber"}) {
	$group_in_work{"gidnumber"}	= UsersCache->NextFreeGID ($type);
    }
    
    if ($type eq "ldap") {
        # add other default values
	my %ldap_defaults	= %{UsersLDAP->GetGroupDefaults()};
	foreach my $attr (keys %ldap_defaults) {
	    if (!defined ($group_in_work{$attr})) {
		$group_in_work{$attr}	= $ldap_defaults{$attr};
	    }
	};
	# created DN if not present yet
	if (!defined $group_in_work{"dn"}) {
	    my $dn = UsersLDAP->CreateGroupDN (\%data);
	    if (defined $dn) {
		$group_in_work{"dn"} = $dn;
	    }
	}
    }
    # --------------------------------- now call Add function from plugins
    foreach my $plugin (sort @{$plugins}) {
	if ($plugin_error) { last; }
	my $result = UsersPlugins->Apply ("Add", {
	    "what"	=> "group",
	    "type"	=> $type,
	    "plugins"	=> [ $plugin ]
	}, \%group_in_work);
	# check if plugin has done the 'Add' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    %group_in_work= %{$result->{$plugin}};
	}
	else {
	    $result = UsersPlugins->Apply ("Error", {
		"what"	=> "group",
		"type"	=> $type,
		"plugins"	=> [ $plugin ] }, {});
	    $plugin_error = $result->{$plugin} || "";
	}
    }
    if ($plugin_error) {
	return $plugin_error;
    }
    # ---------------------------------------------------------------------
    return "";
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
# Checks if commited user is really modified and has to be saved
sub UserReallyModified {

    my $self	= shift;
    my %user	= %{$_[0]};
    if (($user{"what"} || "") eq "group_change") {
        return 0;
    }
    if (($user{"what"} || "") ne "edit_user" ||
	bool ($user{"disabled"}) || bool ($user{"enabled"})) {
        return 1;
    }

    my $ret = 0;

    my %org_user	= ();
    if (defined $user{"org_user"}) {
	%org_user	= %{$user{"org_user"}};
    }
    if ($user{"type"} ne "ldap") {
	# grouplist can be ignored, it is a modification of groups
	while ( my ($key, $value) = each %org_user) {

	    if ($key eq "grouplist") {
		next;
	    }
	    if (defined $user{$key} &&
		(ref ($value) eq "YaST::YCP::Boolean" && 
		 ref ($user{$key}) eq "YaST::YCP::Boolean") ||
		(ref ($value) eq "YaST::YCP::Integer" && 
		 ref ($user{$key}) eq "YaST::YCP::Integer"))
	    {
		if ($user{$key}->value() != $value->value())
		{
		    $ret = 1;
		    y2milestone ("old value: ", $value->value());
		    y2milestone ("changed to: ", $user{$key}->value());
		}
		next;
	    }
	    if (!defined $user{$key} || $user{$key} ne $value)
	    {
		$ret = 1;
		y2debug ("old value: $value, changed to: ",
		    $user{$key} || "-" );
	    }
	}
	return $ret;
#FIXME what if there is a new key? it's not in org_user map...
    }
    # search result, because some attributes were not filled yet
    my @internal_keys	= @{UsersLDAP->GetUserInternal ()};
    foreach my $key (keys %user) {

	my $value = $user{$key};
	if (!defined $user{$key} || contains (\@internal_keys, $key) ||
	    ref ($value) eq "HASH" ) {
	    next;
	}
	if (!defined ($org_user{$key})) {
	    if ($value ne "") {
		$ret = 1;
	    }
	}
	elsif (ref ($value) eq "ARRAY") {
	    if (ref ($org_user{$key}) ne "ARRAY" ||
		!same_arrays ($org_user{$key}, $value)) {
		$ret = 1;
	    }
	}
        elsif ($org_user{$key} ne $value) {
	    if ((ref ($value) eq "YaST::YCP::Boolean" && 
		 ref ($org_user{$key}) eq "YaST::YCP::Boolean") ||
		(ref ($value) eq "YaST::YCP::Integer" && 
		 ref ($org_user{$key}) eq "YaST::YCP::Integer")) {
		if ($user{$key}->value() == $value->value()) { next;}
	    }
	    $ret = 1;
	}
    }
    return $ret;
}

# Substitute the values of LDAP atributes, predefined in LDAP user configuration
BEGIN { $TYPEINFO{SubstituteUserValues} = ["function", "void"] }
sub SubstituteUserValues {

    my $self	= shift;
    my $substituted = UsersLDAP->SubstituteValues ("user", \%user_in_work);
    if (defined $substituted && ref ($substituted) eq "HASH") {
	%user_in_work = %{$substituted};
    }
}


##------------------------------------
# Update the global map of users using current user or group
BEGIN { $TYPEINFO{CommitUser} = ["function", "boolean"] }
sub CommitUser {

    my $self	= shift;
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
    my $uid		= $user{"uidnumber"};
    my $org_uid		= $user{"org_uidnumber"} || $uid;
    my $username	= $user{"uid"};
    my $org_username	= $user{"org_uid"} || $username;
    my $groupname	= $user{"groupname"} || $self->GetDefaultGroupname ($type);
    my $home		= $user{"homedirectory"} || "";
    my %grouplist	= ();
    if (defined $user{"grouplist"} && ref ($user{"grouplist"}) eq "HASH") {
	%grouplist	= %{$user{"grouplist"}};
    }

    if (($type eq "local" || $type eq "system") &&
	!$users_modified && $self->UserReallyModified (\%user)) {
	    $users_modified = 1;
    }
    if ($type eq "ldap" && !$ldap_modified && $self->UserReallyModified (\%user)) {
        $ldap_modified = 1;
    }

    y2milestone ("commiting user '$username', action is '$what_user', modified: $users_modified, ldap modified: $ldap_modified");

    # --- 1. do the special action
    if ($what_user eq "add_user") {
	
        $user{"modified"}	= "added";

	if ($type eq "ldap") {
	    my $substituted = UsersLDAP->SubstituteValues ("user", \%user);
	    if (defined $substituted && ref ($substituted) eq "HASH") {
		%user = %{$substituted};
	    }
	}

        # update the affected groups
        foreach my $group (keys %grouplist) {
            %group_in_work = %{$self->GetGroupByName ($group, $type)};
            if (%group_in_work && $self->AddUserToGroup ($username)) {
                $self->CommitGroup ();
	    }
        };
        # add user to his default group (updating only cache variables)
        %group_in_work = %{$self->GetGroupByName ($groupname, $type)};
        if (%group_in_work) {
            $group_in_work{"what"}	= "user_change_default";
            $group_in_work{"more_users"}{$username}	= 1;
            $self->CommitGroup ();
        }

        # check if home directory for this user doesn't already exist
        if (defined $removed_homes{$home}) {
	    delete $removed_homes{$home};
        }

        # add new entry to global shadow map:
        $shadow{$type}{$username}	= $self->CreateShadowMap (\%user);
    }
    elsif ( $what_user eq "edit_user" ) {

        if (!defined $user{"modified"}) {
            $user{"modified"}	= "edited";
	}
        # check the change of additional group membership
        foreach my $group (keys %grouplist) {

            %group_in_work = %{$self->GetGroupByName ($group, $type)};
            if (%group_in_work) {
	        # username changed - remove org_username
	        if ($org_username ne $username) {
		   $self->RemoveUserFromGroup ($org_username);
	        }
	        if ($self->AddUserToGroup ($username)) {
		   $self->CommitGroup ();
	        }
	    }
        };

        # check if user was removed from some additional groups
	if (defined $user{"removed_grouplist"}) {
            foreach my $group (keys %{$user{"removed_grouplist"}}) {
	        %group_in_work = %{$self->GetGroupByName ($group, $type)};
	        if (%group_in_work &&
		    $self->RemoveUserFromGroup ($org_username)) {
		    $self->CommitGroup ();
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
            %group_in_work	= %{$self->GetGroupByName ($groupname, $type)};
            if (%group_in_work) {
                $group_in_work{"what"}	= "user_change_default";
                delete $group_in_work{"more_users"}{$org_username};
                $group_in_work{"more_users"}{$username}	= 1;
                $self->CommitGroup ();
            }
        }
        elsif ($groupname ne $org_groupname) {
            # note: username could be also changed!
            # 1. remove the name from original group ...
            %group_in_work = %{$self->GetGroupByName ($org_groupname, $type)};
            if (%group_in_work) {
                $group_in_work{"what"}	= "user_change_default";
                delete $group_in_work{"more_users"}{$org_username};
                $self->CommitGroup ();
            }
            # 2. and add it to the new one:
            %group_in_work	= %{$self->GetGroupByName ($groupname, $type)};
            if (%group_in_work) {
                $group_in_work{"what"}	= "user_change_default";
                $group_in_work{"more_users"}{$username}	= 1;
                $self->CommitGroup ();
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
            $shadow{$type}{$username} = $self->CreateShadowMap (\%user);
        }
    }
    elsif ( $what_user eq "group_change_default") {
	# gid of default group was changed
	$user{"modified"} = "edited";
    }
    elsif ( $what_user eq "delete_user" ) {

        # prevent the add & delete of the same user
        if (!defined $user{"modified"} || $user{"modified"} ne "added") {
            $user{"modified"} = "deleted";
	    $removed_users{$type}{$uid}	= \%user;
        }

        # check the change of group membership
        foreach my $group (keys %grouplist) {
            %group_in_work = %{$self->GetGroupByName ($group, $type)};
            if (%group_in_work &&
	        $self->RemoveUserFromGroup ($org_username)) {
                $self->CommitGroup();
	    }
        };
        # remove user from his default group -- only cache structures
        %group_in_work		= %{$self->GetGroupByName ($groupname, $type)};
	if (%group_in_work) {
	    $group_in_work{"what"}	= "user_change_default";
            delete $group_in_work{"more_users"}{$username};
	    $self->CommitGroup ();
	}

	# store deleted directories... someone could want to use them
	if ($type ne "ldap" && bool ($user{"delete_home"})) {
	    my $h	= $home;
	    if (defined $user{"org_user"}{"homedirectory"}) {
	        $h	= $user{"org_user"}{"homedirectory"};
	    }
	    $removed_homes{$h}	= 1;
	}
    }

    # --- 2. and now do the common changes

    UsersCache->CommitUser (\%user);
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

        $user{"org_uidnumber"}			= $uid;
        $user{"org_uid"}			= $username;
	if ($home ne "") {
	    $user{"org_homedirectory"}		= $home;
	}
        $users{$type}{$uid}			= \%user;
        $users_by_name{$type}{$username}	= $uid;

	if ((($user{"modified"} || "") ne "") && $what_user ne "group_change") {
	    $modified_users{$type}{$uid}	= \%user;
	}
    }
    undef %user_in_work;
    return 1;
}

# Substitute the values of LDAP atributes,predefined in LDAP group configuration
BEGIN { $TYPEINFO{SubstituteGroupValues} = ["function", "void"] }
sub SubstituteGroupValues {

    my $self	= shift;
    my $substituted = UsersLDAP->SubstituteValues ("group", \%group_in_work);
    if (defined $substituted && ref ($substituted) eq "HASH") {
	%group_in_work = %{$substituted};
    }
}


##------------------------------------
# Update the global map of groups using current group
BEGIN { $TYPEINFO{CommitGroup} = ["function", "boolean"]; }
sub CommitGroup {

    my $self	= shift;

    if (!%group_in_work || !defined $group_in_work{"gidnumber"} ||
	!defined $group_in_work{"cn"}) {
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
    my $groupname    	= $group{"cn"};
    my $org_groupname	= $group{"org_cn"} || $groupname;
    my $gid    		= $group{"gidnumber"};
    my $org_gid		= $group{"org_gidnumber"} || $gid;
    my %userlist	= ();
    if (defined $group{"userlist"}) {
	%userlist	= %{$group{"userlist"}};
    }
    y2milestone ("commiting group '$groupname', action is '$what_group'");

    if ($type eq "system" || $type eq "local") {
	$groups_modified = 1;
    }
    if ($type eq "ldap" && $what_group ne "") {
	$ldap_modified	= 1;
	my $member_attribute	= UsersLDAP->GetMemberAttribute ();
	if (defined $group{$member_attribute}) {
	    %userlist	= %{$group{$member_attribute}};
	}
    }

    # 1. specific action
    if ( $what_group eq "add_group" ) {

	$group{"modified"} = "added";
        # update users's grouplists (only cache structures)
        foreach my $user (keys %userlist) {
            %user_in_work = %{$self->GetUserByName ($user, "")};
	    if (%user_in_work) {
                $user_in_work{"grouplist"}{$groupname}	= 1;
	        $user_in_work{"what"} = "group_change";
	        $self->CommitUser ();
	    }
        };
    }
    elsif ($what_group eq "edit_group") {
	if (!defined $group{"modified"}) {
	    $group{"modified"}	= "edited";
	}
        # update users's grouplists (mainly cache structures)
        foreach my $user (keys %userlist) {
            %user_in_work = %{$self->GetUserByName ($user, "")};
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
                    $self->CommitUser ();
                }
            }
        };
        # check the additional users removed from our group
        foreach my $user (keys %{$group{"removed_userlist"}}) {
            %user_in_work = %{$self->GetUserByName ($user, "")};
            if (%user_in_work) {
                if (defined $user_in_work{"grouplist"}{$org_groupname}) {
		    delete $user_in_work{"grouplist"}{$org_groupname};
                    $user_in_work{"what"}	= "group_change";
                    $self->CommitUser ();
                }
            }
	};
        # correct the changed groupname/gid of our group for users
	# having this group as default
        if ($groupname ne $org_groupname || $gid != $org_gid) {
            foreach my $user (keys %{$group{"more_users"}}) {
                %user_in_work = %{$self->GetUserByName ($user, "")};
                if (%user_in_work) {
		    $user_in_work{"groupname"}	= $groupname;
                    $user_in_work{"gidnumber"}	= $gid;
		    $user_in_work{"what"}		= "group_change";
		    if ($gid != $org_gid) {
			$user_in_work{"what"} 	= "group_change_default";
		    }
                    $self->CommitUser ();
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
    UsersCache->CommitGroup (\%group);
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

        # this has to be done due to multiple changes of groupname
        $group{"org_cn"}			= $groupname;
        $group{"org_gidnumber"}			= $gid;

        $groups{$type}{$gid}			= \%group;
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

    my $self	= shift;
    my %customs = (
        "custom_users"			=> \@user_custom_sets,
        "custom_groups"			=> \@group_custom_sets,
    );
    $customs{"dont_warn_when_uppercase"} =
	YaST::YCP::Boolean ($not_ask_uppercase);
    my $ret = SCR->Write (".target.ycp", Directory->vardir()."/users.ycp", \%customs);

    y2milestone ("Custom user information written: ", $ret);
    return $ret;
}

##------------------------------------
# Writes settings to /etc/defaults/useradd
sub WriteLoginDefaults {

    my $self	= shift;
    my $ret 	= 1;

    foreach my $key (keys %useradd_defaults) {
	my $value	= $useradd_defaults{$key};
	$ret = $ret && SCR->Write (".etc.default.useradd.\"\Q$key\E\"", $value);
    }

    if ($ret) {
	SCR->Write (".etc.default.useradd", "force");
    }
    y2milestone ("Succesfully written useradd defaults: $ret");
    return $ret;
}

##------------------------------------
# Save Security settings (encryption method) if changed in Users module
BEGIN { $TYPEINFO{WriteSecurity} = ["function", "boolean"]; }
sub WriteSecurity {

    my $self	= shift;
    my $ret = 1;
    if ($security_modified) {
	
	my %security	= (
	    "PASSWD_ENCRYPTION"	=> $encryption_method
	);
	Security->Import (\%security);
	Progress->off();
	$ret = Security->Write();
	if (!$write_only && $use_gui) {
	    Progress->on();
	}
    }
    y2milestone ("Security module settings written: $ret");	
    return $ret;
}


##------------------------------------
BEGIN { $TYPEINFO{WriteGroup} = ["function", "boolean"]; }
sub WriteGroup {

    SCR->Execute (".target.bash", "/bin/cp $base_directory/group $base_directory/group.YaST2save");
    return SCR->Write (".passwd.groups", \%groups);
}

##------------------------------------
BEGIN { $TYPEINFO{WritePasswd} = ["function", "boolean"]; }
sub WritePasswd {
    SCR->Execute (".target.bash", "/bin/cp $base_directory/passwd $base_directory/passwd.YaST2save");
    return SCR->Write (".passwd.users", \%users);
}

##------------------------------------
BEGIN { $TYPEINFO{WriteShadow} = ["function", "boolean"]; }
sub WriteShadow {
    
    SCR->Execute (".target.bash", "/bin/cp $base_directory/shadow $base_directory/shadow.YaST2save");
    return SCR->Write (".passwd.shadow", \%shadow);
}

##------------------------------------
sub DeleteUsers {

    my $ret = 1;

    foreach my $type ("system", "local") {
	if (!defined $removed_users{$type} || $userdel_precmd eq "") {
	    next;
	}
	foreach my $uid (keys %{$removed_users{$type}}) {
	    my %user = %{$removed_users{$type}{$uid}};
	    my $cmd = sprintf ("$userdel_precmd %s $uid %i %s",
		$user{"uid"}, $user{"gidnumber"}, $user{"homedirectory"});
	    SCR->Execute (".target.bash", $cmd);
	};
    };

    foreach my $home (keys %removed_homes) {
	$ret = $ret && UsersRoutines->DeleteHome ($home);
    };

    foreach my $type ("system", "local") {
	if (!defined $removed_users{$type} || $userdel_postcmd eq "") {
	    next;
	}
	foreach my $uid (keys %{$removed_users{$type}}) {
	    my %user = %{$removed_users{$type}{$uid}};
	    my $cmd = sprintf ("$userdel_postcmd %s $uid %i %s",
		$user{"uid"}, $user{"gidnumber"}, $user{"homedirectory"});
	    SCR->Execute (".target.bash", $cmd);
	};
    };
    return $ret;
}

##------------------------------------
# After doing 'Write Changes Now', we must uncheck the 'modified' flags
# of users/groups that were just written.
# Otherwise, user previously added couldn't be deleted after such write...
BEGIN { $TYPEINFO{UpdateUsersAfterWrite} = ["function", "void", "string"]; }
sub UpdateUsersAfterWrite {

    my $self	= shift;
    my $type	= shift;
	
    if (ref ($modified_users{$type}) eq "HASH") {
        foreach my $uid (keys %{$modified_users{$type}}) {
	    my $a = $modified_users{$type}{$uid}{"modified"};
	    if (!defined $a) { next;}
	    if (defined $users{$type}{$uid}) {
		if (($users{$type}{$uid}{"modified"} || "") eq $a) {
		    delete $users{$type}{$uid}{"modified"};
		}
		# org_user map must be also removed (e.g. for multiple renames)
		if (defined $users{$type}{$uid}{"org_user"}) {
		    delete $users{$type}{$uid}{"org_user"};
		}
	    }
	}
    }
}

BEGIN { $TYPEINFO{UpdateGroupsAfterWrite} = ["function", "void", "string"]; }
sub UpdateGroupsAfterWrite {

    my $self	= shift;
    my $type	= shift;

    if (ref ($modified_groups{$type}) eq "HASH") {
        foreach my $gid (keys %{$modified_groups{$type}}) {
	    my $a = $modified_groups{$type}{$gid}{"modified"};
	    if (!defined $a) { next;}
	    if (defined $groups{$type}{$gid}) {
		if (($groups{$type}{$gid}{"modified"} || "") eq $a) {
		    delete $groups{$type}{$gid}{"modified"};
		}
		# org_group map must be also removed (e.g. for multiple renames)
		if (defined $groups{$type}{$gid}{"org_group"}) {
		    delete $groups{$type}{$gid}{"org_group"};
		}
	    }
	}
    }
}

# internal function: get the error generated by plugin (if any)
# First parameter is configuration map, 2nd is original result map of call
# which was done on all plugins.
sub GetPluginError {

    my $config	= shift;
    my $result	= shift;
    my $error	= "";

    if (ref ($result) eq "HASH") {
	foreach my $plugin (keys %{$result}) {
	    if ($error) { last; }
	    if (! bool ($result->{$plugin})) {
		$config->{"plugins"}	= [ $plugin ];
		my $res = UsersPlugins->Apply ("Error", $config, {});
		$error	= $res->{$plugin} || "";
	    }
	}
    }
    return $error;
}

##------------------------------------
BEGIN { $TYPEINFO{Write} = ["function", "string"]; }
sub Write {

    my $self		= shift;
    my $ret		= "";
    my $nscd_passwd	= 0;
    my $nscd_group	= 0;

    # progress caption
    my $caption 	= __("Writing user and group configuration...");
    my $no_of_steps 	= 8;

    if ($use_gui) {
	Progress->New ($caption, " ", $no_of_steps,
	    [
		# progress stage label
		__("Write LDAP users and groups"),
		# progress stage label
		__("Write groups"),
		# progress stage label
		__("Check for deleted users"),
		# progress stage label
		__("Write users"),
		# progress stage label
		__("Write passwords"),
		# progress stage label
		__("Write the custom settings"),
		# progress stage label
		__("Write the default login settings")
           ], [
		# progress step label
		__("Writing LDAP users and groups..."),
		# progress step label
		__("Writing groups..."),
		# progress step label
		__("Checking deleted users..."),
		# progress step label
		__("Writing users..."),
		# progress step label
		__("Writing passwords..."),
		# progress step label
		__("Writing the custom settings..."),
		# progress step label
		__("Writing the default login settings..."),
		# final progress step label
		__("Finished")
	    ], "" );
    } 

    # Write LDAP users and groups
    if ($use_gui) { Progress->NextStage (); }

    if ($ldap_modified) {
	my $error_msg	= "";

	if (defined ($removed_users{"ldap"})) {
	    $error_msg	= UsersLDAP->WriteUsers ($removed_users{"ldap"});
	    if ($error_msg ne "") {
		Ldap->LDAPErrorMessage ("users", $error_msg);
	    }
	    else {
		delete $removed_users{"ldap"};
	    }
	    $nscd_passwd	= 1;
	}
		
	if ($error_msg eq "" && defined ($modified_users{"ldap"})) {
	    $error_msg	= UsersLDAP->WriteUsers ($modified_users{"ldap"});
	    if ($error_msg ne "") {
		Ldap->LDAPErrorMessage ("users", $error_msg);
	    }
	    else {
		$self->UpdateUsersAfterWrite ("ldap");
		delete $modified_users{"ldap"};
	    }
	    $nscd_passwd	= 1;
	}

	if ($error_msg eq "" && defined ($removed_groups{"ldap"})) {
	    $error_msg	= UsersLDAP->WriteGroups ($removed_groups{"ldap"});
	    if ($error_msg ne "") {
		Ldap->LDAPErrorMessage ("groups", $error_msg);
	    }
	    else {
		delete $removed_groups{"ldap"};
	    }
	    $nscd_group		= 1;
	}

	if ($error_msg eq "" && defined ($modified_groups{"ldap"})) {
	    $error_msg	= UsersLDAP->WriteGroups ($modified_groups{"ldap"});
	    if ($error_msg ne "") {
		Ldap->LDAPErrorMessage ("groups", $error_msg);
	    }
	    else {
		$self->UpdateGroupsAfterWrite ("ldap");
		delete $modified_groups{"ldap"};
	    }
	    $nscd_group		= 1;
	}

	if ($error_msg eq "") {
	    $ldap_modified = 0;
	}
	else {
	    return $error_msg;
	}
    }

    # Write groups 
    if ($use_gui) { Progress->NextStage (); }

    my $plugin_error	= "";

    if ($groups_modified) {
	if ($group_not_read) {
	    # error popup (%s is a file name)
            $ret = sprintf (__("%s file was not correctly read so it will not be written."), "$base_directory/group");
	    Report->Error ($ret);
	    return $ret;
	}
	# -------------------------------------- call WriteBefore on plugins
        foreach my $type (keys %modified_groups)  {
	    if ($type eq "ldap") { next; }
	    foreach my $gid (keys %{$modified_groups{$type}}) {
		if ($plugin_error) { last;}
		my $args	= {
	    	    "what"	=> "group",
		    "type"	=> $type,
		    "modified"	=> $modified_groups{$type}{$gid}{"modified"}
		};
		my $result = UsersPlugins->Apply ("WriteBefore", $args,
		    $modified_groups{$type}{$gid});
		$plugin_error	= GetPluginError ($args, $result);
	    }
	}
	# -------------------------------------- write /etc/group
        if ($plugin_error eq "" && ! WriteGroup ()) {
	    # error popup (%s is a file name)
            $ret = sprintf(__("Cannot write %s file."), "$base_directory/group");
	    Report->Error ($ret);
	    return $ret;
        }
	# -------------------------------------- call Write on plugins
        foreach my $type (keys %modified_groups)  {
	    if ($type eq "ldap") { next; }
	    foreach my $gid (keys %{$modified_groups{$type}}) {
		if ($plugin_error) { last;}
		my $args	= {
	    	    "what"	=> "group",
		    "type"	=> $type,
		    "modified"	=> $modified_groups{$type}{$gid}{"modified"}
		};
		my $result = UsersPlugins->Apply ("Write", $args,
		    $modified_groups{$type}{$gid});
		$plugin_error	= GetPluginError ($args, $result);
	    }
	    # unset the 'modified' flags after write
	    $self->UpdateGroupsAfterWrite ("local");
	    $self->UpdateGroupsAfterWrite ("system");
	    delete $modified_groups{"local"};
	    delete $modified_groups{"system"};
	}
	if ($plugin_error) {
	    Report->Error ($plugin_error);
	    return $plugin_error;
	}
	if (!$write_only) {
	    $nscd_group		= 1;
	}
    }

    # Check for deleted users
    if ($use_gui) { Progress->NextStage (); }

    if ($users_modified) {
        if (!DeleteUsers ()) {
       	    # error popup
	    $ret = __("There was an error while removing users.");
	    Report->Error ($ret);
	    return $ret;
	}
    }

    # Write users
    if ($use_gui) { Progress->NextStage (); }

    if ($users_modified) {
	if ($passwd_not_read) {
	    # error popup (%s is a file name)
            $ret = sprintf (__("%s file was not correctly read so it will not be written."), "$base_directory/passwd");
	    Report->Error ($ret);
	    return $ret;
	}
	# -------------------------------------- call WriteBefore on plugins
        foreach my $type (keys %modified_users)  {
	    if ($type eq "ldap") { next; }
	    foreach my $uid (keys %{$modified_users{$type}}) {
		if ($plugin_error) { last;}
		my $args	= {
	    	    "what"	=> "user",
		    "type"	=> $type,
		    "modified"	=> $modified_users{$type}{$uid}{"modified"}
		};
		my $result = UsersPlugins->Apply ("WriteBefore", $args,
		    $modified_users{$type}{$uid});
		$plugin_error	= GetPluginError ($args, $result);
	    }
	}
	# -------------------------------------- write /etc/group
        if ($plugin_error eq "" && !WritePasswd ()) {
	    # error popup (%s is a file name)
            $ret =sprintf(__("Cannot write %s file."), "$base_directory/passwd");
	    Report->Error ($ret);
	    return $ret;
	}
	# -------------------------------------- call Write on plugins
        foreach my $type (keys %modified_users)  {
	    if ($type eq "ldap") { next; }
	    foreach my $uid (keys %{$modified_users{$type}}) {
		if ($plugin_error) { last;}
		my $args	= {
	    	    "what"	=> "user",
		    "type"	=> $type,
		    "modified"	=> $modified_users{$type}{$uid}{"modified"}
		};
		my $result = UsersPlugins->Apply ("Write", $args,
		    $modified_users{$type}{$uid});
		$plugin_error	= GetPluginError ($args, $result);
	    }
	}
	if ($plugin_error) {
	    Report->Error ($plugin_error);
	    return $plugin_error;
	}
	if (!$write_only) {
	    $nscd_passwd	= 1;
	}

	# check for homedir changes
        foreach my $type (keys %modified_users)  {
	    if ($type eq "ldap") {
		next; #homes for LDAP are ruled in WriteLDAP
	    }
	    foreach my $uid (keys %{$modified_users{$type}}) {
	    
		my %user	= %{$modified_users{$type}{$uid}};
		my $home 	= $user{"homedirectory"} || "";
		my $username 	= $user{"uid"} || "";
		my $command 	= "";
		my $user_mod 	= $user{"modified"} || "no";
		my $gid 	= $user{"gidnumber"};
		my $create_home	= $user{"create_home"};
       
		if ($user_mod eq "imported" || $user_mod eq "added") {
		    my $skel	= $useradd_defaults{"skel"};
		    if (bool ($user{"no_skeleton"})) {
			$skel 	= "";
		    }
		    if ((bool ($create_home) || $user_mod eq "imported")
			&& !%{SCR->Read (".target.stat", $home)})
		    {
			UsersRoutines->CreateHome ($skel, $home);
		    }
		    if ($home ne "/var/lib/nobody") {
			UsersRoutines->ChownHome ($uid, $gid, $home);
		    }
		    # call the useradd.local
		    $command = sprintf ("%s %s", $useradd_cmd, $username);
		    y2milestone ("'$command' return value: ", 
			SCR->Execute (".target.bash", $command));
		}
		elsif ($user_mod eq "edited") {
		    my $org_home = $user{"org_user"}{"homedirectory"} || $home;
		    if ($home ne $org_home) {
			# move the home directory
			if (bool ($create_home)) {
			    UsersRoutines->MoveHome ($org_home, $home);
			}
			# chown only when directory was changed (#39417)
			if ($home ne "/var/lib/nobody") {
			    UsersRoutines->ChownHome ($uid, $gid, $home);
			}
		    }
		}
	    }
	}
	# unset the 'modified' flags after write
	$self->UpdateUsersAfterWrite ("local");
	$self->UpdateUsersAfterWrite ("system");
	# not modified after successful write
	delete $modified_users{"local"};
	delete $modified_users{"system"};
    }

    # Write passwords
    if ($use_gui) { Progress->NextStage (); }

    if ($users_modified) {
	if ($shadow_not_read) {
	    # error popup (%s is a file name)
            $ret = sprintf (__("%s file was not correctly read so it will not be written."), "$base_directory/shadow");
	    Report->Error ($ret);
	    return $ret;
 	}
        if (! WriteShadow ()) {
	    # error popup (%s is a file name)
            $ret =sprintf(__("Cannot write %s file."), "$base_directory/shadow");
	    Report->Error ($ret);
	    return $ret;
        }
    }

    # remove the passwd cache for nscd (bug 24748, 41648)
    if (!$write_only) {
	if ($nscd_passwd) {
	    SCR->Execute (".target.bash", "/usr/sbin/nscd -i passwd");
	}
	if ($nscd_group) {
	    SCR->Execute (".target.bash", "/usr/sbin/nscd -i group");
	}
    }

    # call make on NIS server
    if (($users_modified || $groups_modified) && $nis_master) {
        my %out	= %{SCR->Execute (".target.bash_output",
	    "/usr/bin/make -C /var/yp")};
        if (!defined ($out{"exit"}) || $out{"exit"} != 0) {
            y2error ("Cannot make NIS database: ", %out);
        }
    }

    # Write the custom settings
    if ($use_gui) { Progress->NextStage (); }

    if ($customs_modified) {
        if ($self->WriteCustomSets()) {
	    $customs_modified = 0;
	}
    }

    # Write the default login settings
    if ($use_gui) { Progress->NextStage (); }

    if ($defaults_modified) {
        if ($self->WriteLoginDefaults()) {
	    $defaults_modified	= 0;
	}
    }

    if ($security_modified) {
	if ($self->WriteSecurity()) {
	    $security_modified	= 0;
	}
    }

    # mail forward from root
    if (Mode->cont () && $root_mail ne "" &&
	!MailAliases->SetRootAlias ($root_mail)) {
        
	# error popup
        $ret =__("There was an error while setting forwarding for root's mail.");
	Report->Error ($ret);
	return $ret;
    }

    Autologin->Write (Mode->cont () || $write_only);

    # do not show user in first dialog when all has been writen
    if (Mode->cont ()) {
        $use_next_time	= 0;
        undef %saved_user;
        undef %user_in_work;
    }

    $users_modified	= 0;
    $groups_modified	= 0;

    sleep (1);

    return $ret;
}

##-------------------------------------------------------------------------
##----------------- check routines (TODO move outside...) ---------

# "-" means range! -> at the begining or at the end!
# now CHARACTER_CLASS from /etc/login.defs is used
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

    my $self	= shift;
    my $uid	= $_[0];
    my $type	= UsersCache->GetUserType ();
    my $min	= UsersCache->GetMinUID ($type);
    my $max	= UsersCache->GetMaxUID ($type);

    if (!defined $uid) {
	# error popup
	return __("There is no free UID for this type of user.");
    }

    if (("add_user" eq ($user_in_work{"what"} || "")) 	||
	($uid != ($user_in_work{"uidnumber"} || 0))	||
	(defined $user_in_work{"org_uidnumber"} && 
		 $user_in_work{"org_uidnumber"} != $uid)) {

	if (UsersCache->UIDExists ($uid)) {
	    # error popup
	    return __("The user ID entered is already in use.
Select another user ID.");
	}
    }
    my $username	= $user_in_work{"uid"} || "";

    if ($type eq "system" && $username eq "nobody" && $uid == 65534) {
	return "";
    }
    if ($type eq "system" && $uid< UsersCache->GetMinUID("system") && $uid >=0){
	# system id's 0..100 are ok
	return "";
    }

    if ($type eq "ldap" && $uid >=0 && $uid <= $max) {
	# LDAP uid could be from any range (#38556)
	return "";
    }

    if (($type ne "system" && $type ne "local" && ($uid < $min || $uid > $max))
	||
	# allow change of type: "local" <-> "system"
	(($type eq "system" || $type eq "local") &&
	 (
	    ($uid < UsersCache->GetMinUID ("local") &&
	    $uid < UsersCache->GetMinUID ("system")) ||
	    ($uid > UsersCache->GetMaxUID ("local") &&
	     $uid > UsersCache->GetMaxUID ("system"))
	 )
	)) 
    {
	# error popup
	return sprintf (__("The selected user ID is not allowed.
Select a valid integer between %i and %i."), $min, $max);
    }
    return "";
}

##------------------------------------
# check the uid of current user - part 2
BEGIN { $TYPEINFO{CheckUIDUI} = ["function",
    ["map", "string", "string"],
    "integer", ["map", "string", "integer"]];
}
sub CheckUIDUI {

    my $self	= shift;
    my $uid	= $_[0];
    my %ui_map	= %{$_[1]};
    my $type	= UsersCache->GetUserType ();
    my %ret	= ();

    if (($ui_map{"ldap_range"} || 0) != 1) {
	if ($type eq "ldap" &&
	    $uid < UsersCache->GetMinUID ("ldap"))
	{
	    $ret{"question_id"}	= "ldap_range";
	    $ret{"question"}	= sprintf(
# popup question, %i are numbers
__("The selected user ID is not from a range
defined for LDAP users (%i-%i).
Are you sure?"),
		UsersCache->GetMinUID ("ldap"), UsersCache->GetMaxUID ("ldap"));
	    return \%ret;
	}
    }

    if (($ui_map{"local"} || 0) != 1) {
	if ($type eq "system" &&
	    $uid > UsersCache->GetMinUID ("local") &&
	    $uid < UsersCache->GetMaxUID ("local") + 1)
	{
	    $ret{"question_id"}	= "local";
	    # popup question
	    $ret{"question"}	= sprintf(__("The selected user ID is a local ID,
because the ID is greater than %i.
Really change type of user to 'local'?"), UsersCache->GetMinUID ("local"));
	    return \%ret;
	}
    }

    if (($ui_map{"system"} || 0) != 1) {
	if ($type eq "local" &&
	    $uid > UsersCache->GetMinUID ("system") &&
	    $uid < UsersCache->GetMaxUID ("system") + 1)
	{
	    $ret{"question_id"}	= "system";
	    # popup question
	    $ret{"question"}	= sprintf (__("The selected user ID is a system ID,
because the ID is smaller than %i.
Really change type of user to 'system'?"), UsersCache->GetMaxUID ("system") + 1);
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

    my $self		= shift;
    my $username	= $_[0];

    if (!defined $username || $username eq "") {
	# error popup
        return __("You did not enter a user name.
Try again.");
    }

    my $min		= UsersCache->GetMinLoginLength ();
    my $max		= UsersCache->GetMaxLoginLength ();

    if (length ($username) < $min || length ($username) > $max) {

	# error popup
	return sprintf (__("The user name must be between %i and %i characters in length.
Try again."), $min, $max);
    }

    my $filtered = $username;

    # Samba users may need to have '$' at the end of username (#40433)
    if (($user_in_work{"type"} || "") eq "ldap") {
	$filtered =~ s/\$$//g;
    }
    my $grep = SCR->Execute (".target.bash_output", "echo '$filtered' | grep '\^$character_class\$'");
    my $stdout = $grep->{"stdout"} || "";
    $stdout =~ s/\n//g;
    if ($stdout ne $filtered) {
	y2error ("username $username doesn't match to $character_class");
	# error popup
	return __("The user login may contain only
letters, digits, \"-\", \".\", and \"_\"
and must begin with a letter or \"_\".
Try again.");
    }

    if (("add_user" eq ($user_in_work{"what"} || "")) ||
	($username ne ($user_in_work{"uid"} || "")) ||
	(defined $user_in_work{"org_uid"} && 
		 $user_in_work{"org_uid"} ne $username)) {

	if (UsersCache->UsernameExists ($username)) {
	    # error popup
	    return __("There is a conflict between the entered
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

    my $self		= shift;
    my $fullname	= $_[0];

    if (defined $fullname && $fullname =~ m/[:,]/) {
	# error popup
        return __("The full user name cannot contain
\":\" or \",\" characters.
Try again.");
    }
    return "";
}

##------------------------------------
# check 'additional information': part of gecos field without the fullname
BEGIN { $TYPEINFO{CheckGECOS} = ["function", "string", "string"]; }
sub CheckGECOS {

    my $self		= shift;
    my $gecos		= $_[0];

    if (!defined $gecos) {
	return "";
    }
    if ($gecos =~ m/:/) {
       	# error popup
	return __("The \"Additional User Information\" entry cannot
contain a colon (:).  Try again.");
    }
    
    my @gecos_l = split (/,/, $gecos);
    if (@gecos_l > 3 ) {
	# error popup
        return __("The \"Additional User Information\" entry can consist
of up to three sections separated by commas.
Remove the surplus.");
    }
    
    return "";
}

##------------------------------------
# check the password of current user
BEGIN { $TYPEINFO{CheckPassword} = ["function", "string", "string"]; }
sub CheckPassword {

    my $self		= shift;
    my $pw 		= $_[0];
    my $type		= UsersCache->GetUserType ();
    my $min_length 	= $min_pass_length{$type};
    my $max_length 	= $max_pass_length{$type};

    # password for 'disabled' user
    if ($pw eq "!") { # TODO || $pw eq ""
	return "";
    }

    if (($pw || "") eq "") {
	# error popup
	return __("You did not enter a password.
Try again.");
    }

    if (length ($pw) < $min_length) {
	# error popup
        return sprintf (__("The password must have between %i and %i characters.
Try again."), $min_length, $max_length);
    }

    my $filtered = $pw;
    $filtered =~ s/$valid_password_chars//g;

    if ($filtered ne "") {
	# error popup
	return __("The password may only contain the following characters:
0..9, a..z, A..Z, and any of \"#* ,.;:._-+!\$%^&/|\?{[()]}\".
Try again.");
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
	SCR->Read (".target.size", "$cracklib_dictpath.pwd") == -1) {
	$ret = SCR->Execute (".crack", $pw);
    }
    else {
	$ret = SCR->Execute (".crack", $pw, $cracklib_dictpath);
    }
    if (!defined ($ret)) { $ret = ""; }

    return UsersUI->RecodeUTF ($ret);
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
	# popup question
        return __("You have used the user name as a part of the password.
This is not good security practice. Are you sure?");
    }

    # check for lowercase
    my $filtered 	= $pw;
    $filtered 		=~ s/[a-z]//g;
    if ($filtered eq "") {
	# popup question
        return __("You have used only lowercase letters for the password.
This is not good security practice. Are you sure?");
    }

    # check for numbers
    $filtered 		= $pw;
    $filtered 		=~ s/[0-9]//g;
    if ($filtered eq "") {
	# popup question
        return __("You have used only digits for the password.
This is not good security practice. Are you sure?");
    }
    return "";
}

##------------------------------------
# Checks if password is not too long
# @param pw password
sub CheckPasswordMaxLength {

    my $self		= shift;
    my $pw 		= $_[0];
    my $type		= UsersCache->GetUserType ();
    my $max_length 	= $max_pass_length{$type};
    my $ret		= "";

    if (length ($pw) > $max_length) {
	# popup question
        $ret = sprintf (__("The password is too long for the current encryption method.
Truncate it to %s characters?"), $max_length);
    }
    return $ret;
}

##------------------------------------
# check the password of current user -- part 2
BEGIN { $TYPEINFO{CheckPasswordUI} = ["function",
    ["map", "string", "string"],
    "string", "string", ["map", "string", "integer"]];
}
sub CheckPasswordUI {

    my $self		= shift;
    my $username	= $_[0];
    my $pw 		= $_[1];
    my %ui_map		= %{$_[2]};
    my %ret		= ();

    if ($pw eq "") {
	return \%ret;
    }

    if ($use_cracklib && (($ui_map{"crack"} || 0) != 1)) {
	my $error = CrackPassword ($pw);
	if ($error ne "") {
	    $ret{"question_id"}	= "crack";
	    # popup question
	    $ret{"question"}	= sprintf (__("Password is too simple:
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
	my $error = $self->CheckPasswordMaxLength ($pw);
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

    my $self	= shift;
    my $dir 	= $_[0];

    # maybe more directories in path don't exist
    while ($dir ne "" && !%{SCR->Read (".target.stat", $dir)}) {
	$dir = substr ($dir, 0, rindex ($dir, "/"));
    }

    my $tmpfile = $dir."/tmpfile";

    while (SCR->Read (".target.size", $tmpfile) != -1) {
        $tmpfile .= "0";
    }

    my %out = %{SCR->Execute (".target.bash_output", "/bin/touch $tmpfile")};
    if (defined $out{"exit"} && $out{"exit"} == 0) {
        SCR->Execute (".target.bash", "/bin/rm $tmpfile");
        return "";
    }
    return $dir;
}


##------------------------------------
# check the home directory of current user
BEGIN { $TYPEINFO{CheckHome} = ["function", "string", "string"]; }
sub CheckHome {

    my $self		= shift;
    my $home		= $_[0];

    if (!defined $home || $home eq "") {
	return "";
    }

    # /var/lib/nobody could be used for multiple users
    if ($home eq "/var/lib/nobody") {
	return "";
    }

    my $type		= UsersCache->GetUserType ();
    my $first 		= substr ($home, 0, 1);
    my $filtered 	= $home;
    $filtered 		=~ s/$valid_home_chars//g;

    if ($filtered ne "" || $first ne "/" || $home =~ m/\/\./) {
	# error popup
        return __("The home directory may only contain the following characters:
a..zA..Z0..9_-/
Try again.");
    }

    my $modified	= 
	(($user_in_work{"what"} || "") eq "add_user")		||
	($home ne ($user_in_work{"homedirectory"} || "")) 	||
	(defined $user_in_work{"org_homedirectory"} && 
		 $user_in_work{"org_homedirectory"} ne $home);

    if (!$modified) {
	return "";
    }

    # check if directory is writable
    if (!Mode->config () && !Mode->test () &&
	($type ne "ldap" || Ldap->file_server ()))
    {
	my $home_path = substr ($home, 0, rindex ($home, "/"));
        $home_path = $self->IsDirWritable ($home_path);
        if ($home_path ne "") {
	    # error popup
            return sprintf (__("The directory %s is not writable.
Choose another path for the home directory."), $home_path);
	}
    }

    if ($home eq $self->GetDefaultHome ($type)) {
	return "";
    }
    
    if (UsersCache->HomeExists ($home)) {
	# error message
	return __("The home directory is used from another user.
Please try again.");
    }
    return "";
}

##------------------------------------
# check the home directory of current user - part 2
BEGIN { $TYPEINFO{CheckHomeUI} = ["function",
    ["map", "string", "string"],
    "integer", "string", ["map", "string", "integer"]];
}
sub CheckHomeUI {

    my $self		= shift;
    my $uid		= $_[0];
    my $home		= $_[1];
    my %ui_map		= %{$_[2]};
    my $type		= UsersCache->GetUserType ();
    my %ret		= ();
    my $create_home	= $user_in_work{"create_home"};

    if ($home eq "" || !bool ($create_home) || Mode->config()) {
	return \%ret;
    }

    # /var/lib/nobody could be used for multiple users
    if ($home eq "/var/lib/nobody") {
	return \%ret;
    }

    if ($type eq "ldap" && !Ldap->file_server ()) {
	return \%ret;
    }
	
    my %stat 	= %{SCR->Read (".target.stat", $home)};
    
    if ((($ui_map{"not_dir"} || 0) != 1)	&&
	%stat && !($stat{"isdir"} || 0))	{

	$ret{"question_id"}	= "not_dir";
	# yes/no popup: user seleceted something strange as a home directory
	$ret{"question"}	= __("The path for the selected home directory already exists,
but it is not a directory.
Are you sure?");
	return \%ret;
    }

    if ((($ui_map{"chown"} || 0) != 1)		&&
	%stat && ($stat{"isdir"} || 0))	{
        
	$ret{"question_id"}	= "chown";
	# yes/no popup
	$ret{"question"}	= __("The home directory selected already exists.
Use it and change its owner?");

	my $dir_uid	= $stat{"uidnumber"} || 0;
                    
	if ($uid == $dir_uid) { # chown is not needed (#25200)
	    # yes/no popup
	    $ret{"question"}	= __("The home directory selected already exists
and is owned by the currently edited user.
Use this directory?");
	}
	# maybe it is home of some user marked to delete...
	elsif (defined $removed_homes{$home}) {
	    # yes/no popup
	    $ret{"question"}	= sprintf (__("The home directory selected (%s)
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
    "string", ["map", "string", "integer"]];
}
sub CheckShellUI {

    my $self	= shift;
    my $shell	= $_[0];
    my %ui_map	= %{$_[1]};
    my %ret	= ();

    if (($ui_map{"shell"} || 0) != 1 &&
	($user_in_work{"loginshell"} || "") ne $shell ) {

	if (!defined ($all_shells{$shell})) {
	    $ret{"question_id"}	= "shell";
	    # popup question
	    $ret{"question"}	= __("If you select a nonexistent shell, the user may be unable to log in.
Are you sure?");
	}
    }
    return \%ret;
}

##------------------------------------
# check the gid of current group
BEGIN { $TYPEINFO{CheckGID} = ["function", "string", "integer"]; }
sub CheckGID {

    my $self	= shift;
    my $gid	= $_[0];
    my $type	= UsersCache->GetGroupType ();
    my $min 	= UsersCache->GetMinGID ($type);
    my $max	= UsersCache->GetMaxGID ($type);

    if (!defined $gid) {
	# error popup
	return __("There is no free GID for this type of group.");
    }

    if (("add_group" eq ($group_in_work{"what"} || "")) ||
	($gid != ($group_in_work{"gidnumber"} || 0))	||
	(defined $group_in_work{"org_gidnumber"} && 
		 $group_in_work{"org_gidnumber"} != $gid)) {

	if (UsersCache->GIDExists ($gid)) {
	    # error popup
	    return __("The group ID entered is already in use.
Select another group ID.");
	}
    }
    my $groupname	= $group_in_work{"cn"} || "";
    
    if ($type eq "system" &&
	($groupname eq "nobody" && $gid == 65533) ||
	($groupname eq "nogroup" && $gid == 65534)) {
	return "";
    }
    if ($type eq "system" && $gid< UsersCache->GetMinGID("system") && $gid >=0){
	# system id's 0..100 are ok
	return "";
    }

    if ($type eq "ldap" && $gid >=0 && $gid <= $max) {
	# LDAP gid could be from any range (#38556)
	return "";
    }

    if (($type ne "system" && $type ne "local" && ($gid < $min || $gid > $max))
	||
	# allow change of type: "local" <-> "system"
	(($type eq "system" || $type eq "local") &&
	 (
	    ($gid < UsersCache->GetMinGID ("local") &&
	    $gid < UsersCache->GetMinGID ("system")) ||
	    ($gid > UsersCache->GetMaxGID ("local") &&
	     $gid > UsersCache->GetMaxGID ("system"))
	 )
	)) 
    {
	# error popup
	return sprintf (__("The selected group ID is not allowed.
Select a valid integer between %i and %i."), $min, $max);
    }
    return "";
}

##------------------------------------
# check the gid of current group - part 2
BEGIN { $TYPEINFO{CheckGIDUI} = ["function",
    ["map", "string", "string"],
    "integer", ["map", "string", "integer"]];
}
sub CheckGIDUI {

    my $self	= shift;
    my $gid	= $_[0];
    my %ui_map	= %{$_[1]};
    my $type	= UsersCache->GetGroupType ();
    my %ret	= ();

    if (($ui_map{"ldap_range"} || 0) != 1) {
	if ($type eq "ldap" &&
	    $gid < UsersCache->GetMinGID ("ldap"))
	{
	    $ret{"question_id"}	= "ldap_range";
	    $ret{"question"}	= sprintf(
# popup question, %i are numbers
__("The selected group ID is not from a range
defined for LDAP groups (%i-%i).
Are you sure?"),
		UsersCache->GetMinGID ("ldap"), UsersCache->GetMaxGID ("ldap"));
	    return \%ret;
	}
    }

    if (($ui_map{"local"} || 0) != 1) {
	if ($type eq "system" &&
	    $gid > UsersCache->GetMinGID ("local") &&
	    $gid < UsersCache->GetMaxGID ("local"))
	{
	    $ret{"question_id"}	= "local";
	    # popup question
	    $ret{"question"}	= sprintf (__("The selected group ID is a local ID,
because the ID is greater than %i.
Really change type of group to 'local'?"), UsersCache->GetMinGID ("local"));
	    return \%ret;
	}
    }

    if (($ui_map{"system"} || 0) != 1) {
	if ($type eq "local" &&
	    $gid > UsersCache->GetMinGID ("system") &&
	    $gid < UsersCache->GetMaxGID ("system"))
	{
	    $ret{"question_id"}	= "system";
	    # popup question
	    $ret{"question"}	= sprintf(__("The selected group ID is a system ID,
because the ID is smaller than %i.
Really change type of group to 'system'?"), UsersCache->GetMaxGID ("system"));
	    return \%ret;
	}
    }
    return \%ret;
}

##------------------------------------
# check the groupname of current group
BEGIN { $TYPEINFO{CheckGroupname} = ["function", "string", "string"]; }
sub CheckGroupname {

    my $self		= shift;
    my $groupname	= $_[0];

    if (!defined $groupname || $groupname eq "") {
	# error popup
        return __("You did not enter a group name.
Try again.");
    }
    
    my $min	= UsersCache->GetMinGroupnameLength ();
    my $max	= UsersCache->GetMaxGroupnameLength ();

    my $groupname_changed = 
	(("add_group" eq ($group_in_work{"what"} || "")) ||
	($groupname ne ($group_in_work{"cn"} || "")) 	||
	(defined $group_in_work{"org_cn"} && 
		 $group_in_work{"org_cn"} ne $groupname));

    if ($groupname_changed &&
	(length ($groupname) < $min || length ($groupname) > $max)) {

	# error popup
	return sprintf (__("The group name must be between %i and %i characters in length.
Try again."), $min, $max);
    }
	
    my $filtered = $groupname;

    my $grep = SCR->Execute (".target.bash_output", "echo '$filtered' | grep '\^$character_class\$'");
    my $stdout = $grep->{"stdout"} || "";
    $stdout =~ s/\n//g;
    if ($stdout ne $filtered) {
	y2error ("groupname $groupname doesn't match to $character_class");
	# error popup
	return __("The group name may contain only
letters, digits, \"-\", \".\", and \"_\"
and must begin with a letter.
Try again.");
    }
    
    if ($groupname_changed && UsersCache->GroupnameExists ($groupname)) {
	# error popup
	return __("There is a conflict between the entered
group name and an existing group name.
Try another one.");
    }
    return "";
}

##------------------------------------
# check correctness of current user data
# if map is empty, it takes current user map
BEGIN { $TYPEINFO{CheckUser} = ["function", "string", ["map", "string","any"]];}
sub CheckUser {

    my $self	= shift;
    my %user;
    if (!defined $_[0] || ref ($_[0]) ne "HASH" || !%{$_[0]}) {
	%user 	= %user_in_work;
    }
    else {
	%user	= %{$_[0]};
    }

    my $type	= $user{"type"} || "";

    my $error	= $self->CheckUID ($user{"uidnumber"});

    if ($error eq "") {
	$error	= $self->CheckUsername ($user{"uid"});
    }

    if ($error eq "") {
	# do not check pw when it wasn't changed - must be tested directly
	if ($user{"userpassword"} ne "x" ||
	    ($user{"what"} || "") eq "add_user") {
	    $error	= $self->CheckPassword ($user{"userpassword"});
	}
#FIXME user can set 'x' as pasword!
    }
    
    if ($error eq "") {
	$error	= $self->CheckHome ($user{"homedirectory"});
    }

    if ($error eq "" && $type ne "ldap") {
	$error	= $self->CheckFullname ($user{"cn"});
    }

    if ($error eq "" && $type ne "ldap") {
	$error	= $self->CheckGECOS ($user{"addit_data"});
    }

    my $error_map	=
	UsersPlugins->Apply ("Check", {
	    "what" 	=> "user",
	    "type"	=> $type,
	    "modified"	=> $user{"modified"} || "",
	    "plugins"	=> $user{"plugins"}
	 }, \%user);

    if (ref ($error_map) eq "HASH") {
	foreach my $plugin (keys %{$error_map}) {
	    if ($error ne "") { last; }
	    if (defined $error_map->{$plugin} && $error_map->{$plugin} ne ""){
		$error = $error_map->{$plugin};
	    }
	}
    }

    # disable commit
    if ($error ne "") {
	$user_in_work{"check_error"} = $error;
    }
    elsif (defined ($user_in_work{"check_error"})) {
	delete $user_in_work{"check_error"};
    }
    
    return $error;
}


##------------------------------------
# check correctness of current group data
BEGIN { $TYPEINFO{CheckGroup} = ["function", "string", ["map","string","any"]];}
sub CheckGroup {

    my $self	= shift;
    my %group;
    if (!defined $_[0] || ref ($_[0]) ne "HASH" || !%{$_[0]}) {
	%group 	= %group_in_work;
    }
    else {
	%group	= %{$_[0]};
    }


    my $error = $self->CheckGID ($group{"gidnumber"});

    if ($error eq "") {
	if (defined $group{"userpassword"} && ! bool ($group{"encrypted"}) &&
	    $group{"userpassword"} ne "" && $group{"userpassword"} ne "x" &&
	    $group{"userpassword"} ne "!") {
	    $error	= $self->CheckPassword ($group{"userpassword"});
	}
    }

    if ($error eq "") {
	$error = $self->CheckGroupname ($group{"cn"});
    }

    my $error_map	=
	UsersPlugins->Apply ("Check", {
	    "what"	=> "group",
	    "type"	=> $group{"type"} || "",
	    "modified"	=> $group{"modified"} || "",
	    "plugins"	=> $group{"plugins"}
	}, \%group);

    if (ref ($error_map) eq "HASH") {
	foreach my $plugin (keys %{$error_map}) {
	    if ($error ne "") {
		next;
	    }
	    if (defined $error_map->{$plugin} && $error_map->{$plugin} ne ""){
		$error = $error_map->{$plugin};
	    }
	}
    }

    # disable commit
    if ($error ne "") {
	$group_in_work{"check_error"} = $error;
    }
    elsif (defined ($group_in_work{"check_error"})) {
	delete $group_in_work{"check_error"};
    }
    return $error;
}

##------------------------------------
# check if group could be deleted
BEGIN { $TYPEINFO{CheckGroupForDelete} = ["function",
    "string",
    ["map","string","any"]];
}
sub CheckGroupForDelete {

    my $self	= shift;
    my $group;
    if (!defined $_[0] || ref ($_[0]) ne "HASH" || !%{$_[0]}) {
	$group 	= \%group_in_work;
    }
    else {
	$group	= shift;
    }
    my $error	= "";
    my $m_attr  = UsersLDAP->GetMemberAttribute ();

    if (defined $group->{"more_users"} && %{$group->{"more_users"}}) {

	# error message: group cannot be deleted
        $error = __("You cannot delete this group because
there are users that use this group
as their default group.");
    }
    elsif ((defined $group->{"userlist"}   && %{$group->{"userlist"}}) ||
	   (defined $group->{$m_attr}      && %{$group->{$m_attr}})) {
	# error message: group cannot be deleted
        $error = __("You cannot delete this group because
there are users in the group.
Remove these users from the group first.");
    }

    # disable commit
    if ($error ne "") {
	$group_in_work{"check_error"} = $error;
    }
    elsif (defined ($group_in_work{"check_error"})) {
	delete $group_in_work{"check_error"};
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

    my $self	= shift;

    if ($encryption_method ne $_[0]) {
	$encryption_method 		= $_[0];
	$security_modified 		= 1;
	my %max_lengths			= %{Security->PasswordMaxLengths ()};
	if (defined $max_lengths{$encryption_method}) {
	    $max_pass_length{"local"}	= $max_lengths{$encryption_method};
	    $max_pass_length{"system"}	= $max_pass_length{"local"};
	}
    }
}

##------------------------------------
# hash user password for LDAP users
# (code provided by rhafer)
sub _hashPassword {

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

    my $self	= shift;
    my $pw	= $_[0];
    my $type	= $_[1];
    my $method	= lc ($encryption_method);
    
    if (!defined $pw || $pw eq "") {
	return $pw;
    }
    if (Mode->test ()) {
	return "crypted_".$pw;
    }

    if ($type eq "ldap") {
	$method = lc (UsersLDAP->GetEncryption ());
	if ($method eq "clear") {
	    return $pw;
	}
	return _hashPassword ($method, $pw);
    }
    # TODO crypt using some perl function...
    return UsersUI->HashPassword ($method, $pw);
}


##------------------------------------
BEGIN { $TYPEINFO{SetRootPassword} = ["function", "void", "string"];}
sub SetRootPassword {

    my $self		= shift;
    $root_password 	= $_[0];
}

##------------------------------------
# Writes password of superuser
# This is called during install
# @return true on success
BEGIN { $TYPEINFO{WriteRootPassword} = ["function", "boolean"];}
sub WriteRootPassword {

    my $self		= shift;
    # Crypt the root password according to method defined in encryption_method
    my $crypted		= $self->CryptPassword ($root_password, "system");
    return SCR->Write (".target.passwd.root", $crypted);
}

##------------------------------------
BEGIN { $TYPEINFO{GetRootPassword} = ["function", "string"];}
sub GetRootPassword {
    return $root_password;
}

##-------------------------------------------------------------------------
## -------------------------------------------- nis related routines 
##------- TODO move to some 'include' file! -------------------------------


##------------------------------------
# Check whether host is NIS master
BEGIN { $TYPEINFO{ReadNISMaster} = ["function", "boolean"];}
sub ReadNISMaster {
    if (SCR->Read (".target.size", "/usr/lib/yp/yphelper") != -1) {
        return 0;
    }
    return (SCR->Execute (".target.bash", "/usr/lib/yp/yphelper --domainname `domainname` --is-master passwd.byname > /dev/null 2>&1") == 0);
}

##------------------------------------
# Checks if set of NIS users is available
BEGIN { $TYPEINFO{ReadNISAvailable} = ["function", "boolean"];}
sub ReadNISAvailable {

    my $passwd_source = SCR->Read (".etc.nsswitch_conf.passwd");
    if (defined $passwd_source) {
	foreach my $source (split (/ /, $passwd_source)) {

	    if ($source eq "nis" || $source eq "compat") {
		return (Service->Status ("ypbind") == 0);
	    }
	}
    }
    return 0;
}
##-------------------------------------------------------------------------
##------------------------ import/export routines -------------------------
##-------------------------------------------------------------------------

##------------------------------------
# Helper function, which corects the userlist entry of each group.
# During autoinstallation, system groups are loaded from the disk,
# and the userlists of these groups can contain the local users,
# which we don not want to Import. So they are removed here.
# @param disk_groups the groups loaded from local disk
sub RemoveDiskUsersFromGroups {

    my $disk_groups	= $_[0];
    foreach my $gid (keys %{$disk_groups}) {
	my $group	= $disk_groups->{$gid};
	
	foreach my $user (keys %{$group->{"userlist"}}) {
	    if (!defined ($users_by_name{"local"}{$user}) &&
		!defined ($users_by_name{"system"}{$user}))
	    {
		delete $disk_groups->{$gid}{"userlist"}{$user};
	    }
	}
	foreach my $user (keys %{$group->{"more_users"}}) {
	    if (!defined ($users_by_name{"local"}{$user}) &&
		!defined ($users_by_name{"system"}{$user}))
	    {
		delete $disk_groups->{$gid}{"more_users"}{$user};
	    }
	}
    }
}

##------------------------------------
# Converts autoyast's user's map for users module usage
# @param user map with user data provided by users_auto client
# @return map with user data as defined in Users module
BEGIN { $TYPEINFO{ImportUser} = ["function",
    [ "map", "string", "any" ],
    [ "map", "string", "any" ]];
}
sub ImportUser {

    my $self	= shift;
    my $user	= $_[0];
    my %ret	= ();

    my $forename	= $user->{"forename"} 	|| "";
    my $surname 	= $user->{"surname"}	|| "";
    my $cn		= $user->{"cn"} || $user->{"fullname"} || "";
    my $username 	= $user->{"username"};# Import could use old kay names

    if (!defined ($username)) {
	$username	= $user->{"uid"}	|| "";
    }
    y2debug("Username=$username");

    my $uid		= $user->{"uidnumber"};
    if (!defined $uid) {
	$uid		= $user->{"uid"};
	if (!defined $uid) {
	    $uid 		= -1;
	}
    }
    my $gid		= $user->{"gidnumber"};
    if (!defined $gid) {
	$gid		= $user->{"gid"};
	if (!defined $gid) {
	    $gid 		= -1;
	}
    }

    if ($cn eq "") {
	if ($forename ne "") {
	    if ($surname ne "") { $cn = "$forename $surname"; }
	    else { $cn = $forename; }
	}
	else { $cn = $surname; }
    }

    my $type	= "local";
    if ($uid != -1 &&
	($uid < UsersCache->GetMaxUID ("system") || $username eq "nobody")) {
        $type = "system";
    }

    # if empty, set to default, might be changed later..
    my %user_shadow	= %{$self->GetDefaultShadow ($type)};
    if (defined $user->{"password_settings"}) {
	%user_shadow	= %{$user->{"password_settings"}};
    }

    my $encrypted	= $user->{"encrypted"};
    if (defined $encrypted && ref ($encrypted) ne "YaST::YCP::Boolean") {
	$encrypted	= YaST::YCP::Boolean ($encrypted);
    }
    my $pass		= $user->{"user_password"}	|| "x";
    if ((!defined $encrypted || !bool ($encrypted)) &&
	$pass ne "x" && !Mode->config ())
    {
	$pass 		= $self->CryptPassword ($pass, $type);
	$encrypted	= YaST::YCP::Boolean (1);
    }
    my $home	= $self->GetDefaultHome($type).$username;

    my %grouplist	= ();
    if (defined $user->{"grouplist"}) {
	if (ref ($user->{"grouplist"}) eq "HASH") {
	    %grouplist	= %{$user->{"grouplist"}};
	}
	else {
	    foreach my $g (split (/,/, $user->{"grouplist"})) {
		$grouplist{$g}	= 1;
	    }
	}
    }

    if ($uid == -1) {
	# check for existence of this user (and change it with given values)
	my %existing 	= %{$self->GetUserByName ($username, "")};
	if (%existing) {
	
	    y2milestone("Existing user:", $existing{"uid"} || "");
	    %user_in_work	= %existing;
	    $type		= $existing{"type"} || "system";

	    if (!defined $user->{"password_settings"}) {
		LoadShadow ();
		%user_shadow	= %{$self->CreateShadowMap (\%user_in_work)};
	    }
	    my $finalpw 	= "";
	    if ($pass ne "x") {
		$finalpw 	= $pass;
	    }
	    else {
		$finalpw 	= $existing{"userpassword"} || "x";
	    }

	    if (!defined $user->{"forename"} && !defined $user->{"surname"} &&
		$cn eq "") {
		$cn		= $existing{"cn"} || "";
	    }
	    if ($gid == -1) {
		$gid		= $existing{"gidnumber"};
	    }
	    %ret	= (
		"userpassword"	=> $finalpw,
		"grouplist"	=> \%grouplist,
		"uid"		=> $username,
		"encrypted"	=> $encrypted,
		"cn"		=> $cn,
		"uidnumber"	=> $existing{"uidnumber"},
		"loginshell"	=> $user->{"shell"} || $user->{"loginshell"} || $existing{"loginshell"} || $self->GetDefaultShell ($type),

		"gidnumber"	=> $gid,
		"homedirectory"	=> $user->{"homedirectory"} || $user->{"home"} || $existing{"homedirectory"} || $home,
		"type"		=> $type,
		"modified"	=> "imported"
	    );
	}
    }
    if ($gid == -1) {
	$gid = $self->GetDefaultGID ($type);
    }

    if (!%ret) {
	%ret	= (
	"uid"		=> $username,
	"encrypted"	=> $encrypted,
	"userpassword"	=> $pass,
	"cn"		=> $cn,
	"uidnumber"	=> $uid,
	"gidnumber"	=> $gid,
	"loginshell"	=> $user->{"shell"} || $user->{"loginshell"} || $self->GetDefaultShell ($type),

	"grouplist"	=> \%grouplist,
	"homedirectory"	=> $user->{"homedirectory"} || $user->{"home"} || $home,
	"type"		=> $type,
	"modified"	=> "imported"
	);
    }
    my %translated = (
	"inact"		=> "shadowinactive",
	"expire"	=> "shadowexpire",
	"warn"		=> "shadowwarning",
	"min"		=> "shadowmin",
        "max"		=> "shadowmax",
        "flag"		=> "shadowflag",
	"last_change"	=> "shadowlastchange",
	"password"	=> "userpassword",
    );
    foreach my $key (keys %user_shadow) {
	my $new_key	= $translated{$key} || $key;
	if ($key eq "userpassword") { next; }
	$ret{$new_key}	= $user_shadow{$key};
    }
    if (!defined $ret{"shadowlastchange"} ||
	$ret{"shadowlastchange"} eq "") {
	$ret{"shadowlastchange"}	= LastChangeIsNow ();
    }
    return \%ret;
}

##------------------------------------
# Converts autoyast's group's map for groups module usage
# @param group map with group data provided by users_auto client
# @return map with group data as defined in Users module
sub ImportGroup {

    my $self		= shift;
    my %group		= %{$_[0]};
    my $type 		= "local";
    my $groupname 	= $group{"groupname"};# Import could use old kay names

    if (!defined $groupname) {
	$groupname	= $group{"cn"}	|| "";
    }

    my $gid		= $group{"gidnumber"};
    if (!defined $gid) {
	$gid		= $group{"gid"};
	if (!defined $gid) {
	    $gid 	= -1;
	}
    }
    if ($gid == -1) {
	# check for existence of this group (and change it with given values)
	my $existing 	= $self->GetGroupByName ($groupname, "");
	if (ref ($existing) eq "HASH" && %{$existing}) {
	    $gid	= $existing->{"gidnumber"};
	}
    }
    if (($gid <= UsersCache->GetMaxGID ("system") ||
        $groupname eq "nobody" || $groupname eq "nogroup") &&
        $groupname ne "users")
    {
        $type 		= "system";
    }
    my %userlist	= ();
    if (defined $group{"userlist"}) {
	if (ref ($group{"userlist"}) eq "HASH") {
	    %userlist	= %{$group{"userlist"}};
	}
	else {
	    foreach my $u (split (/,/, $group{"userlist"})) {
		$userlist{$u}	= 1;
	    }
	}
    }
    my %ret		= (
        "userpassword"	=> $group{"group_password"} || "x",
        "cn"		=> $groupname,
        "gidnumber"	=> $gid,
        "userlist"	=> \%userlist,
        "modified"	=> "imported",
        "type"		=> $type
    );
    return \%ret;
}

##------------------------------------
# Get all the user configuration from the list of maps.
# Is called users_auto (preparing autoinstallation data).
# @param settings	A map with keys: "users", "groups", "user_defaults"
# and values to be added to the system.
# @return true
BEGIN { $TYPEINFO{Import} = ["function",
    "boolean",
    ["map", "string", "any"]];
}
sub Import {
    
    my $self		= shift;
    my %settings	= %{$_[0]};

    y2debug ("importing: ", %settings);

    if (!defined $settings{"user_defaults"} || !%{$settings{"user_defaults"}}) {
        $self->ReadLoginDefaults ();
    }
    else {
        %useradd_defaults 	= %{$settings{"user_defaults"}};
        $defaults_modified	= 1;
    }

    $self->ReadSystemDefaults();

    $tmpdir	= SCR->Read (".target.tmpdir");

    my $error_msg = $self->ReadLocal ();
    if ($error_msg) {
	return 0; #TODO do not return, just read less
    }

    $shadow{"local"}		= {};
    $users{"local"}		= {};
    $users_by_name{"local"}	= {};

    if (defined $settings{"users"} && @{$settings{"users"}} > 0) {
        $users_modified		= 1;
    }
    if (defined $settings{"groups"} && @{$settings{"groups"}} > 0) {
        $groups_modified	= 1;
    }

    # Problem: what if UID is not provided?
    my @without_uid		= ();

    if (defined $settings{"users"} && @{$settings{"users"}} > 0) {

	foreach my $imp_user (@{$settings{"users"}}) {
	    ResetCurrentUser ();
	    my %user		= %{$self->ImportUser ($imp_user)};
	    my $type		= $user{"type"} || "local";
	    my $username 	= $user{"uid"} || "";
	    my $uid 		= $user{"uidnumber"};
	    if (!defined $uid || $uid == -1) {
		delete $user{"uidnumber"};
		push @without_uid, \%user;
	    }
	    else {
		$users{$type}{$uid}		= \%user;
		$users_by_name{$type}{$username}= $uid;
		$shadow{$type}{$username} = $self->CreateShadowMap (\%user);
		$modified_users{$type}{$uid}	= \%user;
	    }
	}

	foreach my $user (@without_uid) {
	    y2milestone ("no UID for this user:", $user->{"uid"} || "");
	    $self->ResetCurrentUser ();
	    $self->AddUser ($user);
	    if ($self->CheckUser ($self->GetCurrentUser()) eq "") {
		$self->CommitUser ();
	    }
	}
    }

    # group users should be "local"
    if (defined ($groups{"system"}{100}) &&
	$groups{"system"}{100}{"cn"} eq "users") {
	delete $groups{"system"}{100};
    }
    if (defined ($groups{"system"}{500}) &&
	$groups{"system"}{500}{"cn"} eq "users") {
	delete $groups{"system"}{500};
    }

    # we're not interested in local userlists...
    RemoveDiskUsersFromGroups ($groups{"system"});
    $groups{"local"}		= {};
    $groups_by_name{"local"}	= {};

    if (defined $settings{"groups"} && @{$settings{"groups"}} > 0) {

	foreach my $imp_group (@{$settings{"groups"}}) {
	    my %group	= %{$self->ImportGroup ($imp_group)};
	    my $gid 	= $group{"gidnumber"};
	    if (!defined $gid || $gid == -1) {
		next;
	    }
	    my $type				= $group{"type"} || "local";
	    my $groupname 			= $group{"cn"} || "";
	    $groups{$type}{$gid}		= \%group;
	    $groups_by_name{$type}{$groupname}	= $gid;
	    $modified_groups{$type}{$gid}	= \%group;
	}
    }

    my %group_u = %{$self->GetGroupByName ("users", "local")};
    if (!%group_u) {
        # group users must be created
	my $gid		= $self->GetDefaultGID ("local");
        %group_u	= (
             "gidnumber"		=> $gid,
	     "cn"			=> "users",
	     "userpassword"		=> "x",
	     "userlist"			=> {},
	     "type"			=> "local"
	);
        $groups{"local"}{$gid}		= \%group_u;
        $groups_by_name{"local"}{"users"}	= $gid;
    }

    @available_usersets		= ( "local", "system", "custom" );
    @available_groupsets	= ( "local", "system", "custom" );

    $self->ReadAllShells ();

    # create more_users (for groups), grouplist and groupname (for users)
    foreach my $type ("system", "local") {

	if (!defined $users{$type} ||
	    (!$users_modified && !$groups_modified)) {
	    next;
	}

        foreach my $uid (keys %{$users{$type}}) {

	    my $user		= $users{$type}{$uid};
            my $username 	= $user->{"uid"}	|| "";
            my $gid 		= $user->{"gidnumber"};
	    if (!defined $gid) {
		$gid		= $self->GetDefaultGID($type);
	    }
            $users{$type}{$uid}{"grouplist"} = FindGroupsBelongUser ($user);

            # hack: change of default group's gid
	    # (e.g. user 'games' has gid 100, but there is only group 500 now!)
            my %group 		= %{$self->GetGroup ($gid, "")};
	    if (!%group) {
		if ($gid == 100) {
		    $gid 	= 500;
		}
		elsif ($gid == 500) {
		    $gid	= 100;
		}
		# one more chance...
		%group		= %{$self->GetGroup ($gid, "")};
		# adapt user's gid to new one:
		if (%group) {
		    $users{$type}{$uid}{"gidnumber"}	= $gid;
		}
	    }
	    if (defined $group{"cn"}) {
		$users{$type}{$uid}{"groupname"}	= $group{"cn"};
	    }

            # update the group's more_users
            if (%group && !defined ($group{"more_users"}{$username})) {
		my $gtype	= $group{"type"} || $type;
                $groups{$gtype}{$gid}{"more_users"}{$username}	= 1;
            }
        }
    }

    # initialize UsersCache: 1. system users and groups:
    UsersCache->ReadUsers ("system");
    UsersCache->ReadGroups ("system");

    UsersCache->BuildUserItemList ("system", $users{"system"});
    UsersCache->BuildGroupItemList ("system", $groups{"system"});

    # 2. and local ones (probably empty or imported)
    UsersCache->BuildUserLists ("local", $users{"local"});
    UsersCache->BuildUserItemList ("local", $users{"local"});

    UsersCache->BuildGroupLists ("local", $groups{"local"});
    UsersCache->BuildGroupItemList ("local", $groups{"local"});

    UsersCache->SetCurrentUsers (\@user_custom_sets);
    UsersCache->SetCurrentGroups (\@group_custom_sets);

    return 1;
}

##------------------------------------
# Converts user's map for autoyast usage
# @param user map with user data as defined in Users module
# @return map with user data in format used by autoyast
BEGIN { $TYPEINFO{ExportUser} = ["function",
    [ "map", "string", "any" ],
    [ "map", "string", "any" ]];
}
sub ExportUser {

    my $self		= shift;
    my $user		= $_[0];
    my $type		= $user->{"type"} || "local";
    my $username 	= $user->{"uid"} || "";
    my %user_shadow	= ();
    my %translated = (
	"shadowinactive"	=> "inact",
	"shadowexpire"		=> "expire",
	"shadowwarning"		=> "warn",
	"shadowmin"		=> "min",
        "shadowmax"		=> "max",
        "shadowflag"		=> "flag",
	"shadowlastchange"	=> "last_change",
	"userpassword"		=> "password"
    );
    my %shadow_map	= %{$self->CreateShadowMap ($user)};
    my %org_user	= ();
    if (defined $user->{"org_user"}) {
	%org_user	= %{$user->{"org_user"}};
    }
    foreach my $key (keys %shadow_map) {
	my $new_key		= $translated{$key} || $key;
	# actual shadowlastchange must be created in Import
	if ($key eq "userpassword" || $key eq "shadowlastchange" ||
	    (defined $org_user{$key} && $shadow_map{$key} eq $org_user{$key} &&
	     ($user->{"modified"} || "") ne "imported"))
	{
	    # do not export passwod twice
	    # do not export unchanged shadow values
	    next;
	}
	if (defined $shadow_map{$key}) {
	    $user_shadow{$new_key}	= $shadow_map{$key};
	}
    }

    # remove the keys, whose values were not changed
    my %exported_user	= %{$user};
    # export all when username was changed!
    if (%org_user && $user->{"uid"} eq $org_user{"uid"} &&
	($user->{"modified"} || "") ne "imported") {
	foreach my $key (keys %org_user) {
	    if (defined $user->{$key} && $user->{$key} eq $org_user{$key}) {
		delete $exported_user{$key};
	    }
	}
    }
    my %ret		= (
	"username"	=> $user->{"uid"}
    );

    # change the key names
    my %keys_to_export 	= (
        "userpassword"	=> "user_password",
	"cn"		=> "fullname",
        "loginshell"	=> "shell",
        "uidnumber"	=> "uid",
        "gidnumber"	=> "gid",
        "homedirectory"	=> "home"
    );
    foreach my $key (keys %exported_user) {
	if (defined $keys_to_export{$key}) {
	    my $new_key		= $keys_to_export{$key};
	    $ret{$new_key}	= $exported_user{$key};
	}
    }
    
    my $encrypted	= bool ($exported_user{"encrypted"});
    if (!defined $encrypted) {
	$encrypted	= 1;
    }
    if (defined $ret{"user_password"}) {
	$ret{"encrypted"}		= YaST::YCP::Boolean ($encrypted);
    }
    if (%user_shadow) {
	$ret{"password_settings"} 	= \%user_shadow;
    }
    return \%ret;
}

##------------------------------------
# Converts group's map for autoyast usage
# @param group map with group data as defined in Users module
# @return map with group data in format used by autoyast
sub ExportGroup {

    my $self		= shift;
    my $group		= $_[0];
    my $userlist	= "";
    if (defined $group->{"userlist"}) {
	$userlist	= join (",", keys %{$group->{"userlist"}});
    }
    my %ret		= (
        "groupname"		=> $group->{"cn"}		|| "",
        "userlist"		=> $userlist
    );
    if (defined $group->{"org_group"} &&
	(defined $group->{"org_group"}{"gidnumber"} &&
	$group->{"gidnumber"} ne $group->{"org_group"}{"gidnumber"})
	||
	(defined $group->{"org_group"}{"cn"} &&
	$group->{"cn"} ne $group->{"org_group"}{"cn"}))
	{

	$ret{"gid"}		= $group->{"gidnumber"};
    }
    if (($group->{"userpassword"} || "x") ne "x") {
	$ret{"group_password"}	= $group->{"userpassword"};
    }

    return \%ret;
}

##------------------------------------
# Dump the users settings to list of maps
# (For use by autoinstallation.)
# @return map Dumped settings (later acceptable by Import ())
BEGIN { $TYPEINFO{Export} = ["function",
    ["map", "string", "any"]];
}
sub Export {

    my $self		= shift;
    my @exported_users	= ();
    # local users when modified
    if (defined $users{"local"}) {
	foreach my $user (values %{$users{"local"}}) {
	    if ($export_all || defined $user->{"modified"}) {
		push @exported_users, $self->ExportUser ($user);
	    }
	}
    }

    # modified system users:
    if (defined $users{"system"}) {
	foreach my $user (values %{$users{"system"}}) {
            if ($export_all || defined $user->{"modified"}) {
	        push @exported_users, $self->ExportUser ($user);
	    }
	}
    }

    my @exported_groups	= ();
    # modified local system groups:
    if (defined $groups{"local"}) {
	foreach my $group (values %{$groups{"local"}}) {
	    if ($export_all || defined $group->{"modified"}) {
		push @exported_groups, $self->ExportGroup ($group);
	    }
	}
    }

    # modified system groups:
    if (defined $groups{"system"}) {
	foreach my $group (values %{$groups{"system"}}) {
            if ($export_all || defined $group->{"modified"}) {
	        push @exported_groups, $self->ExportGroup ($group);
	    }
	}
    }

    return {
        "users"		=> \@exported_users,
        "groups"	=> \@exported_groups,
        "user_defaults"	=> \%useradd_defaults
    };
}

##------------------------------------
# Summary for autoinstalation
# @return summary of the current configuration
BEGIN { $TYPEINFO{Summary} = ["function", "string"];}
sub Summary {
    
    my $self	= shift;
    my $ret 	= "";

    # summary label
    $ret = __("<h3>Users</h3>");
    foreach my $type ("local", "system") {
	if (!defined $users{$type}) { next; }
	while (my ($uid, $user) = each %{$users{$type}}) {
            if (defined $user->{"modified"}) {
                $ret .= sprintf (" $uid %s %s<br>", $user->{"uid"} || "", $user->{"cn"} || "");
	    }
	}
    }
    # summary label
    $ret .= __("<h3>Groups</h3>");
    foreach my $type ("local", "system") {
	if (!defined $groups{$type}) { next; }
	while (my ($gid, $group) = each %{$groups{$type}}) {
            if (defined $group->{"modified"}) {
                $ret .= sprintf (" $gid %s<br>", $group->{"cn"} || "");
	    }
	}
    }
    return $ret;
}

##-------------------------------------------------------------------------
##-------------------------------------------------------------------------

BEGIN { $TYPEINFO{SetExportAll} = ["function", "void", "boolean"];}
sub SetExportAll {
    my $self	= shift;
    $export_all	= $_[0];
}


BEGIN { $TYPEINFO{SetWriteOnly} = ["function", "void", "boolean"];}
sub SetWriteOnly {
    my $self	= shift;
    $write_only = $_[0];
}

BEGIN { $TYPEINFO{SetReadLocal} = ["function", "void", "boolean"];}
sub SetReadLocal {
    my $self	= shift;
    $read_local	= $_[0];
}


# return state of $use_gui
BEGIN { $TYPEINFO{GetGUI} = ["function", "boolean"];}
sub GetGUI {
    return $use_gui;
}

BEGIN { $TYPEINFO{SetGUI} = ["function", "void", "boolean"];}
sub SetGUI {
    my $self	= shift;
    $use_gui 	= $_[0];
    UsersCache->SetGUI ($use_gui);
    UsersLDAP->SetGUI ($use_gui);
    Report->DisplayErrors ($use_gui, 0);
}

# ---------------- modification of + lines in /etc/passwd
BEGIN { $TYPEINFO{AddPlusPasswd} = ["function", "void", "string"];}
sub AddPlusPasswd {
    my $self		= shift;
    my $plusline	= shift;

    if (!contains (\@pluses_passwd, $plusline)) {
	push @pluses_passwd, $plusline;
	if (SCR->Write (".passwd.passwd.pluslines", \@pluses_passwd)) {
	    $users_modified 	= 1;
	}
    }
}

BEGIN { $TYPEINFO{AddPlusShadow} = ["function", "void", "string"];}
sub AddPlusShadow {
    my $self		= shift;
    my $plusline	= shift;

    if (!contains (\@pluses_shadow, $plusline)) {
	push @pluses_shadow, $plusline;
	if (SCR->Write (".passwd.shadow.pluslines", \@pluses_shadow)) {
	    $users_modified 	= 1;
	}
    }
}

BEGIN { $TYPEINFO{AddPlusGroup} = ["function", "void", "string"];}
sub AddPlusGroup {
    my $self		= shift;
    my $plusline	= shift;

    if (!contains (\@pluses_group, $plusline)) {
	push @pluses_group, $plusline;
	if (SCR->Write (".passwd.group.pluslines", \@pluses_group)) {
	    $groups_modified 	= 1;
	}
    }
}

1
# EOF
