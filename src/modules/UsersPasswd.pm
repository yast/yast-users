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

# File:		modules/UsersPasswd.pm
# Package:	Configuration of users and groups
# Summary:	Access to /etc/passwd, /etc/shadow and /etc/group
# Author:	Jiri Suchomel <jsuchome@suse.cz>

package UsersPasswd;

use strict;
use YaST::YCP qw(:LOGGING);

our %TYPEINFO;

YaST::YCP::Import ("FileUtils");
YaST::YCP::Import ("SCR");
YaST::YCP::Import ("SSHAuthorizedKeys");

#---------------------------------------------------------------------
#--------------------------------------------------------- definitions

# see SYS_UID_MAX and SYS_GID_MAX in /etc/login.defs
my $max_system_uid	= 499;
my $max_system_gid	= 499;

my %last_uid		= (
    "local"	=> $max_system_uid + 1,
    "system"	=> 0
);

my %users		= ();
my %groups		= ();
my %shadow_tmp		= ();
my %shadow		= ();

# used for check if values like uid,username are unique:
my %uids		= ();
my %usernames		= ();
my %homes		= (); 
my %gids		= ();
my %groupnames		= ();

# for each user there is a list of groups, where the user is contained
my %users_groups	= ();

my %users_by_uidnumber	= ();
my %groups_by_gidnumber	= ();

my $plus_line_group 	= "";
my $plus_line_passwd	= "";
my $plus_line_shadow	= "";

my @plus_lines_group 	= ();
my @plus_lines_passwd	= ();
my @plus_lines_shadow	= ();

my @comments_group 	= ();
my @comments_passwd	= ();
my @comments_shadow	= ();

# error number
my $errno		= 0;

#more information about the error
my $error_info		= "";

# directory where user/group/shadow data should be found
my $base_directory	 = "/etc";

# data correctly initialized ? (Read must be called before Get*)
my $initialized		= 0;

# indicates that /etc/shadow is missing (may be intentional, see bnc#583338)
my $no_shadow		= 0;

#---------------------------------------------------------------------
#-------------------------------------------------- internal functions

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

# check if the data were initialized correctly
sub check_init {
    
    if (!$initialized) {
	y2warning ("not correctly initialized, data might be broken!");
    }
    return $initialized;
}


#---------------------------------------------
# read /etc/shadow and prepare global 'shadow_tmp' structure
sub read_shadow {

    %shadow_tmp	= ();
    @plus_lines_shadow	= ();
    @comments_shadow	= ();
    $no_shadow	= 0;

    my $file	= "$base_directory/shadow";

    if (! FileUtils->Exists ($file)) {
	y2warning ("$file is not available!");
    	$no_shadow	= 1;
	return 1;
    }
    my $in	= SCR->Read (".target.string", $file);

    if (! defined $in) {
	y2warning ("$file cannot be opened for reading!");
	return 1;
    }

    foreach my $shadow_entry (split (/\n/,$in)) {
	chomp $shadow_entry;
	if ($shadow_entry eq "") {
	    y2warning ("empty line in shadow file...");
	    next;
	}
	my ($uname,$pass,$last_change,$min, $max, $warn, $inact, $expire, $flag)
	    = split(/:/,$shadow_entry);  
        my $first = substr ($uname, 0, 1);

	if ($first eq "#") {
	    y2warning ("Found comment line in shadow file: '$shadow_entry'");
	    y2warning ("It will be moved to the end of file");
	    push @comments_shadow, $shadow_entry;
	}
	elsif ($first ne "+" && $first ne "-")
	{
	    if (!defined $uname || $uname eq "") {
		y2error ("strange line in shadow file: '$shadow_entry'");
		$errno 		= 9;
		return 0;
	    }

	    if (defined $shadow_tmp{$uname})
	    {
		y2error ("duplicated username in /etc/shadow! Exiting...");
		$errno		= 3;
		$error_info 	= $uname;
		return 0;
	    }
	    $shadow_tmp{$uname} = {
		"shadowLastChange"	=> $last_change,
		"shadowWarning"		=> $warn,
		"shadowInactive"	=> $inact,
		"shadowExpire"		=> $expire,
		"shadowMin"		=> $min,
		"shadowMax"		=> $max,
		"shadowFlag"		=> $flag,
		"userPassword"		=> $pass
	    };
	}
	else # plus line in /etc/shadow
	{
	    $plus_line_shadow = $shadow_entry;
	    push @plus_lines_shadow, $shadow_entry;
	}
    }
    return 1;
}

#---------------------------------------------
# read /etc/group and prepar global 'users_groups' structure
sub read_group {

    %groups	= ();
    %gids	= ();
    %groupnames	= ();
    %users_groups       = ();
    %groups_by_gidnumber= ();
    @plus_lines_group	= ();
    @comments_group	= ();

    my $file	= "$base_directory/group";

    if (! FileUtils->Exists ($file)) {
	y2warning ("$file is not available!");
	return 1;
    }
    my $in	= SCR->Read (".target.string", $file);
    if (! defined $in) {
	y2warning ("$file cannot be opened for reading!");
	return 1;
    }

    foreach my $group (split (/\n/,$in)) {
	
	chomp $group;
	if ($group eq "") {
	    y2warning ("empty line in group file...");
	    next;
	}
        my ($groupname, $pass, $gid, $users) = split (/:/,$group);
	my $first = substr ($groupname, 0, 1);

	if ($first eq "#") {
	    y2warning ("Found comment line in group file: '$group'");
	    y2warning ("It will be moved to the end of file");
	    push @comments_group, $group;
	}
        elsif ( $first ne "+" && $first ne "-" ) {
	    
	    if (!defined $pass || !defined $gid || !defined $users ||
		$gid eq "") {
		y2error ("strange line in group file: '$group'");
		$errno 		= 8;
		$error_info 	= "$group";
		return 0;
	    }
		
	    my $group_type = "local";
	    if (($gid <= $max_system_gid || $groupname eq "nobody" ||
		 $groupname eq "nogroup") &&
		($groupname ne "users"))
	    {
		$group_type = "system";
	    }

            # check for duplicates...
	    if (defined $gids{$group_type}{$gid})
	    {
		y2warning ("duplicated gid ($gid) in /etc/group");
	        $gids{$group_type}{$gid} = $gids{$group_type}{$gid} + 1;
	    }
	    else
            {
	        $gids{$group_type}{$gid} = 1;
	    }

            if (defined $groupnames{"local"}{$groupname} ||
		defined $groupnames{"system"}{$groupname})
            {
	        y2error ("duplicated groupname in /etc/group! Exiting...");
		$errno		= 6;
		$error_info 	= $groupname;
	        return 0;
            }
	    else
	    {
		$groupnames{$group_type}{$groupname} = 1;
            }
            # for each user generate list of groups, where the user is contained
	    my @userlist	= split(/,/,$users);
	    my %userlist	= ();
	    foreach my $u (@userlist) {
		$userlist{$u}			= 1;
		$users_groups{$u}{$groupname}	= 1;
	    }
	    $groups{$group_type}{$groupname} = {
		"cn"		=> $groupname,
		"gidNumber" 	=> $gid,
		"userlist"	=> \%userlist,
		"type"		=> $group_type,
		"userPassword"	=> $pass,
		"more_users"	=> {}
	    };

	    if (!defined $groups_by_gidnumber{$group_type}{$gid}) {
		$groups_by_gidnumber{$group_type}{$gid} = {};
	    }
	    $groups_by_gidnumber{$group_type}{$gid}{$groupname}	= 1;
	}
	else # save the possible "+"/"-" entries
        {
	    $plus_line_group = $group;
	    push @plus_lines_group, $group;
        }
    }
    return 1;
}

# Read authorized keys from user's home (FATE#319471)
sub read_authorized_keys {
    foreach my $user (values %{$users{"local"}}) {
      SSHAuthorizedKeys->read_keys($user->{"homeDirectory"});
      $user->{"authorized_keys"} = SSHAuthorizedKeys->export_keys($user->{"homeDirectory"});
    }

    # Read authorized keys also from root's home (bsc#1066342)
    # 'root' user may not always exist (bsc#1112119, bsc#1107456)
    SSHAuthorizedKeys->read_keys($users{system}{root}{homeDirectory}) if $users{system}{root};
}

# actually read /etc/passwd and save into internal structure
sub read_passwd {

    my $file	= "$base_directory/passwd";

    %users 	= ();
    %shadow	= ();
    %uids	= ();
    %usernames	= ();
    %homes	= ();
    %users_by_uidnumber	= ();
    @plus_lines_passwd	= ();
    @comments_passwd	= ();

    if (! FileUtils->Exists ($file)) {
	y2warning ("$file is not available!");
	return 1;
    }
    my $in	= SCR->Read (".target.string", $file);
    if (! defined $in) {
	y2warning ("$file cannot be opened for reading!");
	return 1;
    }

    foreach my $user (split (/\n/,$in)) {

	chomp $user;
	if ($user eq "") {
	    y2warning ("empty line in passwd file...");
	    next;
	}

	my ($username, $password, $uid, $gid, $full, $home, $shell)
	    = split(/:/,$user);
        my $first = substr ($username, 0, 1);

	if ($first eq "#") {
	    y2warning ("Found comment line in passwd file: '$user'");
	    y2warning ("It will be moved to the end of file");
	    push @comments_passwd, $user;
	}
	elsif ($first ne "+" && $first ne "-") {

	    if (!defined $password || !defined $uid || !defined $gid ||
		!defined $full || !defined $home || !defined $shell ||
		$username eq "" || $uid eq "" || $gid eq "") {
		y2error ("strange line in passwd file: '$user'");
		$errno 		= 7;
		$error_info 	= "$user";
		return 0;
	    }
		
            my $user_type	= "local";
	    my $group_type	= "";
	    my $groupname	= "";
	    my %grouplist	= ();

	    if (defined $groups_by_gidnumber{"system"}{$gid})
	    {
		$group_type = "system";
	    }
	    if (defined $groups_by_gidnumber{"local"}{$gid})
	    {
		$group_type = "local";
	    }
	    if ($group_type ne "")
	    {
		$groupname = (keys %{$groups_by_gidnumber{$group_type}{$gid}})[0];
		# modify default group's more_users entry
		$groups{$group_type}{$groupname}{"more_users"}{$username}	= 1;
	    }

	    # add the grouplist
	    if (defined $users_groups{$username}) {
		%grouplist = %{$users_groups{$username}};
	    }

	    if (($uid <= $max_system_uid) || ($username eq "nobody")) {
		$user_type = "system";
		if ($last_uid{"system"} < $uid  && $username ne "nobody") {
		    $last_uid{"system"} = $uid;
		}
	    }
	    else {
		if ($last_uid{"local"} < $uid) {
		    $last_uid{"local"} = $uid;
		}
	    }
	    my $encoding = "";
	    if ($encoding ne "") {
		from_to ($full, $encoding, "utf-8");
	    }
    
	    my $colon = index ($full, ",");
	    my $additional = "";
	    if ( $colon > -1)
	    {
		$additional = $full;
		$full = substr ($additional, 0, $colon);
		$additional = substr ($additional, $colon + 1,
		    length ($additional));
	    }

            # check for duplicates in /etc/passwd:
	    if (defined $uids{$user_type}{$uid})
	    {
		y2warning ("duplicated UID in /etc/passwd: $uid");
	        $uids{$user_type}{$uid} = $uids{$user_type}{$uid} + 1;
	    }
            else
	    {
	        $uids{$user_type}{$uid} = 1;
            }
	    
	    if (defined $usernames{"local"}{$username} ||
		defined $usernames{"system"}{$username})
	    {
		y2error ("duplicated username in /etc/passwd! Exiting...");
		$errno = 2;
		$error_info 	= $username;
		return 0;
	    }
	    else
	    {
		$usernames{$user_type}{$username} = 1;
	    }
	    if ($home ne "")
	    {
		$homes{$user_type}{$home} = 1;
	    }
    
	    my @grouplist	= keys (%grouplist);

	    # such map we would like to export from the read script...
	    $users{$user_type}{$username} = {
		"addit_data"	=> $additional,
		"cn"		=> $full,
		"homeDirectory"	=> $home,
		"uid"		=> $username,
		"uidNumber"	=> $uid,
		"gidNumber"	=> $gid,
		"loginShell"	=> $shell,
		"groupname"	=> $groupname,
		"grouplist"	=> \%grouplist,
		"userPassword"	=> undef,
		"type"		=> $user_type
	    };
	    # sometimes real password might be in /etc/passwd
	    if ($password ne "" && $password ne "x" && $no_shadow) {
	    	$users{$user_type}{$username}{"userPassword"} = $password;
	    }

	    if (! defined $shadow_tmp{$username}) {
		y2debug ("There is no shadow entry for user $username.");
	    }
	    else {
		# divide shadow map accoring to user type
		$shadow{$user_type}{$username} = $shadow_tmp{$username};
	    }

	    if (!defined $users_by_uidnumber{$user_type}{$uid}) {
		$users_by_uidnumber{$user_type}{$uid} = {};
	    }
	    $users_by_uidnumber{$user_type}{$uid}{$username}	= 1;
	}
	else # the "+" entry in passwd
	{
	    $plus_line_passwd = $user;
	    push @plus_lines_passwd, $user;
	}
    }
    return 1;
}


#---------------------------------------------------------------------
# ------------------------------------------------------- external API


# Return last error number
# @return integer
BEGIN { $TYPEINFO{GetError} = ["function", "integer"]}
sub GetError {
    return YaST::YCP::Integer ($errno);
}

# Return error message of last error
# @return string
BEGIN { $TYPEINFO{GetErrorInfo} = ["function", "string"]}
sub GetErrorInfo {

    return $error_info;
}

# Read the data from passwd, shadow and group files and save them to global
# structures.
# @return boolean (success)
# @param configuration map; can contain these keys:
#	"max_system_uid" - maximal UID for system users
#	"max_system_gid" - maximal GID for system groups
#	"base_directory" - directory with data files ("/etc" by default)
BEGIN { $TYPEINFO{Read} = ["function", "boolean", ["map", "string", "string"]]}
sub Read {

    my $self	= shift;
    my $config	= shift;
    my $ret	= 0;

    if (defined ($config->{"max_system_uid"})) {
	$max_system_uid	= $config->{"max_system_uid"};
    }
    if (defined ($config->{"max_system_gid"})) {
        $max_system_gid	= $config->{"max_system_gid"};
    }
    if (defined ($config->{"base_directory"})) {
        $base_directory	= $config->{"base_directory"};
    }
    if (read_shadow () && read_group ()) {
	$ret = read_passwd ();
	read_authorized_keys();
    }
    $initialized	= $ret;
    return $ret;
}


# Return the map with users from passwd file.
# @return map<string,map> - map is indexed by user name
# @param type of users to get (local/system)
BEGIN { $TYPEINFO{GetUsers} = ["function",
    ["map", "string", ["map", "string", "any"]],
    "string"];
}
sub GetUsers {

    check_init ();
    my $self	= shift;
    my $type	= shift;

    if (defined $users{$type}) {
	return $users{$type};
    }
    return {};
}

# Return the map with mappings of UID's to user names with such UID
# @param type of users to get (local/system)
BEGIN { $TYPEINFO{GetUsersByUIDNumber} = ["function",
    ["map", "integer", ["map", "string", "integer"]],
    "string"];
}
sub GetUsersByUIDNumber {

    check_init ();
    my $self	= shift;
    my $type	= shift;
    
    if (defined $users_by_uidnumber{$type}) {
        return $users_by_uidnumber{$type};
    }
    return {};
}

# Return the map with data from shadow file.
# @return map<string,map> - map is indexed by user name
# @param type of users to get (local/system)
BEGIN { $TYPEINFO{GetShadow} = ["function",
    ["map", "string", ["map", "string", "any"]],
    "string"];
}
sub GetShadow {
    check_init ();
    my $self	= shift;
    my $type	= shift;
    
    if (defined $shadow{$type}) {
	return $shadow{$type};
    }
    return {};
}

# Return the map with group data from group file.
# @return map<string,map> - map is indexed by group name
# @param type of groups to get (local/system)
BEGIN { $TYPEINFO{GetGroups} = ["function",
    ["map", "string", ["map", "string", "any"]],
    "string"];
}
sub GetGroups {
    check_init ();
    my $self	= shift;
    my $type	= shift;

    if (defined $groups{$type}) {
	return $groups{$type};
    }
    return {};
}

# Return the map with mappings of GID's to group names with such GID
# @param type of groups to get (local/system)
BEGIN { $TYPEINFO{GetGroupsByGIDNumber} = ["function",
    ["map", "string", ["map", "string", "any"]],
    "string"];
}
sub GetGroupsByGIDNumber {
    check_init ();
    my $self	= shift;
    my $type	= shift;

    if (defined $groups_by_gidnumber{$type}) {
        return $groups_by_gidnumber{$type};
    }
    return {};
}


# Return the list of lines beginning with +
# @param string file to get lines from (passwd/shadow/group)
BEGIN { $TYPEINFO{GetPluslines} = ["function", ["list", "string"], "string"];}
sub GetPluslines {

    check_init ();
    my $self	= shift;
    my $file	= shift;
    if ($file eq "passwd") {
	return \@plus_lines_passwd;
    }
    elsif ($file eq "shadow") {
	return \@plus_lines_shadow;
    }
    elsif ($file eq "group") {
	return \@plus_lines_group;
    }
    return [];
}

# Set the new list of lines beginning with + for given file. The lines will
# be written to the end of the file during writing (Write* functions)
# @param string file to get lines from (passwd/shadow/group)
# @param list<string> new set of + lines
BEGIN { $TYPEINFO{SetPluslines} = ["function", "boolean", "string",
    ["list", "string"]];
}
sub SetPluslines {

    my $self	= shift;
    my $file	= shift;
    my $lines	= shift;

    if (! defined $lines || ref ($lines) ne "ARRAY") {
	return 0;
    }
	
    if ($file eq "passwd") {
	if (same_arrays (\@plus_lines_passwd, $lines)) {
	    return 0;
	}
	else {
	    @plus_lines_passwd = @$lines;
	    y2milestone ("new plus lines in passwd: ", @plus_lines_passwd);
	    return 1;
	}
    }
    elsif ($file eq "shadow") {
	if (same_arrays (\@plus_lines_shadow, $lines)) {
	    return 0;
	}
	else {
	    @plus_lines_shadow = @$lines;
	    y2milestone ("new plus lines in shadow: ", @plus_lines_shadow);
	    return 1;
	}
    }
    elsif ($file eq "group") {
	if (same_arrays (\@plus_lines_group, $lines)) {
	    return 0;
	}
	else {
	    @plus_lines_group = @$lines;
	    y2milestone ("new plus lines in group: ", @plus_lines_group);
	    return 1;
	}
    }
    return 0;
}

#--------------------------------------
# Write map of users to the passwd file
# @param map of users, indexed by type in 1st level, and by user name in 2nd one
BEGIN { $TYPEINFO{WriteUsers} = ["function", "boolean", "any" ];}
sub WriteUsers {

    my $self	= shift;
    my %users_w	= %{$_[0]};

    check_init ();

    # do not allow user to remove whole passwd
    if (!%users_w) {
	%users_w	= %users;
    }

    my $file	= "$base_directory/passwd";
    if (! FileUtils->Exists ($file)) {
	y2warning ("$file cannot be opened for writing!");
    }
    my $out	= "";

    foreach my $type (sort {$b cmp $a} keys %users_w) {

	if ($type ne "local" && $type ne "system") {
	    next;
	}

	foreach my $username (sort keys %{$users_w{$type}}) {

	    my %user	= %{$users_w{$type}{$username}};
	    my $pass	= "x";
	    if ($no_shadow && $user{"userPassword"})
	    {
		$pass	= $user{"userPassword"};
	    }
	    my $cn	= $user{"cn"} || "";
	    if (defined $user{"addit_data"} && $user{"addit_data"} ne "") {
		$cn	.= ",".$user{"addit_data"};
	    }
	    my $userline	= join (":", (
		$user{"uid"} || "",
		$pass,
		$user{"uidNumber"} || 0,
		$user{"gidNumber"} || 0,
		$cn,
		$user{"homeDirectory"} || "",
		$user{"loginShell"} || "",
	    ));
	    if (defined $userline) {
		$out	= $out."$userline\n";
	    }
	}
    }
    if (@comments_passwd > 0) {
	foreach my $comment (@comments_passwd) {
	    $out	= $out."$comment\n";
	}
    }
    if (@plus_lines_passwd > 0) {
	foreach my $plusline (@plus_lines_passwd) {
	    $out	= $out."$plusline\n";
	}
    }
    my $ret	= SCR->Write (".target.string", $file, $out);
    y2usernote ("File written: '$file'");
    return $ret;
}

#--------------------------------------------
# Write map of shadow data to the shadow file
# @param map of shadow info for all users
BEGIN { $TYPEINFO{WriteShadow} = ["function", "boolean", "any" ];}
sub WriteShadow {

    my $self		= shift;
    my %shadow_w	= %{$_[0]};

    check_init ();

    # do not allow user to remove whole shadow
    if (!%shadow_w) {
	%shadow_w	= %shadow;
    }

    my $file	= "$base_directory/shadow";
    if (! FileUtils->Exists ($file)) {
	y2warning ("$file cannot be opened for writing!");
    }
    my $out	= "";

    foreach my $type (sort {$b cmp $a} keys %shadow_w ) {

	if ($type ne "local" && $type ne "system") {
	    next;
	}

        foreach my $uname (sort keys %{$shadow_w{$type}}) {

	    my %shadow_entry	= %{$shadow_w{$type}{$uname}};
	    foreach my $key ("shadowWarning", "shadowInactive", "shadowExpire", "shadowFlag", "userPassword", "shadowMin", "shadowMax") {
		# -1 should disable feature, it should not be written (#259896)
		if (!defined $shadow_entry{$key} || $shadow_entry{$key} eq -1) {
		    $shadow_entry{$key}	= "";
		}
	    }
	    my $shadowline	= join (":", (
		$uname,
		$shadow_entry{"userPassword"},
		$shadow_entry{"shadowLastChange"},
		$shadow_entry{"shadowMin"},
		$shadow_entry{"shadowMax"},
		$shadow_entry{"shadowWarning"},
		$shadow_entry{"shadowInactive"},
		$shadow_entry{"shadowExpire"},
		$shadow_entry{"shadowFlag"}
	    ));
	    if (defined $shadowline) {
		$out	= $out."$shadowline\n";
	    }
	}
    }
    if (@comments_shadow > 0) {
	foreach my $comment (@comments_shadow) {
	    $out	= $out."$comment\n";
	}
    }
    if (@plus_lines_shadow > 0) {
	foreach my $plusline (@plus_lines_shadow) {
	    $out	= $out."$plusline\n";
	}
    }
    my $ret	= SCR->Write (".target.string", $file, $out);
    y2usernote ("File written: '$file'");
    return $ret;
}


#--------------------------------------
# Write map of groups to the group file
BEGIN { $TYPEINFO{WriteGroups} = ["function", "boolean", "any" ];}
sub WriteGroups {

    my $self		= shift;
    my %groups_w	= %{$_[0]};

    check_init ();

    # do not allow user to remove whole group
    if (!%groups_w) {
	%groups_w	= %groups;
    }

    my $file	= "$base_directory/group";
    if (! FileUtils->Exists ($file)) {
	y2warning ("$file cannot be opened for writing!");
    }
    my $out	= "";

    # sort order: system items go before local ones
    foreach my $type (sort {$b cmp $a} keys %groups_w ) {

	if ($type ne "local" && $type ne "system") {
	    next;
	}

	# sort order: id
        foreach my $groupname (sort keys %{$groups_w{$type}}) {

	    my %group	= %{$groups_w{$type}{$groupname}};
	    my $pass	= "x";
	    if (defined $group{"userPassword"}) {
		$pass 	= $group{"userPassword"};
	    }
	    my @group_entry	= (
		$group{"cn"},
		$pass,
		$group{"gidNumber"} || 0,
		join (",", sort keys %{$group{"userlist"}})
	    );
	    my $groupline	= join (":", @group_entry);

	    if (defined $groupline) {
		$out	= $out."$groupline\n";
	    }
	}
    }
    if (@comments_group > 0) {
	foreach my $comment (@comments_group) {
	    $out	= $out."$comment\n";
	}
    }
    if (@plus_lines_group > 0) {
	foreach my $plusline (@plus_lines_group) {
	    $out	= $out."$plusline\n";
	}
    }
    my $ret	= SCR->Write (".target.string", $file, $out);
    y2usernote ("File written: '$file'");
    return $ret;
}

#---------------------------------------------------------------------
#----------------------------------- functions used in caching modules


# Return map of home directories of given type (in the form "home" -> 1)
# @param string type of users
BEGIN { $TYPEINFO{GetHomes} = ["function",
    ["map", "string", "integer"],
    "string"];
}
sub GetHomes {
    my $self	= shift;
    my $type	= shift;
    if (defined $homes{$type}) {
	return $homes{$type};
    }
    return {};
}
	
# Return map of UIDs of given type
# @param string type of users
BEGIN { $TYPEINFO{GetUIDs} = ["function",
    ["map", "integer", "integer"],
    "string"];
}
sub GetUIDs {
    my $self	= shift;
    my $type	= shift;
    if (defined $uids{$type}) {
        return $uids{$type};
    }
    return {};
}
	
# Return map of user names of given type
# @param string type of users
BEGIN { $TYPEINFO{GetUsernames} = ["function",
    ["map", "string", "integer"],
    "string"];
}
sub GetUsernames {
    my $self	= shift;
    my $type	= shift;
    if (defined $usernames{$type}) {
	return $usernames{$type};
    }
    return {};
}

# Return the highest UID used for user of given type
# @return integer
# @param string type of user
BEGIN { $TYPEINFO{GetLastUID} = ["function", "integer", "string"]; }
sub GetLastUID {
    my $self	= shift;
    my $type	= shift;
    if (defined $last_uid{$type}) {
	return YaST::YCP::Integer ($last_uid{$type});
    }
    return 0;
}

# Return map of GIDs of given type
# @param string type of groups
BEGIN { $TYPEINFO{GetGIDs} = ["function",
    ["map", "integer", "integer"],
    "string"];
}
sub GetGIDs {
    my $self	= shift;
    my $type	= shift;
    if (defined $gids{$type}) {
	return $gids{$type};
    }
    return {};
}
	
# Return map of group names of given type
# @param string type of groups
BEGIN { $TYPEINFO{GetGroupnames} = ["function",
    ["map", "string", "integer"],
    "string"];
}
sub GetGroupnames {
    my $self	= shift;
    my $type	= shift;
    if (defined $groupnames{$type}) {
	return $groupnames{$type};
    }
    return {};
}

# set the new the value of base directory
BEGIN { $TYPEINFO{SetBaseDirectory} = ["function", "void", "string"]; }
sub SetBaseDirectory {
    my $self		= shift;
    my $dir		= shift;
    $base_directory	= $dir if (defined $dir);
}

42
# EOF
