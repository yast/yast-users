#! /usr/bin/perl -w
# ------------------------------------------------------------------------------
# Copyright (c) 2006-2012 Novell, Inc. All Rights Reserved.
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------
#

#
# File:			modules/Users.pm
# Package:		Configuration of users and groups
# Summary:		I/O routines + main data structures
#
# $Id$
#

package Users;

use strict;

use YaST::YCP qw(:LOGGING sformat);
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

# what should be imported during installation (F120103)
my %installation_import		= (
    "users"		=> (),
    "groups"		=> (),
);

# Write only, keep progress turned off
my $write_only			= 0; 

# Export all users and groups (for autoinstallation purposes)
# (used also for indication of cloning: #94340
my $export_all			= 0; 

# Where the user/group/password data are stored (can be different on NIS server)
my $base_directory		= "/etc";

my $root_password		= "";

my %default_groupname		= ();

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

my %users_by_uidnumber		= (
    "system"		=> {},
    "local"		=> {},
);
my %groups_by_gidnumber		= (
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
    "groups"		=> "",
    "umask"		=> "022"
);

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
my $sysconfig_ldap_modified     = 0;
my $ldap_settings_read          = 0;

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
my $groupadd_cmd 		= "";

my $pass_warn_age		= "7";
my $pass_min_days		= "0";
my $pass_max_days		= "99999";

# password encryption method
my $encryption_method		= "des";
my $group_encryption_method	= "des";

# User/group names must match the following regex expression. (/etc/login.defs)
my $character_class 		= "[[:alpha:]_][[:alnum:]_.-]*[[:alnum:]_.\$-]\\?";

# the +/- entries in config files:
my @pluses_passwd		= ();
my @pluses_group		= ();
my @pluses_shadow 		= ();

# starting dialog for installation mode
my $start_dialog		= "summary";
my $use_next_time		= 0;

# if user should be warned when using uppercase letters in login name
my $not_ask_uppercase		= 0;

# if user should be warned when using blowfish/md5 encryption on NIS server
my $not_ask_nisserver_notdes	= 0;

# which sets of users are we working with:
my @current_users		= ();
my @current_groups 		= ();

# mail alias for root (helper; see root_aliases for current values)
my $root_mail			= "";

# hash with user names that should get root's mail
my %root_aliases		= ();
my %root_aliases_orig		= ();

# users sets in "Custom" selection:
my @user_custom_sets		= ("local");
my @group_custom_sets		= ("local");

# list of available plugin modules for local and system users (groups)
my @local_plugins		= ();

# if system settings already read by ReadSystemDefaults
my $system_defaults_read	= 0;

# if new value of root password should be written at the end
my $save_root_password		= 0;


##------------------------------------
##------------------- global imports

YaST::YCP::Import ("SCR");
YaST::YCP::Import ("Autologin");
YaST::YCP::Import ("Call");
YaST::YCP::Import ("Directory");
YaST::YCP::Import ("FileUtils");
YaST::YCP::Import ("Ldap");
YaST::YCP::Import ("Linuxrc");
YaST::YCP::Import ("Installation");
YaST::YCP::Import ("MailAliases");
YaST::YCP::Import ("Message");
YaST::YCP::Import ("Mode");
YaST::YCP::Import ("Package");
YaST::YCP::Import ("Popup");
YaST::YCP::Import ("ProductFeatures");
YaST::YCP::Import ("Progress");
YaST::YCP::Import ("Report");
YaST::YCP::Import ("Security");
YaST::YCP::Import ("Service");
YaST::YCP::Import ("Stage");
YaST::YCP::Import ("String");
YaST::YCP::Import ("Syslog");
YaST::YCP::Import ("UsersCache");
YaST::YCP::Import ("UsersLDAP");
YaST::YCP::Import ("UsersPasswd");
YaST::YCP::Import ("UsersPlugins");
YaST::YCP::Import ("UsersRoutines");
YaST::YCP::Import ("UsersSimple");
YaST::YCP::Import ("UsersUI");
YaST::YCP::Import ("SSHAuthorizedKeys");

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

# if root password value should be explicitely written
BEGIN { $TYPEINFO{SaveRootPassword} = ["function", "void", "boolean"]; }
sub SaveRootPassword {
    my $self		= shift;
    $save_root_password	= bool ($_[0]);
}

BEGIN { $TYPEINFO{NISAvailable} = ["function", "boolean"]; }
sub NISAvailable {
    return $nis_available;
}

BEGIN { $TYPEINFO{NISMaster} = ["function", "boolean"]; }
sub NISMaster {
    return $nis_master;
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

# OBSOLETE 
BEGIN { $TYPEINFO{GetRootMail} = ["function", "string"]; }
sub GetRootMail {
    y2warning ("this function is obsolete, use GetRootAliases instead");
    return join (",", keys %root_aliases);
}

# OBSOLETE 
BEGIN { $TYPEINFO{SetRootMail} = ["function", "void", "string"]; }
sub SetRootMail {
    my $self		= shift;
    my $root_a 		= shift;
    y2warning ("this function is obsolete, use RemoveRootAlias/AddRootAlias instead");
    foreach my $alias (split (/,/, $root_a)) {
	$alias	=~ s/[ \t]//g;
	$root_aliases{$alias}	= 1;
    }
}

# return the map with root aliases
BEGIN { $TYPEINFO{GetRootAliases} = ["function", ["map", "string", "integer"]];}
sub GetRootAliases {
    return \%root_aliases;
}

# remove the given user from root's aliases set
BEGIN { $TYPEINFO{RemoveRootAlias} = ["function", "void", "string"]; }
sub RemoveRootAlias {
    my $self		= shift;
    my $u		= shift;
    delete $root_aliases{$u} if (defined $root_aliases{$u});
}

# add the given user to root's aliases set
BEGIN { $TYPEINFO{AddRootAlias} = ["function", "void", "string"]; }
sub AddRootAlias {
    my $self		= shift;
    my $u		= shift;
    $root_aliases{$u}	= 1;
}

# return the value of base directory
BEGIN { $TYPEINFO{GetBaseDirectory} = ["function", "string"]; }
sub GetBaseDirectory {
    return $base_directory;
}

# set the new the value of base directory
BEGIN { $TYPEINFO{SetBaseDirectory} = ["function", "void", "string"]; }
sub SetBaseDirectory {
    my $self		= shift;
    my $dir		= shift;
    $base_directory	= $dir if (defined $dir);
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

# return the global $umask value
BEGIN { $TYPEINFO{GetUmask} = ["function", "string"]; }
sub GetUmask {
    my $umask	= $useradd_defaults{"umask"};
    $umask 	= "022" unless $umask;
    return $umask;
}

##------------------------------------
# current users = name of user sets currently shown in table ("local", "nis")
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

# set the list of users to be imported during installation
BEGIN { $TYPEINFO{SetUsersForImport} = ["function", "void", ["list","any"]];}
sub SetUsersForImport {
    my $self		= shift;
    my $to_import	= shift;
    return if (! defined ($to_import) || ref ($to_import) ne "ARRAY");
    my @u	= @$to_import;
    $installation_import{"users"}	= \@u;
}

# return the data of users to be imported during installation
BEGIN { $TYPEINFO{GetUsersForImport} = ["function", ["list","any"]];}
sub GetUsersForImport {
    my $self	= shift;
    my @ret	= ();
    if (defined ($installation_import{"users"}) &&
	ref ($installation_import{"users"}) eq "ARRAY") {
	@ret	= @{$installation_import{"users"}};
    }
    return \@ret;
}

# return the data of users and groups to be imported during installation
BEGIN { $TYPEINFO{GetDataForImport} = ["function", ["map", "string", "any"]];}
sub GetDataForImport {
    my $self		= shift;
    return \%installation_import;
}

BEGIN { $TYPEINFO{NotAskUppercase} = ["function", "boolean"];}
sub NotAskUppercase {
    return $not_ask_uppercase;
}

BEGIN { $TYPEINFO{SetAskUppercase} = ["function", "void", "boolean"];}
sub SetAskUppercase {
    my $self	= shift;
    if ($not_ask_uppercase != bool ($_[0])) {
        $not_ask_uppercase 	= bool ($_[0]);
	$customs_modified	= 1;
    }
}

BEGIN { $TYPEINFO{NotAskNISServerNotDES} = ["function", "boolean"];}
sub NotAskNISServerNotDES {
    return $not_ask_nisserver_notdes;
}

BEGIN { $TYPEINFO{SetAskNISServerNotDES} = ["function", "void", "boolean"];}
sub SetAskNISServerNotDES {
    my $self	= shift;
    if ($not_ask_nisserver_notdes != bool ($_[0])) {
        $not_ask_nisserver_notdes 	= bool ($_[0]);
	$customs_modified		= 1;
    }
}

    
    
##------------------------------------
BEGIN { $TYPEINFO{CheckHomeMounted} = ["function", "void"]; }
# Checks if the home directory is properly mounted (bug #20365)
sub CheckHomeMounted {

    if (Mode->test() || Mode->config()) {
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

    if (FileUtils->Exists ("/etc/cryptotab")) {
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
        my $dest_home_mountpoint = Installation->destdir() . $home;

        y2milestone("home mount points are:", $dest_home_mountpoint, ",", $home);
        my $mounted	= 0;
        my $mtab	= SCR->Read (".etc.mtab");
	if (defined $mtab && ref ($mtab) eq "ARRAY") {
	    foreach my $line (@{$mtab}) {
		my %line	= %{$line};
                # While installing package "systemd" the /etc/mtab entries will be
                # changed from e.g. /home to /mnt/home. This will be done in SLES12
                # only and not for e.g. LEAP. So we have to check both.
                # (bnc#995299, bnc#980878)
		if ($line{"file"} eq $dest_home_mountpoint || $line{"file"} eq $home ) {
		    $mounted = 1;
		}
	    }
        }

        if (!$mounted) {
            return sformat (
# Popup text: %1 is the file name (e.g. /etc/fstab),
# %2 is the directory (e.g. /home),
__("In %1, there is a mount point for the directory
%2, which is used as a default home directory for new
users, but this directory is not currently mounted.
If you add new users using the default values,
their home directories will be created in the current %2.
This can result in these directories not being accessible
after you mount correctly. Continue user configuration?"),
	    $mountpoint_in, $home);
	}
    }
    return $ret;
}


##-------------------------------------------------------------------------
##----------------- get routines ------------------------------------------

##------------------------------------
BEGIN { $TYPEINFO{GetMinPasswordLength} = ["function", "integer", "string"]; }
sub GetMinPasswordLength {

    my ($self, $type)		= @_;
    return UsersSimple->GetMinPasswordLength ($type);
}

##------------------------------------
BEGIN { $TYPEINFO{GetMaxPasswordLength} = ["function", "integer", "string"]; }
sub GetMaxPasswordLength {
    my ($self, $type)		= @_;
    return UsersSimple->GetMaxPasswordLength ($type);
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
            "shadowInactive"	=> $useradd_defaults{"inactive"},
            "shadowExpire"      => $useradd_defaults{"expire"},
            "shadowWarning"     => $pass_warn_age,
            "shadowMin"         => $pass_min_days,
            "shadowMax"         => $pass_max_days,
            "shadowFlag"        => "",
            "shadowLastChange"	=> "",
	    "userPassword"	=> undef
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

##------------------------------------
# Change the structure with default values (/etc/defaults/useradd)
# @param new_defaults new values
# @param groupname the name of dew default group
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
# Returns the map of user specified by its UID
# @param uid	user's identification number (UID) or uidnumber attribute for LDAP users
# @param type	"local"/"system"/"nis"/"ldap"; if empty, all types are searched
# @return the map of _first_ user matching the parameters
BEGIN { $TYPEINFO{GetUser} = [ "function",
    ["map", "string", "any" ],
    "integer", "string"];
}
sub GetUser {

    my $self		= shift;
    my $uid		= $_[0];
    my @types_to_look	= ($_[1]);
    if ($_[1] eq "") {
	@types_to_look = keys %users_by_uidnumber;
	unshift @types_to_look, UsersCache->GetUserType ();
    }
    foreach my $type (@types_to_look) {
	next if (!$type);
	if (defined $users_by_uidnumber{$type}{$uid} &&
	    (ref ($users_by_uidnumber{$type}{$uid}) eq "HASH") &&
	    %{$users_by_uidnumber{$type}{$uid}})
	{
	    my $first_username	= (keys %{$users_by_uidnumber{$type}{$uid}})[0];
	    return $self->GetUserByName ($first_username, $type);
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
    
    foreach my $id (keys %{$users{$type}}) {
	my $user	= $users{$type}{$id};
	if (ref ($user) eq "HASH" && defined $user->{$key}) {
	    if (defined $ret->{$user->{$key}}) {
		y2warning("Multiple users satisfy the input conditions: user $id, key ".  $user->{$key});
	    }
	    else {
		$ret->{$user->{$key}}	= $user;
	    }
	}
    }
    return $ret;
    # error message
    my $msg = __("Multiple users satisfy the input conditions.");
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
# Returns the map of user specified by its name
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
    }

    my @types_to_look	= ($_[1]);
    if ($_[1] eq "") {
	@types_to_look = keys %users;
	unshift @types_to_look, UsersCache->GetUserType ();
    }
    
    foreach my $type (@types_to_look) {
	if (defined $users{$type}{$username}) {
	    return $users{$type}{$username};
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
# Returns the map of first group with given GID
# @param name 	group's GID (or gidnumber attribute for LDAP groups)
# @param type 	if empty, all types are searched
# @return the map of first group matching parameters
BEGIN { $TYPEINFO{GetGroup} = [ "function",
    ["map", "string", "any" ],
    "integer", "string"];
}
sub GetGroup {

    my $self		= shift;
    my $gid		= $_[0];
    my @types_to_look	= ($_[1]);
    if ($_[1] eq "") {
	@types_to_look = sort keys %groups_by_gidnumber;
	unshift @types_to_look, UsersCache->GetGroupType ();
    }

    foreach my $type (@types_to_look) {
	if (defined $groups_by_gidnumber{$type}{$gid} &&
	    ref ($groups_by_gidnumber{$type}{$gid}) eq "HASH" &&
	    %{$groups_by_gidnumber{$type}{$gid}})
	{
	    my $first_groupname	= (keys %{$groups_by_gidnumber{$type}{$gid}})[0];
	    return $self->GetGroupByName ($first_groupname, $type);
	}
    }
    return {};
}

##------------------------------------
# Returns the map of first group with given name
# @param name 	group's name (or cn attribute for LDAP groups)
# @param type 	if empty, all types are searched
# @return the map of first group matching parameters
BEGIN { $TYPEINFO{GetGroupByName} = [ "function",
    ["map", "string", "any" ],
    "string", "string"];
}
sub GetGroupByName {

    my $self		= shift;
    my $groupname	= $_[0];
    my $group_type	= $_[1];

    my @types_to_look	= ($group_type);
    if ($group_type eq "") {
	@types_to_look = keys %groups;
	unshift @types_to_look, UsersCache->GetGroupType ();
    }

    foreach my $type (@types_to_look) {
	if (defined $groups{$type}{$groupname}) {
	    return $groups{$type}{$groupname};
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
    if (! FileUtils->Exists ($file)) {
	my %customs	= ();
	SCR->Write (".target.ycp", $file, \%customs);
	$customs_modified	= 1;

	if ($ldap_available && Ldap->initial_defaults_used () &&
	    !Mode->config ())
	{
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
	    if (defined ($custom_map{"dont_warn_when_nisserver_notdes"})) {
		$not_ask_nisserver_notdes	=
		    $custom_map{"dont_warn_when_nisserver_notdes"};
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
    # LDAP is not set in nsswitch, but in customs: remove from customs (#360600)
    if (!$ldap_available &&
	(contains (\@user_custom_sets, "ldap") ||
	 contains (\@group_custom_sets, "ldap")))
    {
	@user_custom_sets       = grep (!/^ldap$/, @user_custom_sets);
	@group_custom_sets      = grep (!/^ldap$/, @group_custom_sets);
	$customs_modified       = 1;
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
	if (FileUtils->Exists ($shell_entry)) {
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
# Read settings from Security module
# @param force	force reading, even if already read before
BEGIN { $TYPEINFO{ReadSystemDefaults} = ["function", "void", "boolean"]; }
sub ReadSystemDefaults {

    if (Mode->test ()) { return; }

    my $self		= shift;
    my $force		= shift;

    return if ($system_defaults_read && !$force);

    if (! Security->GetModified ()) {
	my $progress_orig = Progress->set (0);
	Security->Read ();
	Progress->set ($progress_orig);
    }
    $security_modified 		= $security_modified || Security->GetModified ();

    my %security	= %{Security->Export ()};
    $pass_warn_age	= $security{"PASS_WARN_AGE"}	|| $pass_warn_age;
    $pass_min_days	= $security{"PASS_MIN_DAYS"}	|| $pass_min_days;
    $pass_max_days	= $security{"PASS_MAX_DAYS"}	|| $pass_max_days;

    # command to call before/after adding/deleting user
    $useradd_cmd 	= $security{"USERADD_CMD"};
    $userdel_precmd 	= $security{"USERDEL_PRECMD"};
    $userdel_postcmd 	= $security{"USERDEL_POSTCMD"};

    # command to call after adding group
    $groupadd_cmd 	= SCR->Read (".etc.login_defs.GROUPADD_CMD") || "";

    $encryption_method	= $security{"PASSWD_ENCRYPTION"} || $encryption_method;
    UsersSimple->SetEncryptionMethod ($encryption_method);
    $group_encryption_method
	= $security{"GROUP_ENCRYPTION"} || $encryption_method;

    UsersSimple->SetCrackLibDictPath ($security{"CRACKLIB_DICTPATH"} || "");
    UsersSimple->UseCrackLib ($security{"PASSWD_USE_CRACKLIB"} eq "yes");

    if (defined $security{"PASS_MIN_LEN"}) {
	UsersSimple->SetMinPasswordLength ("local", $security{"PASS_MIN_LEN"});
	UsersSimple->SetMinPasswordLength ("system", $security{"PASS_MIN_LEN"});
    }

    my $login_defs	= SCR->Dir (".etc.login_defs");
    if (contains ($login_defs, "CHARACTER_CLASS")) {
	$character_class= SCR->Read (".etc.login_defs.CHARACTER_CLASS");
        UsersSimple->SetCharacterClass ($character_class);
    }

    my %max_lengths		= %{Security->PasswordMaxLengths ()};
    if (defined $max_lengths{$encryption_method}) {
	my $len	= $max_lengths{$encryption_method};
	UsersSimple->SetMaxPasswordLength ("local", $len);
	UsersSimple->SetMaxPasswordLength ("system", $len);
    }

    UsersCache->InitConstants (\%security);
    $system_defaults_read	= 1;
}

##------------------------------------
BEGIN { $TYPEINFO{ReadLoginDefaults} = ["function", "boolean"]; }
sub ReadLoginDefaults {

    my $self		= shift;
    foreach my $key (sort keys %useradd_defaults) {
        my $entry = SCR->Read (".etc.default.useradd.\"\Q$key\E\"");
        # use the defaults set in this file if $entry not defined
        next if !defined $entry;
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
    $users_by_uidnumber{$type}	= \%{SCR->Read (".ldap.users.by_uidnumber")};
    $groups{$type}		= \%{SCR->Read (".ldap.groups")};
    $groups_by_gidnumber{$type}	= \%{SCR->Read (".ldap.groups.by_gidnumber")};
    # read the necessary part of LDAP user configuration
    UsersSimple->SetMinPasswordLength("ldap",UsersLDAP->GetMinPasswordLength());
    UsersSimple->SetMaxPasswordLength("ldap",UsersLDAP->GetMaxPasswordLength());

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
	$users_by_uidnumber{$type}	= \%{SCR->Read (".nis.users.by_uidnumber")};
	$groups{$type}		= \%{SCR->Read (".nis.groups")};
	$groups_by_gidnumber{$type}	= \%{SCR->Read (".nis.groups.by_gidnumber")};

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
    my $init = UsersPasswd->Read (\%configuration);
    if (!$init) {
	my $error 	= UsersPasswd->GetError ();
	my $error_info	= UsersPasswd->GetErrorInfo ();
	return UsersUI->GetPasswdErrorMessage ($error, $error_info);
    }
    $passwd_not_read 		= 0;
    $shadow_not_read 		= 0;
    $group_not_read 		= 0;

    foreach my $type ("local", "system") {
	$users{$type}		= UsersPasswd->GetUsers ($type);
	$users_by_uidnumber{$type} = UsersPasswd->GetUsersByUIDNumber ($type);
	$shadow{$type}		= UsersPasswd->GetShadow ($type);
	$groups{$type}		= UsersPasswd->GetGroups ($type);
	$groups_by_gidnumber{$type}= UsersPasswd->GetGroupsByGIDNumber ($type);
    }
    my $pluses		= UsersPasswd->GetPluslines ("passwd");
    if (ref ($pluses) eq "ARRAY") {
	@pluses_passwd	= @{$pluses};
    }
    $pluses		= UsersPasswd->GetPluslines ("shadow");
    if (ref ($pluses) eq "ARRAY") {
	@pluses_shadow	= @{$pluses};
    }
    $pluses		= UsersPasswd->GetPluslines ("group");
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
    my $caption 	= __("Initializing User and Group Configuration");
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
		 __("Reading the default system settings..."),
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

    # default login settings
    if ($use_gui) { Progress->NextStage (); }

    $self->ReadLoginDefaults ();

    $error_msg = $self->CheckHomeMounted();

    if ($use_gui && $error_msg ne "" && !Popup->YesNo ($error_msg)) {
	return $error_msg; # problem with home directory: do not continue
    }

    # default system settings
    if ($use_gui) { Progress->NextStage (); }

    $self->ReadSystemDefaults (1);

    $self->ReadAllShells();

    # configuration type
    if ($use_gui) { Progress->NextStage (); }

    $self->ReadSourcesSettings();

    if ($nis_master && $use_gui && !Stage->cont()) {
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

    if ($read_local && !Mode->test ()) {
	$error_msg = $self->ReadLocal ();
    }

    if ($error_msg ne "") {
	Report->Error ($error_msg);
	return $error_msg;# problem with reading config files( /etc/passwd etc.)
    }

    # read shadow settings during cloning users (#suse41026, #94340)
    if ($export_all) {
	foreach my $type ("system", "local") {
	    foreach my $id (keys %{$users{$type}}) {
		$self->SelectUserByName ($id); # SelectUser does LoadShadow
		my %user		= %user_in_work;
		$user{"encrypted"}	= YaST::YCP::Boolean (1);
		undef %user_in_work;
		$users{$type}{$id}	= \%user;
	    }
	    # do not re-crypt group password value (bnc#722421)
	    foreach my $id (keys %{$groups{$type}}) {
		$groups{$type}{$id}{"encrypted"}	= YaST::YCP::Boolean (1);
	    }
	}
    }

    # Build the cache structures
    if ($use_gui) { Progress->NextStage (); }

    $self->ReadUsersCache ();

    if (!$use_next_time) {
	Autologin->Read ();
    }

    if ((Stage->cont () || Stage->firstboot ()) && Autologin->available () && !$use_next_time &&
	ProductFeatures->GetBooleanFeature ("globals", "enable_autologin")) {
	Autologin->Use (YaST::YCP::Boolean (1));
    }

    $self->ReadAvailablePlugins ();

    $root_mail	= MailAliases->GetRootAlias ();
    if (defined $root_mail) {
	foreach my $alias (split (/,/, $root_mail)) {
	    $alias	=~ s/[ \t]//g;
	    $root_aliases{$alias}	= 1;
	}
    }
    %root_aliases_orig	= %root_aliases;
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
# select user by uid
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
    %group_in_work	= %{$self->GetGroupByName($_[0], "")};
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
    
	my $username	= $user_in_work{"uid"} || "";
	# disable autologin when user is deleted #45261
	if (Autologin->user () eq $username) {
	    Autologin->Disable ();
	}
	$self->RemoveRootAlias ($username);

	my $type		= $user_in_work{"type"};
	my $plugins		= $user_in_work{"plugins"};

	# --------- PluginPresent: check which plugins are in use for this user
	# so they can be called in "Write"
	my $result = UsersPlugins->Apply ("PluginPresent", {
	    "what"	=> "user",
	    "type"	=> $type,
	}, \%user_in_work);
	if (defined ($result) && ref ($result) eq "HASH") {
	    $plugins = [];
	    foreach my $plugin (keys %{$result}) {
		if (bool ($result->{$plugin}) && !contains ($plugins, $plugin))
		{
		    push @{$plugins}, $plugin;
		}
	    }
	    $user_in_work{"plugins"}	= $plugins;
	}
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

    my $self	= shift;
    my $type	= shift;
    my $adding	= shift;
    my @plugins	= ();

    if ($type eq "ldap") {
	@plugins	= @{UsersLDAP->GetUserPlugins ()};
    }
    else {
	@plugins	= @local_plugins;
    }
    # check for default plug-ins for adding user
    # (and only when adding user, otherwise the check for presence was already done...)
    if (defined $adding) {
	my $result = UsersPlugins->Apply ("PluginPresent", {
	    "what"	=> "user",
	    "type"	=> $type,
	}, {});	# plugin present for empty user => should be added by default
	if (defined ($result) && ref ($result) eq "HASH") {
	    foreach my $plugin (keys %{$result}) {
		# check if plugin has done the 'PluginPresent' action
		if (bool ($result->{$plugin}) && !contains (\@plugins, $plugin)){
		    push @plugins, $plugin;
		}
	    }
	}
    }
    return \@plugins;
}

##------------------------------------
BEGIN { $TYPEINFO{GetGroupPlugins} = ["function", ["list", "string"], "string"]};
sub GetGroupPlugins {

    my $self		= shift;
    if ($_[0] eq "ldap") {
	return UsersLDAP->GetGroupPlugins ();
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
	    $result	= ShowPluginWarning ($result);
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

    if ($no_plugin && ($type eq "local" || $type eq "system") &&
	bool ($user{"encrypted"})) {
	# no plugins available: local user
	my $pw			= $user{"userPassword"};
	if ((defined $pw) && ($pw !~ m/^\!/)) {
	    $user{"userPassword"}	= "!".$pw;
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
	    $result	= ShowPluginWarning ($result);
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

    if ($no_plugin && ($type eq "local" || $type eq "system") &&
	bool ($user{"encrypted"})) {
	# no plugins available: local user
	my $pw	= $user{"userPassword"};
	if (defined $pw) {
	    $pw				=~ s/^\!//;
	    $user{"userPassword"}	= $pw;
	}
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
        "single_values" => YaST::YCP::Boolean (1),
	"attrs"         => [ "*", "+" ] # read also operational attributes (#238254)
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

    # error message
    if (!%user_in_work) { return __("User does not exist."); }
    my $self		= shift;
    my %data		= %{$_[0]};
    my $type		= $user_in_work{"type"} || "";
    if (defined $data{"type"}) {
	$type 	= $data{"type"};
    }
    my $username	= $user_in_work{"uid"};

    # check if user is edited for first time
    if (!defined $user_in_work{"org_user"} &&
	($user_in_work{"what"} || "") ne "add_user") {
	# read the rest of LDAP if necessary
	if ($type eq "ldap" && ($user_in_work{"modified"} || "") ne "added") {
	    ReadLDAPUser ();
	}

	# password we have read was real -> set "encrypted" flag
	my $pw	= $user_in_work{"userPassword"};
	if (defined $pw) {
	    if (!defined $user_in_work{"encrypted"} ||
		bool ($user_in_work{"encrypted"})) {
		$user_in_work{"encrypted"}	= YaST::YCP::Boolean (1);
	    }
	    # check thi initial enabled/disabled status
	    if ($pw =~ m/^\!/) {
		$user_in_work{"enabled"}	= YaST::YCP::Boolean (0);
	    }
	}

	# set the default value ("move directories, when changed")
	if (!defined $user_in_work{"create_home"}) {
	    $user_in_work{"create_home"}	= YaST::YCP::Boolean (1);
	}

	# set the default value ("change the owner of home to its user")
	if (!defined $user_in_work{"chown_home"}) {
	    $user_in_work{"chown_home"}		= YaST::YCP::Boolean (1);
	}

	# save first map for later checks of modification (in Commit)
	my %org_user			= %user_in_work;
	$user_in_work{"org_user"}	= \%org_user;
	# grouplist wasn't fully generated while reading nis & ldap users
	if ($type eq "nis" || $type eq "ldap") {
	    $user_in_work{"grouplist"} = FindGroupsBelongUser (\%org_user);
	    # set 'groupname' if default group is not LDAP (#43433)
	    if (!defined $user_in_work{"groupname"}) {
		my %g	= %{$self->GetGroup ($user_in_work{"gidNumber"}, "")};
		if (%g && defined ($g{"cn"})) {
	            $user_in_work{"groupname"}  		= $g{"cn"};
		    # TODO adapt the 'more_users' entry of this group?
		}
	    }
	}
	# empty password entry for autoinstall config (do not want to
	# read password from disk: #30573)
	if (Mode->config () && ($user_in_work{"modified"} || "") ne "imported"){
	    $user_in_work{"userPassword"} = undef;
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
	    $result	= ShowPluginWarning ($result);
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
	if ($key eq "uid" || $key eq "homeDirectory" ||
	    $key eq "uidNumber" || $key eq "type" || $key eq "groupname")
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
	    $key eq "chown_home" ||
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
	if ($key eq "userPassword" && (defined $data{$key}) &&
	    (!defined $user_in_work{$key} || $data{$key} ne $user_in_work{$key})
	)
	{
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
	    $result	= ShowPluginWarning ($result);
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
    if (!%group_in_work) { return __("Group does not exist."); }

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
	if (defined ($group_in_work{"userPassword"}) &&
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
	$group_in_work{"plugins"}	= $self->GetGroupPlugins ($type);
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
	    $result	= ShowPluginWarning ($result);
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
	if ($key eq "cn" || $key eq "gidNumber" || $key eq "type") {
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
	if ($key eq "userPassword" && (defined $data{$key}) &&
	    # crypt password only once (when changed)
	    !bool ($data{"encrypted"}))
	{
		$group_in_work{$key}		=
		    $self->CryptPassword ($data{$key}, $type, "group");
		$group_in_work{"encrypted"}	= YaST::YCP::Boolean (1);
		$data{"encrypted"}		= YaST::YCP::Boolean (1);
		next;
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
	    $result	= ShowPluginWarning ($result);
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

    my $plugins_to_remove = $group{"plugins_to_remove"};
    if (contains ($plugins_to_remove, $plugin, 1)) {
	my @plugins_updated	= ();
	foreach my $p (@$plugins_to_remove) {
	    if ($p ne $plugin) {
		push @plugins_updated, $p;
	    }
	}
	$group{"plugins_to_remove"}	= \@plugins_updated;
    }

    if (($group{"what"} || "") eq "add_group") {

	my $result = UsersPlugins->Apply ("AddBefore", $args, \%group);
	# check if plugin has done the 'AddBefore' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    $result	= ShowPluginWarning ($result);
	    %group	= %{$result->{$plugin}};
	}
	else {
	    $result = UsersPlugins->Apply ("Error", $args, {});
	    $plugin_error = $result->{$plugin} || "";
	}

	if ($plugin_error) { return $plugin_error; }

	$result = UsersPlugins->Apply ("Add", $args, \%group);
	# check if plugin has done the 'Add' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    $result	= ShowPluginWarning ($result);
	    %group	= %{$result->{$plugin}};
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
	    $result	= ShowPluginWarning ($result);
	    %group	= %{$result->{$plugin}};
	}
	else {
	    $result = UsersPlugins->Apply ("Error", $args, {});
	    $plugin_error = $result->{$plugin} || "";
	}
	if ($plugin_error) { return $plugin_error; }

	$result = UsersPlugins->Apply ("Edit", $args, \%group);
	# check if plugin has done the 'EditBefore' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    $result	= ShowPluginWarning ($result);
	    %group	= %{$result->{$plugin}};
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

    my $plugins_to_remove = $user{"plugins_to_remove"};
    if (contains ($plugins_to_remove, $plugin, 1)) {
	my @plugins_updated	= ();
	foreach my $p (@$plugins_to_remove) {
	    if ($p ne $plugin) {
		push @plugins_updated, $p;
	    }
	}
	$user{"plugins_to_remove"}	= \@plugins_updated;
    }

    if (($user{"what"} || "") eq "add_user") {

	my $result = UsersPlugins->Apply ("AddBefore", $args, \%user);
	# check if plugin has done the 'AddBefore' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    $result	= ShowPluginWarning ($result);
	    %user	= %{$result->{$plugin}};
	}
	else {
	    $result = UsersPlugins->Apply ("Error", $args, {});
	    $plugin_error = $result->{$plugin} || "";
	}
	if ($plugin_error) { return $plugin_error; }

	$result = UsersPlugins->Apply ("Add", $args, \%user);
	# check if plugin has done the 'Add' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    $result	= ShowPluginWarning ($result);
	    %user	= %{$result->{$plugin}};
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
	    $result	= ShowPluginWarning ($result);
	    %user	= %{$result->{$plugin}};
	}
	else {
	    $result = UsersPlugins->Apply ("Error", $args, {});
	    $plugin_error = $result->{$plugin} || "";
	}
	if ($plugin_error) { return $plugin_error; }

	$result = UsersPlugins->Apply ("Edit", $args, \%user);
	# check if plugin has done the 'Edit' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    $result	= ShowPluginWarning ($result);
	    %user	= %{$result->{$plugin}};
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
	    $result	= ShowPluginWarning ($result);
	    %group	= %{$result->{$plugin}};
	}
	else {
	    $result = UsersPlugins->Apply ("Error", $args, {});
	    $plugin_error = $result->{$plugin} || "";
	}
	if ($plugin_error) { return $plugin_error; }

	$result = UsersPlugins->Apply ("Add", $args, \%group);
	# check if plugin has done the 'Add' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    $result	= ShowPluginWarning ($result);
	    %group	= %{$result->{$plugin}};
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
	    $result	= ShowPluginWarning ($result);
	    %group	= %{$result->{$plugin}};
	}
	else {
	    $result = UsersPlugins->Apply ("Error", $args, {});
	    $plugin_error = $result->{$plugin} || "";
	}
	if ($plugin_error) { return $plugin_error; }

	$result = UsersPlugins->Apply ("Edit", $args, \%group);
	# check if plugin has done the 'EditBefore' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    $result	= ShowPluginWarning ($result);
	    %group	= %{$result->{$plugin}};
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
	    $result	= ShowPluginWarning ($result);
	    %user	= %{$result->{$plugin}};
	}
	else {
	    $result = UsersPlugins->Apply ("Error", $args, {});
	    $plugin_error = $result->{$plugin} || "";
	}
	if ($plugin_error) { return $plugin_error; }

	$result = UsersPlugins->Apply ("Add", $args, \%user);
	# check if plugin has done the 'Add' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    $result	= ShowPluginWarning ($result);
	    %user	= %{$result->{$plugin}};
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
	    $result	= ShowPluginWarning ($result);
	    %user	= %{$result->{$plugin}};
	}
	else {
	    $result = UsersPlugins->Apply ("Error", $args, {});
	    $plugin_error = $result->{$plugin} || "";
	}
	if ($plugin_error) { return $plugin_error; }

	$result = UsersPlugins->Apply ("Edit", $args, \%user);
	# check if plugin has done the 'EditBefore' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    $result	= ShowPluginWarning ($result);
	    %user	= %{$result->{$plugin}};
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
	$user_in_work{"plugins"}	= $self->GetUserPlugins ($type, 1);
    }
    my $plugins		= $user_in_work{"plugins"};
    if (defined $data{"plugins"} && ref ($data{"plugins"}) eq "ARRAY") {
	$plugins	= $data{"plugins"};
    }
    my $plugin_error	= "";
    foreach my $plugin (sort @{$plugins}) {
	# sort: default LDAP plugin is now first, so other plugins don't have
	# to check classes every time. New plugins have to do such check.
	if ($plugin_error) { last; }
	my $result = UsersPlugins->Apply ("AddBefore", {
	    "what"	=> "user",
	    "type"	=> $type,
	    "plugins"	=> [ $plugin ]
	}, \%data);
	# check if plugin has done the 'AddBefore' action
	if (defined $result->{$plugin} && ref ($result->{$plugin}) eq "HASH") {
	    $result	= ShowPluginWarning ($result);
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
	    $key eq "chown_home" ||
	    $key eq "delete_home" || $key eq "no_skeleton" ||
	    $key eq "disabled" || $key eq "enabled") {
	    $user_in_work{$key}	= YaST::YCP::Boolean ($data{$key});
	}
	elsif ($key eq "userPassword" && (defined $data{$key}) &&
	    # crypt password only once
	    !bool ($data{"encrypted"}))
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

    if (!defined $user_in_work{"uidNumber"}) {
	$user_in_work{"uidNumber"} = UsersCache->NextFreeUID ();
    }
    my $username		= $data{"uid"} || $data{"username"};
    if (defined $username) {
	$user_in_work{"uid"}	= $username;
    }

    if (!defined $user_in_work{"cn"}) {
	$user_in_work{"cn"}	= "";
    }
    if (!defined $user_in_work{"gidNumber"}) {
	$user_in_work{"gidNumber"}	= $self->GetDefaultGID ($type);
    }
    if (!defined $user_in_work{"groupname"} || $user_in_work{"groupname"} eq "") {
	my %group	= %{$self->GetGroup ($user_in_work{"gidNumber"}, "")};
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
    if (!defined $user_in_work{"homeDirectory"} && defined ($username)) {
	$user_in_work{"homeDirectory"} = $self->GetDefaultHome ($type).$username;
    }
    if (!defined $user_in_work{"loginShell"}) {
	$user_in_work{"loginShell"}	= $self->GetDefaultShell ($type);
    }
    if (!defined $user_in_work{"create_home"}) {
	$user_in_work{"create_home"}	= YaST::YCP::Boolean (1);
    }
    if (!defined $user_in_work{"chown_home"}) {
	$user_in_work{"chown_home"}	= YaST::YCP::Boolean (1);
    }
    my %default_shadow = %{$self->GetDefaultShadow ($type)};
    foreach my $shadow_item (keys %default_shadow) {
	if (!defined $user_in_work{$shadow_item}) {
	    $user_in_work{$shadow_item}	= $default_shadow{$shadow_item};
	}
    }
    if (!defined $user_in_work{"shadowLastChange"} ||
	$user_in_work{"shadowLastChange"} eq "") {
        $user_in_work{"shadowLastChange"} = LastChangeIsNow ();
    }
#    if (!defined $user_in_work{"userPassword"}) {
#	$user_in_work{"userPassword"}	= "";
#    }
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
	    $result	= ShowPluginWarning ($result);
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
	    $result	= ShowPluginWarning ($result);
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
	if ($key eq "userPassword" && (defined $data{$key}) &&
	    !bool ($data{"encrypted"}))
	{
	    $group_in_work{$key}	=
		$self->CryptPassword ($data{$key}, $type, "group");
	    $group_in_work{"encrypted"}	= YaST::YCP::Boolean (1);
	}
	else {
	    $group_in_work{$key}	= $data{$key};
	}
    }

    $group_in_work{"type"}		= $type;
    $group_in_work{"what"}		= "add_group";
	
    UsersCache->SetGroupType ($type);

    if (!defined $group_in_work{"gidNumber"}) {
	$group_in_work{"gidNumber"}	= UsersCache->NextFreeGID ($type);
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
	    $result	= ShowPluginWarning ($result);
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
	if (($user{"plugin_modified"} || 0) == 1) {
	    return 1; #TODO save special plugin_modified global value?
	}
	# grouplist can be ignored, it is a modification of groups
	while ( my ($key, $value) = each %org_user) {
	    last if $ret;
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
	    if (!defined $user{$key} ||
		((!defined $value) && (defined $user{$key})) ||
		((defined $value) && ($user{$key} ne $value)))
	    {
		$ret = 1;
		y2debug ("old value: ", $value || "(not defined)");
		y2debug ("... changed to: ", $user{$key} || "(not defined)" );
	    }
	}
	return $ret;
    }
    my @internal_keys	= @{UsersLDAP->GetUserInternal ()};
    foreach my $key (keys %user) {
	last if $ret;
	my $value = $user{$key};
	if (!defined $user{$key} || contains (\@internal_keys, $key) ||
	    ref ($value) eq "HASH" ) {
	    next;
	}
	if ($key eq "plugin_modified") {
	    $ret	= 1;
	}
	elsif (!defined ($org_user{$key})) {
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
	    y2debug (sformat ("$key modified: old %1 new %2", $org_user{$key}, $value));
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
    my $uid		= $user{"uidNumber"};
    my $org_uid		= $user{"org_uidNumber"} || $uid;
    my $username	= $user{"uid"};
    my $org_username	= $user{"org_uid"} || $username;
    my $groupname	= $user{"groupname"} || $self->GetDefaultGroupname ($type);
    my $home		= $user{"homeDirectory"} || "";
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
            %group_in_work = %{$self->GetGroupByName ($group, "")};
            if (%group_in_work && $self->AddUserToGroup ($username)) {
                $self->CommitGroup ();
	    }
        };
        # add user to his default group (updating only cache variables)
        %group_in_work = %{$self->GetGroupByName ($groupname, "")};
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
            %group_in_work = %{$self->GetGroupByName ($group, "")};
            if (%group_in_work) {
		my $commit_group	= 0;
	        # username changed - remove org_username
	        if ($org_username ne $username) {
		    if ($self->RemoveUserFromGroup ($org_username)) {
			$commit_group	= 1;
		    }
	        }
	        if ($self->AddUserToGroup ($username)) {
		    $commit_group	= 1;
		}
		$self->CommitGroup () if $commit_group;
	    }
        };

        # check if user was removed from some additional groups
	if (defined $user{"removed_grouplist"}) {
            foreach my $group (keys %{$user{"removed_grouplist"}}) {
	        %group_in_work = %{$self->GetGroupByName ($group, "")};
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
            %group_in_work	= %{$self->GetGroupByName ($groupname, "")};
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
            %group_in_work = %{$self->GetGroupByName ($org_groupname, "")};
            if (%group_in_work) {
                $group_in_work{"what"}	= "user_change_default";
                delete $group_in_work{"more_users"}{$org_username};
                $self->CommitGroup ();
            }
            # 2. and add it to the new one:
            %group_in_work	= %{$self->GetGroupByName ($groupname, "")};
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
	# modify Autologin status if necessary
        if ($username ne $org_username && Autologin->user () eq $org_username) {
	    Autologin->user ($username);
	    Autologin->modified (YaST::YCP::Boolean (1));
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
	    $removed_users{$type}{$username}	= \%user;
        }

        # check the change of group membership
        foreach my $group (keys %grouplist) {
            %group_in_work = %{$self->GetGroupByName ($group, "")};
            if (%group_in_work &&
	        $self->RemoveUserFromGroup ($org_username)) {
                $self->CommitGroup();
	    }
        };
        # remove user from his default group -- only cache structures
        %group_in_work		= %{$self->GetGroupByName ($groupname, "")};
	if (%group_in_work) {
	    $group_in_work{"what"}	= "user_change_default";
            delete $group_in_work{"more_users"}{$username};
	    $self->CommitGroup ();
	}

	# store deleted directories... someone could want to use them
	if ($type ne "ldap" && bool ($user{"delete_home"})) {
	    my $h	= $home;
	    if (defined $user{"org_user"}{"homeDirectory"}) {
	        $h	= $user{"org_user"}{"homeDirectory"};
	    }
	    $removed_homes{$h}	= $org_username;
	}
    }

    # --- 2. and now do the common changes

    UsersCache->CommitUser (\%user);
    if ($what_user eq "delete_user") {
        delete $users{$type}{$username};

	if (defined $users_by_uidnumber{$type}{$uid}{$username}) {
	    delete $users_by_uidnumber{$type}{$uid}{$username};
	}

        if ($type ne "ldap") {
            delete $shadow{$type}{$username};
	}
	if (defined $modified_users{$type}{$username}) {
	    delete $modified_users{$type}{$username};
	}
    }
    else {

        if ($org_type ne $type) {
            delete $shadow{$org_type}{$org_username};
        }
        if ($username ne $org_username || $org_type ne $type) {
	    if (defined ($users{$org_type}{$org_username})) {
		delete $users{$org_type}{$org_username};
	    }
	    if (defined ($modified_users{$org_type}{$org_username})) {
		delete $modified_users{$org_type}{$org_username};
	    }
	    if (defined $users_by_uidnumber{$org_type}{$org_uid}{$org_username}) {
		delete $users_by_uidnumber{$org_type}{$org_uid}{$org_username};
	    }
        }
	elsif ($uid != $org_uid) {
	    if (defined $users_by_uidnumber{$org_type}{$org_uid}{$org_username}) {
		delete $users_by_uidnumber{$org_type}{$org_uid}{$org_username};
	    }
	}

        $user{"org_uidNumber"}			= $uid;
        $user{"org_uid"}			= $username;
	if ($home ne "") {
	    $user{"org_homeDirectory"}		= $home;
	}
        $users{$type}{$username}		= \%user;
	if (!defined $users_by_uidnumber{$type}{$uid}) {
	    $users_by_uidnumber{$type}{$uid}	= {};
	}
	$users_by_uidnumber{$type}{$uid}{$username}	= 1;

	if ((($user{"modified"} || "") ne "") && $what_user ne "group_change") {
	    $modified_users{$type}{$username}	= \%user;
	}

	if (bool ($user{"disabled"}) && Autologin->user () eq $username) {
	    y2milestone ("user is disabled, disabling autologin");
	    Autologin->Disable ();
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

    if (!%group_in_work || !defined $group_in_work{"gidNumber"} ||
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
    my $gid    		= $group{"gidNumber"};
    my $org_gid		= $group{"org_gidNumber"} || $gid;
    my %userlist	= ();
    if (defined $group{"userlist"}) {
	%userlist	= %{$group{"userlist"}};
    }
    y2milestone ("commiting group '$groupname', action is '$what_group'");

    if ($what_group ne "user_change_default" &&
	($type eq "system" || $type eq "local")) {
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
                    $user_in_work{"gidNumber"}	= $gid;
		    $user_in_work{"what"}	= "group_change";
		    if ($gid != $org_gid) {
			$user_in_work{"what"} 	= "group_change_default";
			$user_in_work{"org_gidNumber"} = $org_gid unless $user_in_work{"org_gidNumber"};
		    }
                    $self->CommitUser ();
                }
            };
        }
    }
    elsif ($what_group eq "delete_group") {
	if (!defined $group{"modified"} || $group{"modified"} ne "added") {
	    $group {"modified"}			= "deleted";
            $removed_groups{$type}{$org_groupname}	= \%group;
        }
	delete $groups{$type}{$org_groupname};

	if (defined $groups_by_gidnumber{$type}{$gid}{$org_groupname}) {
	    delete $groups_by_gidnumber{$type}{$gid}{$org_groupname};
	}

	if (defined $modified_groups{$type}{$groupname}) {
	    delete $modified_groups{$type}{$groupname};
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
        
        if ($groupname ne $org_groupname || $org_type ne $type) {
	    if (defined ($groups{$org_type}{$org_groupname})) {
		delete $groups{$org_type}{$org_groupname};
	    }
	    if (defined ($modified_groups{$org_type}{$org_groupname})) {
		delete $modified_groups{$org_type}{$org_groupname};
	    }
	    if (defined $groups_by_gidnumber{$org_type}{$org_gid}{$org_groupname}) {
		delete $groups_by_gidnumber{$org_type}{$org_gid}{$org_groupname};
	    }
        }
	elsif ($gid != $org_gid) {
	    if (defined $groups_by_gidnumber{$org_type}{$org_gid}{$org_groupname}) {
		delete $groups_by_gidnumber{$org_type}{$org_gid}{$org_groupname};
	    }
	}

        # this has to be done due to multiple changes of groupname
        $group{"org_cn"}			= $groupname;
        $group{"org_gidNumber"}			= $gid;

        $groups{$type}{$groupname}			= \%group;

	if (!defined $groups_by_gidnumber{$type}{$gid}) {
	    $groups_by_gidnumber{$type}{$gid} = {};
	}
	$groups_by_gidnumber{$type}{$gid}{$groupname}	= 1;

	if (($group{"modified"} || "") ne "") {
	    $modified_groups{$type}{$groupname}	= \%group;
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
    $customs{"dont_warn_when_nisserver_notdes"} =
	YaST::YCP::Boolean ($not_ask_nisserver_notdes);
    my $file	= Directory->vardir()."/users.ycp";
    my $ret = SCR->Write (".target.ycp", $file, \%customs);

    y2milestone ("Custom user information written: ", $ret);
    y2usernote ("Custom user information written: '$file'");
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
    y2usernote ("File '/etc/default/useradd' was modified.");
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
	my $progress_orig = Progress->set (0);
	$ret = Security->Write();
	Progress->set ($progress_orig);
	y2milestone ("Security module settings written: $ret");	
	$security_modified	= 0 if ($ret);
    }
    return $ret;
}


##------------------------------------
BEGIN { $TYPEINFO{WriteGroup} = ["function", "boolean"]; }
sub WriteGroup {

    my $cmd	= "/bin/cp $base_directory/group $base_directory/group.YaST2save";
    if (SCR->Execute (".target.bash", $cmd) != 0)
    {
	y2error ("creating backup of $base_directory/group failed");
	return 0;
    }
    y2usernote ("Backup created: '$cmd'");
    my $ret	= UsersPasswd->WriteGroups (\%groups);
    $cmd	= "diff -U 1 $base_directory/group.YaST2save $base_directory/group";
    my $out	= SCR->Execute (".target.bash_output", $cmd);
    my $stdout	= $out->{"stdout"} || "";
    y2usernote ("Comparing original and new version:
$stdout`");
    return $ret;
}

##------------------------------------
BEGIN { $TYPEINFO{WritePasswd} = ["function", "boolean"]; }
sub WritePasswd {
    my $cmd	= "/bin/cp $base_directory/passwd $base_directory/passwd.YaST2save";
    if (SCR->Execute (".target.bash", $cmd) != 0)
    {
	y2error ("creating backup of $base_directory/passwd failed");
	return 0;
    }
    y2usernote ("Backup created: '$cmd'");
    my $ret	= UsersPasswd->WriteUsers (\%users);
    $cmd	= "diff -U 1 $base_directory/passwd.YaST2save $base_directory/passwd";
    my $out	= SCR->Execute (".target.bash_output", $cmd);
    my $stdout	= $out->{"stdout"} || "";
    y2usernote ("Comparing original and new version:
$stdout`");
    return $ret;
}

##------------------------------------
BEGIN { $TYPEINFO{WriteShadow} = ["function", "boolean"]; }
sub WriteShadow {
    
    my $cmd	= "/bin/cp $base_directory/shadow $base_directory/shadow.YaST2save";
    if (SCR->Execute (".target.bash", $cmd) != 0)
    {
	if (FileUtils->Exists ("$base_directory/shadow")) {
	    y2error ("creating backup of $base_directory/shadow failed");
	    return 0;
	} else {
	    y2milestone ("$base_directory/shadow does not exists, so it won't be written");
	    return 1;
	}
    }
    else
    {
	y2usernote ("Backup created: '$cmd'");
        return UsersPasswd->WriteShadow (\%shadow);
    }
}

BEGIN { $TYPEINFO{WriteAuthorizedKeys} = ["function", "boolean"]; }
sub WriteAuthorizedKeys {
    foreach my $username (keys %{$modified_users{"local"}}) {
        my %user	= %{$modified_users{"local"}{$username}};
        if ($user{"modified"} eq "imported") {
            # Write authorized keys to user's home (FATE#319471)
            SSHAuthorizedKeys->write_keys($user{"homeDirectory"});
        }
    }

    # Do not crash if 'root' is undefined (bsc#1088183)
    if (defined($modified_users{"system"}{"root"})) {
      # Write root authorized keys(bsc#1066342)
      my %root_user = %{$modified_users{"system"}{"root"}};
      if ($root_user{"modified"} eq "imported") {
          SSHAuthorizedKeys->write_keys($root_user{"homeDirectory"});
      }
    }

    return 1;
}

##------------------------------------
# execute USERDEL_PRECMD scripts for users which should be deleted
sub PreDeleteUsers {

    my $ret = 1;
    
    if ($userdel_precmd eq "" || !FileUtils->Exists ($userdel_precmd)) {
	return $ret;
    }
    
    foreach my $type ("system", "local") {
	if (!defined $removed_users{$type}) {
	    next;
	}
	foreach my $username (keys %{$removed_users{$type}}) {
	    my %user = %{$removed_users{$type}{$username}};
	    my $cmd = sprintf ("$userdel_precmd $username %i %i %s",
		$user{"uidNumber"}, $user{"gidNumber"}, $user{"homeDirectory"});
	    SCR->Execute (".target.bash", $cmd);
	    y2usernote ("User pre-deletion script called: '$cmd'");
	};
    };
    return $ret;
}

# Remove crypted direcotries - because of 'cryptconfig pm-disable' call, this
# must be done when user is still known to PAM...
sub DeleteCryptedHomes {

    my $ret = 1;
    foreach my $home (keys %removed_homes) {
	$ret = $ret && UsersRoutines->DeleteCryptedHome ($home, $removed_homes{$home});
    };
    return $ret;
}

##------------------------------------
# 1. remove home directories,
# 2. execute USERDEL_POSTCMD scripts for deleted local/system users
# 3. call Write function of plugins to do the delete action
sub PostDeleteUsers {

    my $ret	= 1;

    foreach my $home (keys %removed_homes) {
	$ret = $ret && UsersRoutines->DeleteHome ($home);
    };

    if ($userdel_postcmd eq "" || !FileUtils->Exists($userdel_postcmd)) {
	return $ret;
    }

    foreach my $type ("system", "local") {
	if (!defined $removed_users{$type}) {
	    next;
	}
	my $plugin_error;
	foreach my $username (keys %{$removed_users{$type}}) {
	    my %user = %{$removed_users{$type}{$username}};
	    my $uid     = $user{"uidNumber"} || 0;
	    Syslog->Log ("User deleted by YaST: name=$username, UID=$uid");
	    my $cmd = sprintf ("$userdel_postcmd $username $uid %i %s",
              $user{"gidNumber"} || 0, $user{"homeDirectory"} || "");
	    SCR->Execute (".target.bash", $cmd);
	    # call the "Write" function from plugins...
	    my $args	= {
	    	"what"		=> "user",
		"type"		=> $type,
		"modified"	=> "deleted",
	    };
	    my $result		= UsersPlugins->Apply ("Write", $args, \%user);
	    $plugin_error	= GetPluginError ($args, $result);
	    y2usernote ("User post-deletion script called: '$cmd'");
	    Syslog->Log ("USERDEL_POSTCMD command called by YaST: $cmd");
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
        foreach my $username (keys %{$modified_users{$type}}) {
	    my $a = $modified_users{$type}{$username}{"modified"};
	    if (!defined $a) { next;}
	    if (defined $users{$type}{$username}) {
		if (($users{$type}{$username}{"modified"} || "") eq $a) {
		    delete $users{$type}{$username}{"modified"};
		}
		# org_user map must be also removed (e.g. for multiple renames)
		if (defined $users{$type}{$username}{"org_user"}) {
		    delete $users{$type}{$username}{"org_user"};
		}
	    }
	}
    }
}

# see UpdateUsersAfterWrite
BEGIN { $TYPEINFO{UpdateGroupsAfterWrite} = ["function", "void", "string"]; }
sub UpdateGroupsAfterWrite {

    my $self	= shift;
    my $type	= shift;

    if (ref ($modified_groups{$type}) eq "HASH") {
        foreach my $groupname (keys %{$modified_groups{$type}}) {
	    my $a = $modified_groups{$type}{$groupname}{"modified"};
	    if (!defined $a) { next;}
	    if (defined $groups{$type}{$groupname}) {
		if (($groups{$type}{$groupname}{"modified"} || "") eq $a) {
		    delete $groups{$type}{$groupname}{"modified"};
		}
		# org_group map must be also removed (e.g. for multiple renames)
		if (defined $groups{$type}{$groupname}{"org_group"}) {
		    delete $groups{$type}{$groupname}{"org_group"};
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

# Internal function: get the warning message generated by plugin (if any)
# and show it to the user
# Takes the output of plugin call as a paramerer and returns this map,
# possibly modified (removed/added information about the warnings)
sub ShowPluginWarning {

    my $result	= shift;

    if (ref ($result) eq "HASH") {
	foreach my $plugin (keys %{$result}) {
	    my $data	= $result->{$plugin};
	    next if ref ($data) ne "HASH";
	    my $warning	= $data->{"warning_message"};
	    if (defined $warning && $warning ne "") {
		Report->Message ($warning) if $use_gui;
		my $id = $data->{"warning_message_ID"};
		if (defined $id && $id ne "") {
		    if (! defined ($data->{"confirmed_warnings"}) ||
			ref ($data->{"confirmed_warnings"}) ne "HASH") {
			$data->{"confirmed_warnings"}	= {};
		    }
		    $data->{"confirmed_warnings"}{$id}	= 1;
		    delete $data->{"warning_message_ID"};
		}
		delete $data->{"warning_message"};
	    }
	}
    }
    return $result;
}

##------------------------------------
BEGIN { $TYPEINFO{Write} = ["function", "string"]; }
sub Write {

    my $self		= shift;
    my $ret		= "";
    my $nscd_passwd	= 0;
    my $nscd_group	= 0;
    my @useradd_postcommands	= ();
    my @groupadd_postcommands	= ();

    my $umask		= $self->GetUmask ();

    # progress caption
    my $caption 	= __("Writing User and Group Configuration");
    my $no_of_steps 	= 8;

    return $ret if (Stage->cont () && !$self->Modified ());

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

	    # only remember for which users we need to call cryptconfig
	    foreach my $username (keys %{$modified_users{"ldap"}}) {
		my %user	= %{$modified_users{"ldap"}{$username}};
	    }
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
            $ret = sprintf (__("File %s was not read correctly, so it will not be written."), $base_directory."/group");
	    Report->Error ($ret);
	    return $ret;
	}
	# -------------------------------------- call WriteBefore on plugins
        foreach my $type (keys %modified_groups)  {
	    if ($type eq "ldap") { next; }
	    foreach my $groupname (keys %{$modified_groups{$type}}) {
		if ($plugin_error) { last;}
		my $args	= {
	    	    "what"	=> "group",
		    "type"	=> $type,
		    "modified"	=> $modified_groups{$type}{$groupname}{"modified"}
		};
		my $result = UsersPlugins->Apply ("WriteBefore", $args,
		    $modified_groups{$type}{$groupname});
		$plugin_error	= GetPluginError ($args, $result);
	    }
	}
	# -------------------------------------- write /etc/group
        if ($plugin_error eq "" && ! WriteGroup ()) {
            $ret = Message->ErrorWritingFile ("$base_directory/group");
	    Report->Error ($ret);
	    return $ret;
        }
	if (!$write_only) {
	    $nscd_group		= 1;
	}
    }

    # Check for deleted users
    if ($use_gui) { Progress->NextStage (); }

    if ($users_modified) {
        if (!PreDeleteUsers ()) {
       	    # error popup
	    $ret = __("An error occurred while removing users.");
	    Report->Error ($ret);
	    return $ret;
	}
    }

    # Write users
    if ($use_gui) { Progress->NextStage (); }


    if ($users_modified) {
	if ($passwd_not_read) {
	    # error popup (%s is a file name)
            $ret = sprintf (__("File %s was not correctly read, so it will not be written."), $base_directory."/passwd");
	    Report->Error ($ret);
	    return $ret;
	}
	# -------------------------------------- call WriteBefore on plugins
        foreach my $type (keys %modified_users)  {
	    if ($type eq "ldap") { next; }
	    foreach my $username (keys %{$modified_users{$type}}) {
		if ($plugin_error) { last;}
		my $args	= {
	    	    "what"	=> "user",
		    "type"	=> $type,
		    "modified"	=> $modified_users{$type}{$username}{"modified"}
		};
		my $result = UsersPlugins->Apply ("WriteBefore", $args,
		    $modified_users{$type}{$username});
		$plugin_error	= GetPluginError ($args, $result);
	    }
	}
	# remove the crypted directories now, so cryptconfig still knows them
        if (!DeleteCryptedHomes ()) {
       	    # error popup
	    $ret = __("An error occurred while removing users.");
	    Report->Error ($ret);
	    return $ret;
	}
	# -------------------------------------- write /etc/passwd
        if ($plugin_error eq "" && !WritePasswd ()) {
            $ret = Message->ErrorWritingFile ("$base_directory/passwd");
	    Report->Error ($ret);
	    return $ret;
	}
	if (!$write_only) {
	    $nscd_passwd	= 1;
	}

	# check for homedir changes,
	# and while going through modified users, log what was done to the user log (y2usernote)
        foreach my $type (keys %modified_users)  {
	    if ($type eq "ldap") {
		next; #rest of work with homes for LDAP are ruled in WriteLDAP
	    }
	    foreach my $username (keys %{$modified_users{$type}}) {
	    
		my %user	= %{$modified_users{$type}{$username}};
		my $home 	= $user{"homeDirectory"} || "";
		my $uid		= $user{"uidNumber"} || 0;
		my $command 	= "";
		my $user_mod 	= $user{"modified"} || "no";
		my $gid 	= $user{"gidNumber"};
		my $create_home	= $user{"create_home"};
		my $chown_home	= $user{"chown_home"};
		$chown_home	= 1 if (!defined $chown_home);
		my $skel	= $useradd_defaults{"skel"};
		if ($user_mod eq "imported" || $user_mod eq "added") {

		    y2usernote ("User '$username' created");

		    if ($user_mod eq "imported" && FileUtils->Exists ($home)) {
			y2milestone ("home directory $home of user $username already exists");
			next;
		    }
		    if (bool ($user{"no_skeleton"})) {
			$skel 	= "";
		    }
		    if ((bool ($create_home) || $user_mod eq "imported")
			&& !%{SCR->Read (".target.stat", $home)})
		    {
			UsersRoutines->CreateHome ($skel, $home);
		    }
		    if ($home ne "/var/lib/nobody" && bool ($chown_home)) {
			if (UsersRoutines->ChownHome ($uid, $gid, $home))
			{
			    my $mode = 777 - String->CutZeros ($umask);
			    if (defined ($user{"home_mode"})) {
				$mode	= $user{"home_mode"};
			    }
			    UsersRoutines->ChmodHome($home, $mode);
			    # Write authorized keys to user's home (FATE#319471)
			    SSHAuthorizedKeys->write_keys($home);
			}
		    }
		    Syslog->Log ("User added by YaST: name=$username, uid=$uid, gid=$gid, home=$home");
		    if ($useradd_cmd ne "" && FileUtils->Exists ($useradd_cmd))
		    {
			$command = sprintf ("%s %s", $useradd_cmd, $username);
			push @useradd_postcommands, $command;
		    }
		}
		if ($user_mod eq "edited") {
		    my $org_username	= $user{"org_user"}{"uid"} || $username;
		    if ($username ne $org_username) {
			y2usernote ("User '$org_username' renamed to '$username'");
		    }
		    else {
			y2usernote ("User '$username' modified");
		    }
		}
		if ($user_mod eq "edited" && $home ne "/var/lib/nobody") {
		    my $org_home = $user{"org_user"}{"homeDirectory"} || $home;
		    my $org_uid = $uid;
		    $org_uid	= $user{"org_user"}{"uidNumber"} if (defined $user{"org_user"}{"uidNumber"});
		    my $org_gid = $gid;
		    if (defined $user{"org_user"}{"gidNumber"}) {
			$org_gid = $user{"org_user"}{"gidNumber"};
		    }
		    # this would be actually caused by group modification
		    elsif (defined $user{"org_gidNumber"}) {
			$org_gid = $user{"org_gidNumber"};
		    }
		    # chown only when directory was changed (#39417)
		    if ($home ne $org_home || $uid ne $org_uid || $gid ne $org_gid) {
			# move the home directory
			if (bool ($create_home)) {
			    UsersRoutines->MoveHome ($org_home, $home);
			}
			# create new home directory
			elsif (not %{SCR->Read (".target.stat", $home)}) {
			    UsersRoutines->CreateHome ($skel, $home);
			}
			# do not change root's ownership of home directories
			if (bool ($chown_home))
			{
			    UsersRoutines->ChownHome ($uid, $gid, $home);
			}
		    }
		}
	    }
	}
    }

    if (Mode->autoinst() || Mode->autoupgrade() || Mode->config()) { WriteAuthorizedKeys(); }

    # Write passwords
    if ($use_gui) { Progress->NextStage (); }

    if ($users_modified) {
	if ($shadow_not_read) {
	    # error popup (%s is a file name)
            $ret = sprintf (__("File %s was not correctly read, so it will not be written."), $base_directory."/shadow");
	    Report->Error ($ret);
	    return $ret;
 	}
        if (! WriteShadow ()) {
            $ret = Message->ErrorWritingFile ("$base_directory/shadow");
	    Report->Error ($ret);
	    return $ret;
        }
    }

    # remove the passwd cache for nscd (bug 24748, 41648)
    if (!$write_only && Package->Installed ("nscd")) {
	if ($nscd_passwd) {
	    my $cmd	= "/usr/sbin/nscd -i passwd";
	    SCR->Execute (".target.bash", $cmd);
	    y2usernote ("nscd cache invalidated: '$cmd'");
	}
	if ($nscd_group) {
	    my $cmd	= "/usr/sbin/nscd -i group";
	    SCR->Execute (".target.bash", $cmd);
	    y2usernote ("nscd cache invalidated: '$cmd'");
	}
    }

    # last operation on plugins must be done after nscd restart
    # (at least quota seems to need it)
    if ($users_modified) {
	# -------------------------------------- call Write on plugins
        foreach my $type (keys %modified_users)  {
	    if ($type eq "ldap") { next; }
	    foreach my $username (keys %{$modified_users{$type}}) {
		if ($plugin_error) { last;}
		my $args	= {
	    	    "what"	=> "user",
		    "type"	=> $type,
		    "modified"	=> $modified_users{$type}{$username}{"modified"}
		};
		my $result = UsersPlugins->Apply ("Write", $args,
		    $modified_users{$type}{$username});
		$plugin_error	= GetPluginError ($args, $result);
	    }
	}
	if ($plugin_error) {
	    Report->Error ($plugin_error);
	    return $plugin_error;
	}
	# unset the 'modified' flags after write
	$self->UpdateUsersAfterWrite ("local");
	$self->UpdateUsersAfterWrite ("system");
	# not modified after successful write
	delete $modified_users{"local"};
	delete $modified_users{"system"};
    }
    if ($groups_modified) {
	# -------------------------------------- call Write on plugins,
	# (+do some other work while looping over groups)
        foreach my $type (keys %modified_groups)  {
	    if ($type eq "ldap") { next; }
	    foreach my $groupname (keys %{$modified_groups{$type}}) {
		if ($plugin_error) { last;}
		my $args	= {
	    	    "what"	=> "group",
		    "type"	=> $type,
		    "modified"	=> $modified_groups{$type}{$groupname}{"modified"}
		};
		my $result = UsersPlugins->Apply ("Write", $args,
		    $modified_groups{$type}{$groupname});
		$plugin_error	= GetPluginError ($args, $result);
		
		my $group	= $modified_groups{$type}{$groupname};
		my $mod 	= $group->{"modified"} || "no";

		# store commands for calling groupadd_cmd script
		if ($groupadd_cmd ne "" && FileUtils->Exists ($groupadd_cmd)) {
		    if ($mod eq "imported" || $mod eq "added") {
			my $cmd = sprintf ("%s %s", $groupadd_cmd, $groupname);
			push @groupadd_postcommands, $cmd;
		    }
		}
		# now, log what was done to current modified group
		if ($mod eq "imported" || $mod eq "added") {
		    y2usernote ("Group '$groupname' created");
		}
		elsif ($mod eq "edited") {
		    my $org_groupname	= $group->{"org_group"}{"cn"} || $groupname;
		    if ($groupname ne $org_groupname) {
			y2usernote ("Group '$org_groupname' renamed to '$groupname'");
		    }
		    else {
			y2usernote ("Group '$groupname' modified");
		    }
		}
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
    }

    # call make on NIS server
    if (($users_modified || $groups_modified) && $nis_master) {
	my $cmd	= "/usr/bin/make -C /var/yp";
        my %out	= %{SCR->Execute (".target.bash_output", $cmd)};
        if (!defined ($out{"exit"}) || $out{"exit"} != 0) {
            y2error ("Cannot make NIS database: ", %out);
        }
	else {
	    y2usernote ("NIS server database rebuilt: '$cmd'");
	}
    }

    # complete adding groups
    if ($groups_modified && @groupadd_postcommands > 0) {
	foreach my $command (@groupadd_postcommands) {
	    y2milestone ("'$command' returns: ", 
		SCR->Execute (".target.bash", $command));
	    y2usernote ("Group post-add script called: '$command'");
	    Syslog->Log ("GROUPADD_CMD command called by YaST: $command");
	}
    }

    # complete adding users
    if ($users_modified && @useradd_postcommands > 0) {
	foreach my $command (@useradd_postcommands) {
	    y2milestone ("'$command' returns: ", 
		SCR->Execute (".target.bash", $command));
	    y2usernote ("User post-add script called: '$command'");
	    Syslog->Log ("USERADD_CMD command called by YaST: $command");
	}
    }

    # complete deleting of users
    if ($users_modified) {
        if (!PostDeleteUsers ()) {
	    # error popup
	    $ret = __("An error occurred while removing users.");
	    Report->Error ($ret);
	    return $ret;
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
	WriteSecurity();
    }
    if ($sysconfig_ldap_modified) {
        SCR->Write (".sysconfig.ldap.FILE_SERVER", Ldap->file_server? "yes": "no");
        SCR->Write (".sysconfig.ldap", undef);
    }

    my @new_aliases	= sort (keys %root_aliases);
    my @old_aliases	= sort (keys %root_aliases_orig);

    # mail forward from root
    if (!same_arrays (\@new_aliases, \@old_aliases)) {
	$root_mail	= join (", ", keys %root_aliases);
	if (!MailAliases->SetRootAlias ($root_mail)) {
        
	    # error popup
	    $ret = __("An error occurred while setting forwarding for root's mail.");
	    Report->Error ($ret);
	    return $ret;
	}
	else {
          SCR->Execute (".target.bash", "/usr/sbin/config.postfix");
	}
    }

    Autologin->Write (Stage->cont () || $write_only);

    # do not show user in first dialog when all has been writen
    if (Stage->cont ()) {
        $use_next_time	= 0;
        undef %saved_user;
        undef %user_in_work;
    }

    if (Stage->firstboot () && $save_root_password) {
	$self->WriteRootPassword ();
	$save_root_password	= 0;
    }

    $users_modified	= 0;
    $groups_modified	= 0;

    return $ret;
}

##-------------------------------------------------------------------------
##----------------- check routines ----------------------------------------

##------------------------------------
BEGIN { $TYPEINFO{ValidLognameChars} = ["function", "string"]; }
sub ValidLognameChars {
    return UsersSimple->ValidLognameChars ();
}

##------------------------------------
BEGIN { $TYPEINFO{ValidPasswordChars} = ["function", "string"]; }
sub ValidPasswordChars {
    return UsersSimple->ValidPasswordChars ();
}

##------------------------------------
BEGIN { $TYPEINFO{ValidHomeChars} = ["function", "string"]; }
sub ValidHomeChars {
    return UsersSimple->ValidHomeChars ();
}

##------------------------------------
BEGIN { $TYPEINFO{ValidPasswordMessage} = ["function", "string"]; }
sub ValidPasswordMessage {
    return UsersSimple->ValidPasswordMessage ();
}

##------------------------------------
# Return the part of help text about valid password characters
BEGIN { $TYPEINFO{ValidPasswordHelptext} = ["function", "string"]; }
sub ValidPasswordHelptext {
    return UsersSimple->ValidPasswordHelptext ();
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
	return __("No UID is available for this type of user.");
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
    "integer", ["map", "string", "any"]];
}
sub CheckUIDUI {

    my $self	= shift;
    my $uid	= $_[0];
    my %ui_map	= %{$_[1]};
    my $type	= UsersCache->GetUserType ();
    my %ret	= ();

    if (($ui_map{"duplicated_uid"} || -1) != $uid) {
	if (
	   (("add_user" eq ($user_in_work{"what"} || "")) 	||
	    ($uid != ($user_in_work{"uidNumber"} || 0))		||
	    (defined $user_in_work{"org_uidNumber"} 	&& 
		     $user_in_work{"org_uidNumber"} != $uid))	&&
	    UsersCache->UIDExists ($uid))
	{
	    
	    $ret{"question_id"} =	"duplicated_uid";
	    # popup question
	    $ret{"question"}    =	__("The user ID entered is already in use.
Really use it?");
	    return \%ret;
	}
    }

    if (($ui_map{"ldap_range"} || -1) != $uid) {
	if ($type eq "ldap" &&
	    $uid < UsersCache->GetMinUID ("ldap"))
	{
	    $ret{"question_id"}	= "ldap_range";
	    $ret{"question"}	= sprintf(
# popup question, %i are numbers
__("The selected user ID is not from a range
defined for LDAP users (%i-%i).
Really use it?"),
		UsersCache->GetMinUID ("ldap"), UsersCache->GetMaxUID ("ldap"));
	    return \%ret;
	}
    }

    if (($ui_map{"local"} || -1) != $uid) {
	if ($type eq "system" &&
	    $uid > UsersCache->GetMinUID ("local") &&
	    $uid < UsersCache->GetMaxUID ("local") + 1)
	{
	    $ret{"question_id"}	= "local";
	    # popup question
	    $ret{"question"}	= sprintf(__("The selected user ID is a local ID,
because the ID is greater than %i.
Really change the user type to 'local'?"), UsersCache->GetMinUID ("local"));
	    return \%ret;
	}
    }

    if (($ui_map{"system"} || -1) != $uid) {
	if ($type eq "local" &&
	    $uid > UsersCache->GetMinUID ("system") &&
	    $uid < UsersCache->GetMaxUID ("system") + 1)
	{
	    $ret{"question_id"}	= "system";
	    # popup question
	    $ret{"question"}	= sprintf (__("The selected user ID is a system ID,
because the ID is smaller than %i.
Really change the user type to 'system'?"), UsersCache->GetMaxUID ("system") + 1);
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
    my $type		= $user_in_work{"type"} || "";

    my $ret		= UsersSimple->CheckUsernameLength ($username);
    return $ret if $ret;

    $ret		= UsersSimple->CheckUsernameContents ($username, $type);
    return $ret if $ret;

    if (("add_user" eq ($user_in_work{"what"} || "")) ||
	($username ne ($user_in_work{"uid"} || "")) ||
	(defined $user_in_work{"org_uid"} && 
		 $user_in_work{"org_uid"} ne $username)) {

	if (UsersCache->UsernameExists ($username)) {
	    # additional sentence for error popup
	    my $more	= (($self->NISAvailable () || $self->LDAPAvailable ()) &&
		($type eq "local" || $type eq "system")) ? __("
The existing username might belong to a NIS or LDAP user.
") : "";
	    # error popup, %1 might be additional sentence ("The existing username...")
	    return sformat (__("There is a conflict between the entered
username and an existing username. %1
Try another one."), $more);
	}
    }
    return "";
}

##------------------------------------
# check fullname contents
BEGIN { $TYPEINFO{CheckFullname} = ["function", "string", "string"]; }
sub CheckFullname {

    my ($self, $fullname)        = @_;
    return UsersSimple->CheckFullname ($fullname);
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
    my $valid_home_chars= $self->ValidHomeChars ();
    $filtered 		=~ s/$valid_home_chars//g;

    if ($filtered ne "" || $first ne "/" || $home =~ m/\/\./) {
	# error popup
        return __("The home directory may only contain the following characters:
a-z, A-Z, 0-9, and _-/
Try again.");
    }

    my $modified	= 
	(($user_in_work{"what"} || "") eq "add_user")		||
	($home ne ($user_in_work{"homeDirectory"} || "")) 	||
	(defined $user_in_work{"org_homeDirectory"} && 
		 $user_in_work{"org_homeDirectory"} ne $home);

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
	return __("The home directory is used by another user.
Try again.");
    }
    return "";
}

##------------------------------------
# check the home directory of current user - part 2
BEGIN { $TYPEINFO{CheckHomeUI} = ["function",
    ["map", "string", "string"],
    "integer", "string", ["map", "string", "any"]];
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
    
    if ((($ui_map{"not_dir"} || "") ne $home)	&&
	%stat && !($stat{"isdir"} || 0))	{

	$ret{"question_id"}	= "not_dir";
	# yes/no popup: user seleceted something strange as a home directory
	$ret{"question"}	= __("The path for the selected home directory already exists,
but it is not a directory.
Really use this path?");
	return \%ret;
    }

    if ((($ui_map{"chown"} || "") ne $home) &&
	%stat && ($stat{"isdir"} || 0))	{
        
	$ret{"question_id"}	= "chown";
	# yes/no popup
	$ret{"question"}	= __("The home directory selected already exists.
Use it and change its owner?");

	my $dir_uid	= $stat{"uidNumber"} || 0;
                    
	if ($uid == $dir_uid) { # chown is not needed (#25200)
	    # yes/no popup
	    $ret{"question"}	= sprintf (__("The selected home directory (%s)
already exists and is owned by the currently edited user.
Use this directory?
"), $home);
	    $ret{"owned"}	= 1;
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
    "string", ["map", "string", "any"]];
}
sub CheckShellUI {

    my $self	= shift;
    my $shell	= $_[0];
    my %ui_map	= %{$_[1]};
    my %ret	= ();

    if (($ui_map{"shell"} || "") ne $shell &&
	($user_in_work{"loginShell"} || "") ne $shell ) {

	if (!defined ($all_shells{$shell})) {
	    $ret{"question_id"}	= "shell";
	    # popup question
	    $ret{"question"}	= __("If you select a nonexistent shell, the user may be unable to log in.
Use this shell?");
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
	return __("No GID is available for this type of group.");
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
    "integer", ["map", "string", "any"]];
}
sub CheckGIDUI {

    my $self	= shift;
    my $gid	= $_[0];
    my %ui_map	= %{$_[1]};
    my $type	= UsersCache->GetGroupType ();
    my %ret	= ();

    if (($ui_map{"duplicated_gid"} || -1) != $gid) {
	if ((
	    ("add_group" eq ($group_in_work{"what"} || "")) 	||
	    ($gid != ($group_in_work{"gidNumber"} || 0))	||
	    (defined $group_in_work{"org_gidNumber"} && 
		     $group_in_work{"org_gidNumber"} != $gid)) 	&&
	    UsersCache->GIDExists ($gid))
	{
	    $ret{"question_id"} = "duplicated_gid";
	    # popup question
	    $ret{"question"}	= __("The group ID entered is already in use.
Really use it?");
	}
    }

    if (($ui_map{"ldap_range"} || -1) != $gid) {
	if ($type eq "ldap" &&
	    $gid < UsersCache->GetMinGID ("ldap"))
	{
	    $ret{"question_id"}	= "ldap_range";
	    $ret{"question"}	= sprintf(
# popup question, %i are numbers
__("The selected group ID is not from a range
defined for LDAP groups (%i-%i).
Really use it?"),
		UsersCache->GetMinGID ("ldap"), UsersCache->GetMaxGID ("ldap"));
	    return \%ret;
	}
    }

    if (($ui_map{"local"} || -1) != $gid) {
	if ($type eq "system" &&
	    $gid > UsersCache->GetMinGID ("local") &&
	    $gid < UsersCache->GetMaxGID ("local"))
	{
	    $ret{"question_id"}	= "local";
	    # popup question
	    $ret{"question"}	= sprintf (__("The selected group ID is a local ID,
because the ID is greater than %i.
Really change the group type to 'local'?"), UsersCache->GetMinGID ("local"));
	    return \%ret;
	}
    }

    if (($ui_map{"system"} || -1) != $gid) {
	if ($type eq "local" &&
	    $gid > UsersCache->GetMinGID ("system") &&
	    $gid < UsersCache->GetMaxGID ("system"))
	{
	    $ret{"question_id"}	= "system";
	    # popup question
	    $ret{"question"}	= sprintf(__("The selected group ID is a system ID,
because the ID is smaller than %i.
Really change the group type to 'system'?"), UsersCache->GetMaxGID ("system"));
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
        return __("No group name entered.
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

    my $grep = SCR->Execute (".target.bash_output", "echo '$filtered' | grep '\^$character_class\$'", { "LANG" => "C" });

    my $stdout = $grep->{"stdout"} || "";
    $stdout =~ s/\n//g;
    if ($stdout ne $filtered) {
	y2warning ("groupname $groupname doesn't match to $character_class");
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

    my $error	= $self->CheckUID ($user{"uidNumber"});

    if ($error eq "") {
	$error	= $self->CheckUsername ($user{"uid"});
    }

    if ($error eq "") {
        # Check password only if:
        # * It's defined or we're adding a user
        # * AND password is not encrypted (it means that password was changed)
	if ((defined ($user{"userPassword"}) ||
	    ($user{"what"} || "") eq "add_user") && (!$user{"encrypted"})) {
	    $error = UsersSimple->CheckPassword ($user{"userPassword"}, $type);
	}
    }
    
    if ($error eq "") {
	$error	= $self->CheckHome ($user{"homeDirectory"});
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

    my $type	= $group{"type"} || "";

    my $error = $self->CheckGID ($group{"gidNumber"});

    if ($error eq "") {
	if ((defined $group{"userPassword"}) && ! bool ($group{"encrypted"})) {
	    $error = UsersSimple->CheckPassword ($group{"userPassword"}, $type);
	}
    }

    if ($error eq "") {
	$error = $self->CheckGroupname ($group{"cn"});
    }

    if ($error eq "") {
	my %userlist	= ();
	if (defined $group{"userlist"}) {
	    %userlist	= %{$group{"userlist"}};
	}
	foreach my $user (keys %userlist) {
	    my %u = %{$self->GetUserByName ($user, "")};
	    $error = sprintf (__("User %s does not exist."), $user) unless %u;
	}
    }
    my $error_map	=
	UsersPlugins->Apply ("Check", {
	    "what"	=> "group",
	    "type"	=> $type,
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
    }
    UsersSimple->SetEncryptionMethod ($_[0]);
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
# crypt given password; parameters: 1.password 2.type (local etc.) 3.user/group
BEGIN { $TYPEINFO{CryptPassword} = ["function",
    "string",
    "string", "string", "string"];
}
sub CryptPassword {

    my $self	= shift;
    my $pw	= shift;
    my $type	= shift;
    my $what	= shift;
    my $method	= lc ($encryption_method);
    if (defined $what && $what eq "group") {
	$method = lc ($group_encryption_method);
    }
    
    if (!defined $pw) {
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
    Syslog->Log ("Root password changed by YaST");
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
    if (! FileUtils->Exists ("/usr/lib/yp/yphelper")) {
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
		return (Package->Installed ("ypbind") && Service->Status ("ypbind") == 0);
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
# During autoinstallation/config mode, system groups are loaded from the disk
# and the userlists of these groups can contain the local users,
# which we don not want to Import. So they are removed here.
# @param disk_groups the groups loaded from local disk
sub RemoveDiskUsersFromGroups {

    my $disk_groups	= $_[0];
    foreach my $gid (keys %{$disk_groups}) {
	my $group	= $disk_groups->{$gid};
	
	foreach my $user (keys %{$group->{"userlist"}}) {
	    if (!defined ($users{"local"}{$user}) &&
		!defined ($users{"system"}{$user}))
	    {
		delete $disk_groups->{$gid}{"userlist"}{$user};
	    }
	}
	foreach my $user (keys %{$group->{"more_users"}}) {
	    if (!defined ($users{"local"}{$user}) &&
		!defined ($users{"system"}{$user}))
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

    my $uid		= $user->{"uidNumber"};
    if (!defined $uid) {
	$uid            = $user->{"uidnumber"};
	$uid		= $user->{"uid"} if (!defined $uid);
	$uid		= -1 if (!defined $uid);
    }
    my $gid		= $user->{"gidNumber"};
    if (!defined $gid) {
	$gid            = $user->{"gidnumber"};
	$gid		= $user->{"gid"} if (!defined $gid);
	$gid		= -1 if (!defined $gid);
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
	($uid <= UsersCache->GetMaxUID ("system") || $username eq "nobody")) {
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
    my $pass		= $user->{"user_password"};
    if ((!defined $encrypted || !bool ($encrypted)) &&
	(defined $pass) && !Mode->config ())
    {
	$pass 		= $self->CryptPassword ($pass, $type);
	$encrypted	= YaST::YCP::Boolean (1);
    }
    my $home	= $self->GetDefaultHome($type).$username;

    if ($uid == 0) {
	#user "root" has default home directory "/root"
	$home = "/root";
    }

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

    if ($uid == -1 || Stage->initial()) {
	# Check for existence of this user (and change it with given values).
	# During 1st stage we simply match by username (bnc#965852).
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
	    if (defined $pass) {
		$finalpw 	= $pass;
	    }
	    else {
		$finalpw 	= $existing{"userPassword"};
	    }

	    if (!defined $user->{"forename"} && !defined $user->{"surname"} &&
		$cn eq "") {
		$cn		= $existing{"cn"} || "";
	    }
	    if ($gid == -1 || Stage->initial()) {
		$gid		= $existing{"gidNumber"};
	    }
	    %ret	= (
		"userPassword"	=> $finalpw,
		"grouplist"	=> \%grouplist,
		"uid"		=> $username,
		"encrypted"	=> $encrypted,
		"cn"		=> $cn,
		"uidNumber"	=> $existing{"uidNumber"},
		"loginShell"	=> $user->{"shell"} || $user->{"loginShell"} || $existing{"loginShell"} || $self->GetDefaultShell ($type),

		"gidNumber"	=> $gid,
		"homeDirectory"	=> $user->{"homeDirectory"} || $user->{"home"} || $existing{"homeDirectory"} || $home,
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
	"userPassword"	=> $pass,
	"cn"		=> $cn,
	"uidNumber"	=> $uid,
	"gidNumber"	=> $gid,
	"loginShell"	=> $user->{"shell"} || $user->{"loginShell"} || $self->GetDefaultShell ($type),

	"grouplist"	=> \%grouplist,
	"homeDirectory"	=> $user->{"homeDirectory"} || $user->{"home"} || $home,
	"type"		=> $type,
	"modified"	=> "imported"
	);
    }
    my %translated = (
	"inact"		=> "shadowInactive",
	"expire"	=> "shadowExpire",
	"warn"		=> "shadowWarning",
	"min"		=> "shadowMin",
        "max"		=> "shadowMax",
        "flag"		=> "shadowFlag",
	"last_change"	=> "shadowLastChange",
	"password"	=> "userPassword",
	"shadowinactive"=> "shadowInactive",
	"shadowexpire"	=> "shadowExpire",
	"shadowwarning"	=> "shadowWarning",
	"shadowmin"	=> "shadowMin",
        "shadowmax"	=> "shadowMax",
        "shadowflag"	=> "shadowFlag",
	"shadowlastchange"	=> "shadowLastChange",
	"userpassword"	=> "userPassword",
    );
    foreach my $key (keys %user_shadow) {
	my $new_key	= $translated{$key} || $key;
	if ($key eq "userPassword") { next; }
	$ret{$new_key}	= $user_shadow{$key};
    }
    if (!defined $ret{"shadowLastChange"} ||
	$ret{"shadowLastChange"} eq "") {
	$ret{"shadowLastChange"}	= LastChangeIsNow ();
    }

    # Import authorized keys from profile (FATE#319471)
    if ($user->{"authorized_keys"} && $ret{"homeDirectory"}) {
      SSHAuthorizedKeys->import_keys($ret{"homeDirectory"}, $user->{"authorized_keys"});
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

    my $gid		= $group{"gidNumber"};
    if (!defined $gid) {
	$gid		= $group{"gidnumber"};
	$gid		= $group{"gid"} if (!defined $gid);
	$gid		= -1 if (!defined $gid);
    }
    if ($gid == -1 || Stage->initial()) {
	# Check for existence of this group (and change it with given values).
	# During 1st stage we simply match by groupname (bnc#965852).
	my $existing 	= $self->GetGroupByName ($groupname, "");
	if (ref ($existing) eq "HASH" && %{$existing}) {
	    $gid	= $existing->{"gidNumber"};
	    $type       = $existing->{"type"} || $type;
	}
    }
    elsif (($gid <= UsersCache->GetMaxGID ("system") ||
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
    my $encrypted	= $group{"encrypted"};
    $encrypted		= YaST::YCP::Boolean (1) if !defined $encrypted;
    if (defined $encrypted && ref ($encrypted) ne "YaST::YCP::Boolean") {
	$encrypted	= YaST::YCP::Boolean ($encrypted);
    }
    my $pass		= $group{"group_password"};
    if ((!defined $encrypted || !bool ($encrypted)) &&
	(defined $pass) && !Mode->config ())
    {
	$pass 		= $self->CryptPassword ($pass, $type);
	$encrypted	= YaST::YCP::Boolean (1);
    }

    my %ret		= (
	"userPassword"	=> $pass,
	"encrypted"	=> $encrypted,
        "cn"		=> $groupname,
        "gidNumber"	=> $gid,
        "userlist"	=> \%userlist,
        "modified"	=> "imported",
        "type"		=> $type
    );
    return \%ret;
}

##------------------------------------
# Initialize settings for config mode (see bug #44660)
BEGIN { $TYPEINFO{Initialize} = ["function", "boolean" ];}
sub Initialize {

    my $self		= shift;

    $self->ReadLoginDefaults ();
    $self->ReadSystemDefaults(1);

    my $error_msg = $self->ReadLocal ();
    if ($error_msg) {
	return 0;
    }

    $shadow{"local"}			= {};
    $users{"local"}			= {};
    $users_by_uidnumber{"local"}	= {};

    RemoveDiskUsersFromGroups ($groups{"system"});

    my %group_users	= %{$groups{"local"}{"users"}};
    $groups{"local"}			= {};
    $groups_by_gidnumber{"local"}	= {};
    if (%group_users) {
	$groups{"local"}{"users"}	= \%group_users;
	my $gid	= $group_users{"gidNumber"};
	$groups_by_gidnumber{"local"}{$gid}	= { "users" => 1 };
	RemoveDiskUsersFromGroups ($groups{"local"});
    }

    @available_usersets		= ( "local", "system", "custom" );
    @available_groupsets	= ( "local", "system", "custom" );

    $self->ReadAllShells ();

    # initialize UsersCache:
    UsersCache->ReadUsers ("system");
    UsersCache->ReadGroups ("system");

    UsersCache->BuildUserItemList ("system", $users{"system"});
    UsersCache->BuildGroupItemList ("system", $groups{"system"});

    UsersCache->BuildUserItemList ("local", $users{"local"});
    UsersCache->BuildGroupItemList ("local", $groups{"local"});

    @user_custom_sets	= ("local", "system");
    @group_custom_sets	= ("local", "system");
        
    UsersCache->SetCurrentUsers (\@user_custom_sets);
    UsersCache->SetCurrentGroups (\@group_custom_sets);

    return 1;
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
        # if no_groups key is specifed, use no secondary groups
        if ($useradd_defaults{"no_groups"} || 0) {
          delete $useradd_defaults{"no_groups"};
          $useradd_defaults{"groups"}   = "";
        }
        $defaults_modified	= 1;
    }
    if (defined $settings{"login_settings"} &&
	ref ($settings{"login_settings"}) eq "HASH")
    {
	my $autologin	= $settings{"login_settings"};
	my $auto_user	= $autologin->{"autologin_user"} || "";
	if ($auto_user) {
	    Autologin->Use (1);
	    Autologin->user ($auto_user);
	}
	if (defined $autologin->{"password_less_login"}) {
	    Autologin->pw_less ($autologin->{"password_less_login"});
	}
    }

    $self->ReadSystemDefaults(1);

    # remove cache entries (#50265)
    UsersCache->ResetCache ();

    my $error_msg = Mode->test() ? "" : $self->ReadLocal ();
    if ($error_msg) {
	return 0;
    }

    if (Mode->config ()) {
	
	$shadow{"local"}		= {};
	$users{"local"}			= {};
	$users_by_uidnumber{"local"}	= {};
    }

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
	    my $uid 		= $user{"uidNumber"};
	    if (!defined $uid || $uid == -1) {
		delete $user{"uidNumber"};
		push @without_uid, \%user;
	    }
	    else {
		$users{$type}{$username}		= \%user;
		if (!defined $users_by_uidnumber{$type}{$uid}) {
		    $users_by_uidnumber{$type}{$uid} 	= {};
		}
		$users_by_uidnumber{$type}{$uid}{$username}	= 1;
		$shadow{$type}{$username} = $self->CreateShadowMap (\%user);
		$modified_users{$type}{$username}	= \%user;
	    }
	}

	# there could be conflicts when adding new uses
	if (!Mode->config () && @without_uid > 0) {
	    y2milestone ("users imported: updating cache");
	    UsersCache->ReadUsers ("system");
	    UsersCache->ReadUsers ("local");
	}

	foreach my $user (@without_uid) {
	    y2milestone ("no UID for this user:", $user->{"uid"} || "");
	    $self->ResetCurrentUser ();
	    $self->AddUser ($user);
	    my $error = $self->CheckUser ($self->GetCurrentUser());
	    if ($error eq "") {
		$self->CommitUser ();
	    }
	    else {
		y2warning ("error adding new user: $error");
	    }
	}
    }

    # group users should be "local"
    if (defined $groups{"system"}{"users"}) {
	delete $groups{"system"}{"users"};
    }

    # we're not interested in local userlists...
    if (Mode->config ()) {
	RemoveDiskUsersFromGroups ($groups{"system"});
    }

    if (Mode->config ()) {
	$groups{"local"}		= {};
	$groups_by_gidnumber{"local"}	= {};
    }

    my @without_gid		= ();

    if (defined $settings{"groups"} && @{$settings{"groups"}} > 0) {

	foreach my $imp_group (@{$settings{"groups"}}) {
	    my %group	= %{$self->ImportGroup ($imp_group)};
	    my $gid 	= $group{"gidNumber"};
	    if (!defined $gid || $gid == -1) {
		delete $group{"gidNumber"};
		push @without_gid, \%group;
	    }
	    else {
		my $type			= $group{"type"} || "local";
		my $groupname 			= $group{"cn"} || "";
		$groups{$type}{$groupname}	= \%group;
		$modified_groups{$type}{$groupname}	= \%group;
		if (!defined $groups_by_gidnumber{$type}{$gid}) {
		    $groups_by_gidnumber{$type}{$gid} = {};
		}
		$groups_by_gidnumber{$type}{$gid}{$groupname}	= 1;
	    }
	}

	if (!Mode->config () && @without_gid > 0) {
	    y2milestone ("groups imported: updating cache");
	    UsersCache->ReadGroups ("system");
	    UsersCache->ReadGroups ("local");
	}

	foreach my $group (@without_gid) {
	    y2milestone ("no GID for this group:", $group->{"cn"} || "");
	    $self->ResetCurrentGroup ();
	    $self->AddGroup ($group);
	    my $error = $self->CheckGroup ($self->GetCurrentGroup());
	    if ($error eq "") {
		$self->CommitGroup ();
	    }
	    else {
		y2warning ("error adding new group: $error");
	    }
	}
    }

    my %group_u = %{$self->GetGroupByName ("users", "local")};
    if (!%group_u) {
        # group 'users' must be created
	my $gid		= $self->GetDefaultGID ("local");
        %group_u	= (
             "gidNumber"		=> $gid,
	     "cn"			=> "users",
	     "userPassword"		=> undef,
	     "userlist"			=> {},
	     "type"			=> "local"
	);
        $groups{"local"}{"users"}		= \%group_u;
	if (!defined $groups_by_gidnumber{"local"}{$gid}) {
	    $groups_by_gidnumber{"local"}{$gid} = {};
	}
	$groups_by_gidnumber{"local"}{$gid}{"users"}	= 1;
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

        foreach my $username (keys %{$users{$type}}) {

	    my $user		= $users{$type}{$username};
            my $uid 		= $user->{"uidNumber"}	|| 0;
            my $gid 		= $user->{"gidNumber"};
	    if (!defined $gid) {
		$gid		= $self->GetDefaultGID($type);
	    }
            $users{$type}{$username}{"grouplist"} = FindGroupsBelongUser ($user);

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
		    $users{$type}{$username}{"gidNumber"}	= $gid;
		}
	    }
	    if (defined $group{"cn"}) {
		my $groupname 				= $group{"cn"};
		$users{$type}{$username}{"groupname"}	= $groupname;

		# update the group's more_users
		if (!defined ($group{"more_users"}{$username})) {
		    my $gtype	= $group{"type"} || $type;
		    $groups{$gtype}{$groupname}{"more_users"}{$username}	= 1;
		}
            }
        }
    }
    # check if root password is set (bug #76404)
    if (Mode->autoinst ()) {
	my %root_user	= %{$self->GetUserByName ("root", "system")};
	if (%root_user && (($root_user{"userPassword"} || "") eq "")) {

	    my $pw = Linuxrc->InstallInf ("RootPassword");
	    if (defined $pw){
                # ensure that even if no user is defined, root will be written
                $users_modified	= 1;

		y2milestone ("updating root password from install.inf");
		$root_user{"userPassword"} = $self->CryptPassword ($pw, "system");
                # mark that password is already encrypted, so it does not encrypt twice (bsc#1081958)
		$root_user{"encrypted"} = 1;

		$users{"system"}{"root"}		= \%root_user;
		$shadow{"system"}{"root"} = $self->CreateShadowMap(\%root_user);
		$modified_users{"system"}{"root"}	= \%root_user;
	    }
	}
    }

    # initialize UsersCache: 1. system users and groups:
    UsersCache->ReadUsers ("system");
    UsersCache->ReadGroups ("system");

    if (!Mode->config ()) {
	UsersCache->ReadUsers ("local");
	UsersCache->ReadGroups ("local");
    }

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
	"shadowInactive"	=> "inact",
	"shadowExpire"		=> "expire",
	"shadowWarning"		=> "warn",
	"shadowMin"		=> "min",
        "shadowMax"		=> "max",
        "shadowFlag"		=> "flag",
	"shadowLastChange"	=> "last_change",
	"userPassword"		=> "password"
    );
    my %shadow_map	= %{$self->CreateShadowMap ($user)};
    my %org_user	= ();

    if (defined $user->{"org_user"} && $user->{"modified"} ne "added") {
	%org_user	= %{$user->{"org_user"}};
    }
    foreach my $key (keys %shadow_map) {
	my $new_key		= $translated{$key} || $key;
	# actual shadowlastchange must be created in Import
	if ($key eq "userPassword" || $key eq "shadowLastChange" ||
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
        "userPassword"	=> "user_password",
	"cn"		=> "fullname",
        "loginShell"	=> "shell",
        "uidNumber"	=> "uid",
        "gidNumber"	=> "gid",
        "homeDirectory"	=> "home"
    );
    foreach my $key (keys %exported_user) {
	if (defined $keys_to_export{$key}) {
	    my $new_key		= $keys_to_export{$key};
	    $ret{$new_key}	= $exported_user{$key} if defined ($exported_user{$key});
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
    if ($user->{"homeDirectory"}) {
        # Export authorized keys to profile (FATE#319471)
        my $keys = SSHAuthorizedKeys->export_keys($user->{"homeDirectory"});
        if (@$keys) {
            $ret{"authorized_keys"} = $keys;
        }
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
    if (($group->{"modified"} || "") ne "edited" ||
	(defined $group->{"org_group"} &&
	(defined $group->{"org_group"}{"gidNumber"} &&
	$group->{"gidNumber"} ne $group->{"org_group"}{"gidNumber"})
	||
	(defined $group->{"org_group"}{"cn"} &&
	$group->{"cn"} ne $group->{"org_group"}{"cn"}))
	)
    {
	$ret{"gid"}		= $group->{"gidNumber"};
    }
    if (defined $group->{"userPassword"}) {

    	my $encrypted	= bool ($group->{"encrypted"});
    	if (!defined $group->{"encrypted"}) {
	    $encrypted	= 1;
	}
	$ret{"encrypted"}	= YaST::YCP::Boolean ($encrypted);
	$ret{"group_password"}	= $group->{"userPassword"};
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

    my %ret	= (
        "users"		=> \@exported_users,
        "groups"	=> \@exported_groups,
        "user_defaults"	=> \%useradd_defaults
    );
    # special key for special case of no secondary groups (bnc#789635)
    if (($useradd_defaults{"groups"} || "") eq "") {
      $ret{"user_defaults"}{"no_groups"}        = YaST::YCP::Boolean (1);
    }
    if (Autologin->used ()) {
	my %autologin	= ();
	if (Autologin->pw_less ()) {
	    $autologin{"password_less_login"}	= YaST::YCP::Boolean (1);
	}
	$autologin{"autologin_user"}	= Autologin->user ();
	$ret{"login_settings"}	= \%autologin;
    }
    return \%ret;
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
	while (my ($username, $user) = each %{$users{$type}}) {
            if (defined $user->{"modified"}) {
                $ret .= sprintf (" %i $username %s<br>", $user->{"uidNumber"} || 0, $user->{"cn"} || "");
	    }
	}
    }
    # summary label
    $ret .= __("<h3>Groups</h3>");
    foreach my $type ("local", "system") {
	if (!defined $groups{$type}) { next; }
	while (my ($groupname, $group) = each %{$groups{$type}}) {
            if (defined $group->{"modified"}) {
                $ret .= sprintf (" %i $groupname<br>", $group->{"gidNumber"} || 0);
	    }
	}
    }
    if (Autologin->used ()) {
	# summary label
	$ret .= __("<h3>Login Settings</h3>");
	# summary item, %1 is user name
	$ret .= sformat (__("User %1 configured for automatic login"),
	    Autologin->user ());
    }
    return $ret;
}

##-------------------------------------------------------------------------
##-------------------------------------------------------------------------

# Sets modified flags, except of ldap_modified!
BEGIN { $TYPEINFO{SetModified} = ["function", "void", "boolean"];}
sub SetModified {
    my $self	= shift;
    $users_modified = $groups_modified = $customs_modified =
    $defaults_modified = $security_modified = $_[0];
}

# Sets modified flag for sysconfig/ldap
BEGIN { $TYPEINFO{SetLdapSysconfigModified} = ["function", "void", "boolean"];}
sub SetLdapSysconfigModified {
    my $self	= shift;
    $sysconfig_ldap_modified = shift;
}

# Remember reading Ldap client config
BEGIN { $TYPEINFO{SetLdapSettingsRead} = ["function", "void", "boolean"];}
sub SetLdapSettingsRead {
    my $self	= shift;
    $ldap_settings_read = shift;
}

# Check if Ldap client config was read
BEGIN { $TYPEINFO{LdapSettingsRead} = ["function", "boolean"];}
sub LdapSettingsRead {
    return $ldap_settings_read;
}

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
	if (UsersPasswd->SetPluslines ("passwd", \@pluses_passwd)) {
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
	if (UsersPasswd->SetPluslines ("shadow", \@pluses_shadow)) {
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
	if (UsersPasswd->SetPluslines ("group", \@pluses_group)) {
	    $groups_modified 	= 1;
	}
    }
}

1
# EOF
