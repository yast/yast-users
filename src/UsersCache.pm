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
# UsersCache module written in Perl
#

package UsersCache;

use strict;

use YaST::YCP qw(:LOGGING);
use YaPI;

textdomain ("users");

our %TYPEINFO;

# If YaST UI (Qt,ncurses) should be used
my $use_gui                     = 1;

my $user_type		= "local";
my $group_type		= "local";

my %usernames		= ();
my %homes		= ();
my %uids		= ();
my %user_items		= ();
my %userdns		= ();

my %groupnames		= ();
my %gids		= ();
my %group_items		= ();

my %removed_uids	= ();
my %removed_usernames	= ();

my %min_uid			= (
    "local"		=> 1000,
    "system"		=> 100,
    "ldap"		=> 1000
);

my %min_gid			= (
    "local"		=> 1000,
    "system"		=> 100,
    "ldap"		=> 1000
);

my %max_uid			= (
    "local"		=> 60000,
    "system"		=> 499,
    "ldap"		=> 60000
);

my %max_gid			= (
    "local"		=> 60000,
    "system"		=> 499,
    "ldap"		=> 60000
);

# the highest ID in use
my %last_uid		= (
    "local"		=> 1000,
    "system"		=> 100,
);

my %last_gid		= (
    "local"		=> 1000,
    "system"		=> 100,
    "ldap"		=> 1000
);

my $max_length_groupname 	= 32;
my $min_length_groupname	= 2;

# UI-related (summary table) variables:
my $focusline_user;
my $focusline_group;
my $current_summary	= "users";

# usernames generated by "Propose" button
my @proposed_usernames	= ();
# number of clicks of "Propose" (-1 means: generate new list)
my $proposal_count	= -1;

# list of references to list of current user items
my @current_user_items	= ();
my @current_group_items	= ();

# which sets of users are we working with:
my @current_users	= ();
my @current_groups	= ();

# Is the currrent table view "customized"?
my $customized_usersview	= 1;
my $customized_groupsview	= 1;

# the length of UID/GID string item
my $uid_length			= 6;

# the final answer ;-)
my $the_answer			= 42;

##------------------------------------
##------------------- global imports

YaST::YCP::Import ("Ldap");
YaST::YCP::Import ("Mode");
YaST::YCP::Import ("SCR");
YaST::YCP::Import ("UsersPasswd");
YaST::YCP::Import ("UsersUI");

##-------------------------------------------------------------------------
##----------------- various routines --------------------------------------

BEGIN { $TYPEINFO{ResetProposing} = ["function", "void"]; }
sub ResetProposing {
    my $self		= shift;
    $proposal_count	= -1;
}


BEGIN { $TYPEINFO{DebugMap} = ["function", "void", "any"];}
sub DebugMap {

    my $self		= shift;

    if (!defined $_[0] || ref ($_[0]) ne "HASH") { return; }
    my %map = %{$_[0]};
    
    y2internal ("--------------------------- start of output");
    foreach my $key (sort keys %map) {
	if (!defined $map{$key}) {
	    next;
	}
    	if (ref ($map{$key}) eq "ARRAY") {
	    y2warning ("$key ---> (list)\n", join ("\n", sort @{$map{$key}}));
	}
	elsif (ref ($map{$key}) eq "YaST::YCP::Term") {
	    y2warning ("$key --->", @{$map{$key}->args}, "--------");
	}
	else {
	    y2warning ("$key --->", $map{$key}, "--------");
	}
    }
    y2internal ("--------------------------- end of output");
}

##-------------------------------------------------------------------------
##----------------- current users (group) routines, customization r. ------

BEGIN { $TYPEINFO{SetCurrentUsers} = ["function", "void", ["list", "string"]];}
sub SetCurrentUsers {

    my $self		= shift;
    @current_users	= @{$_[0]}; # e.g. ("local", "system")

    @current_user_items = ();
    foreach my $type (@current_users) {
	push @current_user_items, $user_items{$type};
	# e.g. ( pointer to "local items", pointer to "system items")
    };
    undef $focusline_user;
    $self->SetUserType ($current_users[0]);
}

##------------------------------------
BEGIN { $TYPEINFO{SetCustomizedUsersView} = ["function", "void", "boolean"];}
sub SetCustomizedUsersView {
    my $self			= shift;
    $customized_usersview 	= $_[0];
}

##------------------------------------
BEGIN { $TYPEINFO{CustomizedUsersView} = ["function", "boolean"];}
sub CustomizedUsersView {
    return $customized_usersview;
}


##------------------------------------
BEGIN { $TYPEINFO{SetCurrentGroups} = ["function", "void", ["list", "string"]];}
sub SetCurrentGroups {

    my $self		= shift;
    @current_groups	= @{$_[0]}; # e.g. ("local", "system")

    @current_group_items = ();
    foreach my $type (@current_groups) {
	push @current_group_items, $group_items{$type};
	# e.g. ( pointer to "local items", pointer to "system items")
    };
    undef $focusline_group;
    $self->SetGroupType ($current_groups[0]);
}

##------------------------------------
BEGIN { $TYPEINFO{SetCustomizedGroupsView} = ["function", "void", "boolean"];}
sub SetCustomizedGroupsView {
    my $self			= shift;
    $customized_groupsview 	= $_[0];
}

##------------------------------------
BEGIN { $TYPEINFO{CustomizedGroupsView} = ["function", "boolean"];}
sub CustomizedGroupsView {
    return $customized_groupsview;
}

##-------------------------------------------------------------------------
##----------------- test routines -----------------------------------------


##------------------------------------
sub UIDConflicts {

    my $ret = SCR->Read (".uid.uid", $_[0]);
    return !$ret;
}
 
##------------------------------------
BEGIN { $TYPEINFO{UIDExists} = ["function", "boolean", "integer"]; }
sub UIDExists {

    my $self	= shift;
    my $uid	= $_[0];
    my $ret	= 0;

    foreach my $type (keys %uids) {
	if (($uids{$type}{$uid} || 0) > 0) { $ret = 1; }
    };
    # for autoyast, check only loaded sets
    if ($ret || Mode->config () || Mode->test ()) {
	return $ret;
    }
    # not found -> check all sets via agent...
    $ret = UIDConflicts ($uid);
    if ($ret) {
	# check if uid wasn't just deleted...
	my @sets_to_check = ("local", "system");
	# LDAP: do not allow change uid of one user and use old one by
	# another user - because users are saved by calling extern tool
	# and colisions can be hardly avoided
	if ($user_type ne "ldap") {
	    push @sets_to_check, "ldap";
	}
	foreach my $type (@sets_to_check) {
	    if (defined $removed_uids{$type}{$uid} && $removed_uids{$type}{$uid} > 0) { 
		$ret = 0;
	    }
	};
    }
    return $ret;
}

sub UsernameConflicts {

    my $ret = SCR->Read (".uid.username", $_[0]);
    return !$ret;
}

##------------------------------------
BEGIN { $TYPEINFO{UsernameExists} = ["function", "boolean", "string"]; }
sub UsernameExists {

    my $self		= shift;
    my $username	= $_[0];
    my $ret		= 0;

    foreach my $type (keys %usernames) {
	if (defined $usernames{$type}{$username}) { $ret = 1; }
    };
    if ($ret || Mode->config () || Mode->test ()) {
	return $ret;
    }
    $ret = UsernameConflicts ($username);
    if ($ret) {
	my @sets_to_check = ("local", "system");
	if ($user_type ne "ldap") {
	    push @sets_to_check, "ldap";
	}
	foreach my $type (@sets_to_check) {
	    if (defined $removed_usernames{$type}{$username}) {
		$ret = 0;
	    }
	};
    }
    return $ret;
}


##------------------------------------
BEGIN { $TYPEINFO{GIDExists} = ["function", "boolean", "integer"]; }
sub GIDExists {

    my $self	= shift;
    my $gid	= $_[0];
    my $ret	= 0;
    
    if ($group_type eq "ldap") {
	$ret = ($gids{$group_type}{$gid} || 0) > 0;
    }
    else {
	$ret = (($gids{"local"}{$gid} || 0) > 0 || ($gids{"system"}{$gid} || 0) > 0);
    }
    return $ret;
}

##------------------------------------
BEGIN { $TYPEINFO{GroupnameExists} = ["function", "boolean", "string"]; }
sub GroupnameExists {

    my $self		= shift;
    my $groupname	= $_[0];
    my $ret		= 0;
    
    if ($group_type eq "ldap") {
	$ret = defined $groupnames{$group_type}{$groupname};
    }
    else {
	$ret = (defined $groupnames{"local"}{$groupname} ||
		defined $groupnames{"system"}{$groupname});
    }
    return $ret;
}

##------------------------------------
# Check if homedir is not owned by another user
# Doesn't check directory existence, only looks to set of used directories
# @param home the name
# @return true if directory is used as another user's home directory
BEGIN { $TYPEINFO{HomeExists} = ["function", "boolean", "string"]; }
sub HomeExists {

    my $self		= shift;
    my $home		= $_[0];
    my $ret		= 0;
    my @sets_to_check	= ("local", "system");

    if (Ldap->file_server ()) {
	push @sets_to_check, "ldap";
    }
    elsif ($user_type eq "ldap") { #ldap client only
	@sets_to_check = ("ldap");
    }

    foreach my $type (@sets_to_check) {
        if (defined $homes{$type}{$home}) {
	    $ret = 1;
	}
    }
    return $ret;
}

##-------------------------------------------------------------------------
##----------------- get routines ------------------------------------------

#------------------------------------
# returns the id (= user name or group name) of the item selected in the summary table
BEGIN { $TYPEINFO{GetCurrentFocus} = ["function", "string"]; }
sub GetCurrentFocus {

    if ($current_summary eq "users") {
	if (defined $focusline_user) {
	    return $focusline_user;
	}
    }
    else {
	if (defined $focusline_group) {
	    return $focusline_group;
	}
    }
    return undef;
}

#------------------------------------
# set the id (= user name or group name) of the item selected in the summary table
BEGIN { $TYPEINFO{SetCurrentFocus} = ["function", "void", "string"]; }
sub SetCurrentFocus {

    my $self		= shift;
    if ($current_summary eq "users") {
	$focusline_user = $_[0];
    }
    else {
	$focusline_group = $_[0];
    }
}


#------------------------------------
# current summary can be "users" or "groups" (=which table is shown in dialog)
BEGIN { $TYPEINFO{GetCurrentSummary} = ["function", "string"]; }
sub GetCurrentSummary {
    return $current_summary;
}

#------------------------------------
BEGIN { $TYPEINFO{SetCurrentSummary} = ["function", "void", "string"]; }
sub SetCurrentSummary {
    my $self		= shift;
    $current_summary 	= $_[0];
}

#------------------------------------
BEGIN { $TYPEINFO{ChangeCurrentSummary} = ["function", "void"]; }
sub ChangeCurrentSummary {
    
    if ($current_summary eq "users") {
	$current_summary = "groups";
    }
    else {
	$current_summary = "users";
    }
}


#------------------------------------ for User Details...
BEGIN { $TYPEINFO{GetAllGroupnames} = ["function",
    ["map", "string", ["map", "string", "integer"]] ];
}
sub GetAllGroupnames {

    return \%groupnames;
}

##------------------------------------
BEGIN { $TYPEINFO{GetGroupnames} = ["function", ["list", "string"], "string"];}
sub GetGroupnames {

    my $self	= shift;
    my @ret 	= sort keys %{$groupnames{$_[0]}};
    return \@ret;
}


##------------------------------------
# returns sorted list of usernames; parameter is type of users
BEGIN { $TYPEINFO{GetUsernames} = ["function", ["list", "string"], "string"];}
sub GetUsernames {

    my $self	= shift;
    my @ret 	= sort keys %{$usernames{$_[0]}};
    return \@ret;
}

##------------------------------------
# return list of table items of current user set
BEGIN { $TYPEINFO{GetUserItems} = ["function", ["list", "term"]];}
sub GetUserItems {

# @current_user_items: ( pointer to local hash, pointer to system hash, ...)

    my @items;
    foreach my $itemref (@current_user_items) {
	foreach my $username (sort keys %{$itemref}) {
	    push @items, $itemref->{$username};
	}
    }
    return \@items;
}

##------------------------------------
BEGIN { $TYPEINFO{GetGroupItems} = ["function", ["list", "term"]];}
sub GetGroupItems {

    my @items;
    foreach my $itemref (@current_group_items) {
	foreach my $groupname (sort keys %{$itemref}) {
	    push @items, $itemref->{$groupname};
	}
    }
    return \@items;
}

##------------------------------------
BEGIN { $TYPEINFO{GetUserType} = ["function", "string"]; }
sub GetUserType {

    return $user_type;
}

##------------------------------------
BEGIN { $TYPEINFO{GetGroupType} = ["function", "string"]; }
sub GetGroupType {

    return $group_type;
}

##------------------------------------
BEGIN { $TYPEINFO{GetMinGroupnameLength} = ["function", "integer" ]; }
sub GetMinGroupnameLength {
    my $self	= shift;
    return $min_length_groupname;
}

##------------------------------------
BEGIN { $TYPEINFO{GetMaxGroupnameLength} = ["function", "integer" ]; }
sub GetMaxGroupnameLength {
    my $self	= shift;
    return $max_length_groupname;
}

##------------------------------------
BEGIN { $TYPEINFO{GetMinUID} = ["function",
    "integer",
    "string"]; #user type
}
sub GetMinUID {

    my $self	= shift;
    if (defined $min_uid{$_[0]}) {
	return YaST::YCP::Integer ($min_uid{$_[0]})->value;
    }
    return YaST::YCP::Integer (0)->value;
}

##------------------------------------
BEGIN { $TYPEINFO{GetMaxUID} = ["function",
    "integer",
    "string"];
}
sub GetMaxUID {

    my $self	= shift;
    if (defined $max_uid{$_[0]}) {
	return YaST::YCP::Integer ($max_uid{$_[0]})->value;
    }
    return YaST::YCP::Integer (60000)->value;
}

##------------------------------------
BEGIN { $TYPEINFO{GetLastUID} = ["function", "integer", "string"]; }
sub GetLastUID {
    my $self	= shift;
    if (defined $last_uid{$_[0]}) {
	return $last_uid{$_[0]};
    }
    return 1;
}

##------------------------------------
BEGIN { $TYPEINFO{GetLastGID} = ["function", "integer", "string"]; }
sub GetLastGID {
    my $self	= shift;
    if (defined $last_gid{$_[0]}) {
	return $last_gid{$_[0]};
    }
    return 1;
}

##------------------------------------
BEGIN { $TYPEINFO{NextFreeUID} = ["function", "integer"]; }
sub NextFreeUID {

    my $self	= shift;
    my $max	= $self->GetMaxUID ($user_type);
    my $uid	= $last_uid{$user_type};
    my $ret;

    do {
        if ($self->UIDExists ($uid)) {
            $uid++;
	}
        else {
            $last_uid{$user_type} = $uid;
            return $uid;
        }
    } until ( $uid == $max );
    return $max;
}

##------------------------------------
BEGIN { $TYPEINFO{GetMinGID} = ["function",
    "integer",
    "string"];
}
sub GetMinGID {

    my $self	= shift;
    if (defined $min_gid{$_[0]}) {
	return YaST::YCP::Integer ($min_gid{$_[0]})->value;
    }
    return YaST::YCP::Integer (0)->value;
}
##------------------------------------
BEGIN { $TYPEINFO{GetMaxGID} = ["function",
    "integer",
    "string"];
}
sub GetMaxGID {

    my $self	= shift;
    if (defined $max_gid{$_[0]}) {
	return YaST::YCP::Integer ($max_gid{$_[0]})->value;
    }
    return YaST::YCP::Integer (60000)->value;
}


##------------------------------------
BEGIN { $TYPEINFO{NextFreeGID} = ["function", "integer"]; }
sub NextFreeGID {

    my $self	= shift;
    my $ret;
    my $max	= $self->GetMaxGID ($group_type);
    my $gid	= $last_gid{$group_type};
    do {
        if ($self->GIDExists ($gid)) {
            $gid++;
	}
        else {
            $last_gid{$group_type} = $gid;
            return $gid;
        }
    } until ( $gid == $max );
    return YaST::YCP::Integer ($ret)->value;
}


##-------------------------------------------------------------------------
##----------------- data manipulation routines ----------------------------

##------------------------------------
BEGIN { $TYPEINFO{SetMaxUID} = ["function",
    "void",
    "integer",# uid
    "string"];#user type
}
sub SetMaxUID {
    my $self	= shift;
    $max_uid{$_[1]}	= $_[0];
}

##------------------------------------
BEGIN { $TYPEINFO{SetMaxGID} = ["function",
    "void",
    "integer",# gid
    "string"];#user type
}
sub SetMaxGID {
    my $self	= shift;
    $max_gid{$_[1]}	= $_[0];
}

##------------------------------------
BEGIN { $TYPEINFO{SetMinUID} = ["function", "void", "integer", "string"]; }
sub SetMinUID {
    my $self	= shift;
    $min_uid{$_[1]}	= $_[0];
}

##------------------------------------
BEGIN { $TYPEINFO{SetMinGID} = ["function", "void", "integer", "string"]; }
sub SetMinGID {
    my $self	= shift;
    $min_gid{$_[1]}	= $_[0];
}

##------------------------------------
BEGIN { $TYPEINFO{SetLastUID} = ["function", "void", "integer", "string"]; }
sub SetLastUID {
    my $self	= shift;
    if ($_[0] >= $min_uid{$_[1]} && $_[0] <= $max_uid{$_[1]}) {
	$last_uid{$_[1]}	= $_[0];
    }
    else {
	$last_uid{$_[1]}	= $min_uid{$_[1]};
    }
}

##------------------------------------
BEGIN { $TYPEINFO{SetLastGID} = ["function", "void", "integer", "string"]; }
sub SetLastGID {
    my $self	= shift;
    if ($_[0] >= $min_gid{$_[1]} && $_[0] <= $max_gid{$_[1]}) {
	$last_gid{$_[1]}	= $_[0];
    }
    else {
	$last_gid{$_[1]}	= $min_gid{$_[1]};
    }
}

##------------------------------------
BEGIN { $TYPEINFO{SetUserType} = ["function", "void", "string"]; }
sub SetUserType {

    my $self	= shift;
    $user_type	= $_[0];
}

##------------------------------------
BEGIN { $TYPEINFO{SetGroupType} = ["function", "void", "string"]; }
sub SetGroupType {

    my $self	= shift;
    $group_type = $_[0];
}

# Add spaces before the text to make it long enough.
# Used for creating UID/GID items with same length, so they can be sorted
# "as integers" (bnc#399215).
sub PadBefore {
    
    my $text	= shift;
    $text	= "" if !defined $text;

    my $rest	= $uid_length - length ($text);
    my $pad	= "";

    while ($rest > 0) {
	$pad	= $pad." ";
	$rest	= $rest - 1;
    }
    return $pad.$text;
}


##------------------------------------
# build item for one user
sub BuildUserItem {
    
    my $self		= shift;
    my %user		= %{$_[0]};
    my $uid		= PadBefore ($user{"uidNumber"});
    my $username	= $user{"uid"} || "";
    my $full		= $user{"cn"} || "";
    if (defined $user{"gecos"} && $user{"gecos"} ne "") {
	$full		= $user{"gecos"};
    }

    my $iconname	= "yast-users.png";
    
    if ($user{"type"} eq "system") {
	$full		= UsersUI->SystemUserName ($full);
	$iconname	= "yast-system-user.png"
    }
    if (ref ($full) eq "ARRAY") {
	$full	= $full->[0];
    }

    my $groupname	= $user{"groupname"} || "";
    my %grouplist	= %{$user{"grouplist"}};

    if ($groupname ne "") {
    	$grouplist{$groupname}	= 1;
    }
    my $all_groups	= join (",", keys %grouplist);

    my $id = YaST::YCP::Term ("id", $username);
    my $t = YaST::YCP::Term ("item", $id, YaST::YCP::Term("cell", YaST::YCP::Term("icon", $iconname), $username), $full, $uid, $all_groups);
    return $t;
}

##------------------------------------
BEGIN { $TYPEINFO{BuildUserItemList} = ["function",
    "void",
    "string",
    ["map", "integer", [ "map", "string", "any"]] ];
}
sub BuildUserItemList {

    if (Mode->test ()) { return; }

    my $self		= shift;
    my $type		= $_[0];
    my %map_of_users	= %{$_[1]};
    $user_items{$type}	= {};

    foreach my $username (keys %map_of_users) {
        $user_items{$type}{$username} = $self->BuildUserItem ($map_of_users{$username});
    };
}

##------------------------------------
# Get first value from DN (e.g. "group" for "cn=group,dc=suse,dc=cz")
BEGIN { $TYPEINFO{get_first} = ["function", "string", "string"];}
sub get_first {

    my $self	= shift;
    my @dn_list	= split (",", $_[0]);
    my $ret = substr ($dn_list[0], index ($dn_list[0], "=") + 1);

    if (!defined $ret || $ret eq "") { $ret = $_[0]; }
    return $ret;
}

##------------------------------------
# build item for one group
sub BuildGroupItem {

    my $self		= shift;
    my %group		= %{$_[0]};
    my $gid		= PadBefore ($group{"gidNumber"});
    my $groupname	= $group{"cn"} || "";

    my %userlist	= ();
    if (defined ($group{"userlist"})) {
	%userlist 	= %{$group{"userlist"}};
    }
    my %more_users	= ();
    if (defined ($group{"more_users"})) {
	%more_users	= %{$group{"more_users"}};
    }
    # which attribute have groups for list of members
    my $ldap_member_attribute	= Ldap->member_attribute ();

    if ($group{"type"} eq "ldap" && defined ($group{$ldap_member_attribute})) {
	foreach my $dn (keys %{$group{$ldap_member_attribute}}) {
	    my $user		= $self->get_first ($dn);
	    $userlist{$user}	= 1;	
	}
    }

    my @all_users	= ();
    my @userlist	= sort keys %userlist;
    my $i		= 0;

    while ($i < $the_answer && defined $userlist[$i]) {

	push @all_users, $userlist[$i];
	$i++;
    }
    
    my $count		= @all_users;
    my @more_users	= sort keys %more_users;
    my $j		= 0;

    while ($count + $j < $the_answer && defined $more_users[$j]) {

	push @all_users, $more_users[$j];
	$j++;
    }
    if (defined $more_users[$j] || defined $userlist[$i]) {
	push @all_users, "...";
    }

    my $all_users	= join (",", @all_users);

    my $id = YaST::YCP::Term ("id", $groupname);
    my $t = YaST::YCP::Term ("item", $id, $groupname, $gid, $all_users);

    return $t;
}

##------------------------------------
BEGIN { $TYPEINFO{BuildGroupItemList} = ["function",
    "void",
    "string",
    ["map", "integer", [ "map", "string", "any"]] ];
}
sub BuildGroupItemList {

    if (Mode->test ()) { return; }

    my $self		= shift;
    my $type		= $_[0];
    my %map_of_groups	= %{$_[1]};
    $group_items{$type}	= {};

    foreach my $gname (keys %map_of_groups) {
        $group_items{$type}{$gname} = $self->BuildGroupItem ($map_of_groups{$gname});
    };
}


##------------------------------------
# Update the cache after changing user
# @param user the user's map
BEGIN { $TYPEINFO{CommitUser} = ["function",
    "void",
    ["map", "string", "any" ]];
}
sub CommitUser {

    my $self		= shift;
    my %user		= %{$_[0]};
    my $what		= $user{"what"};
    my $type		= $user{"type"}	|| "";
    my $org_type	= $user{"org_type"} || $type;
    my $uid		= $user{"uidNumber"};
    my $org_uid		= $user{"org_uidNumber"} || $uid;
    my $home		= $user{"homeDirectory"} || "";
    my $org_home	= $user{"org_homeDirectory"} || $home;
    my $username	= $user{"uid"};
    my $org_username	= $user{"org_uid"} || $username;

    my $dn		= $user{"dn"} || $username;
    my $org_dn		= $user{"org_dn"} || $dn;


    if ($what eq "add_user") {
	if ($type eq "ldap") {
	    $userdns{$dn}	= 1;
	}
	if (defined $removed_uids{$type}{$uid} && $removed_uids{$type}{$uid} > 0) {
	    $removed_uids{$type}{$uid} = $removed_uids{$type}{$uid} -1;
	    y2debug ("uid $uid previously defined in removed_uids{$type}");
	}
        $uids{$type}{$uid}		= ($uids{$type}{$uid} || 0) + 1;
        $homes{$type}{$home}		= 1;
        $usernames{$type}{$username}	= 1;
	if (defined $removed_usernames{$type}{$username}) {
	    delete $removed_usernames{$type}{$username};
	}
	if ($use_gui) {
	    $user_items{$type}{$username}	= $self->BuildUserItem (\%user);
	    $focusline_user = $username;
	}
    }
    elsif ($what eq "edit_user" || $what eq "group_change") {
        if ($uid != $org_uid) {
            if ($uids{$org_type}{$org_uid} > 0) {
		$uids{$org_type}{$org_uid}	= $uids{$org_type}{$org_uid} - 1;
	    }
            $uids{$type}{$uid}		= ($uids{$type}{$uid} || 0) + 1;
	    if (($removed_uids{$type}{$uid} || 0) > 0) {
		$removed_uids{$type}{$uid} 	= $removed_uids{$type}{$uid} - 1;
	    }
	    $removed_uids{$org_type}{$org_uid}	= ($removed_uids{$type}{$uid} || 0) + 1;
	    y2debug ("uid of user $username changed from $org_uid to $uid");
	}
        if ($home ne $org_home || $type ne $org_type) {
            delete $homes{$org_type}{$org_home};
            $homes{$type}{$home}	= 1;
        }
        if ($username ne $org_username || $type ne $org_type) {
            delete $usernames{$org_type}{$org_username};
            $usernames{$type}{$username}			= 1;
	    if (defined $removed_usernames{$type}{$username}) {
		delete $removed_usernames{$type}{$username};
	    }
	    $removed_usernames{$org_type}{$org_username}	= 1;
	    if ($type eq "ldap") {
		delete $userdns{$org_dn};
		$userdns{$dn}	= 1;
	    }
        }
	if ($use_gui) {
	    delete $user_items{$org_type}{$org_username};
	    $user_items{$type}{$username}	= $self->BuildUserItem (\%user);

	    if ($what ne "group_change") {
		$focusline_user 	= $username;
	    }
	    if ($org_type ne $type) {
		undef $focusline_user;
	    }
	}
    }
    elsif ($what eq "delete_user") {
	if ($type eq "ldap") {
		delete $userdns{$org_dn};
	}
        if (($uids{$type}{$uid} || 0) > 0) {
	    $uids{$type}{$uid}	= $uids{$type}{$uid} - 1;
	}
        delete $homes{$type}{$home};
        delete $usernames{$type}{$username};

	$removed_uids{$type}{$uid}		= ($removed_uids{$type}{$uid} || 0) + 1;
	$removed_usernames{$type}{$username}	= 1;

	if ($use_gui) {
	    delete $user_items{$type}{$username};
	    undef $focusline_user;
	}
    }
}

##------------------------------------
# Update the cache after changing group
# @param group the group's map
BEGIN { $TYPEINFO{CommitGroup} = ["function",
    "void",
    ["map", "string", "any" ]];
}
sub CommitGroup {

    my $self		= shift;
    my %group		= %{$_[0]};
    my $what		= $group{"what"} || "";
    my $type		= $group{"type"} || ""; 

    my $org_type	= $group{"org_type"} || $type;
    my $groupname	= $group{"cn"} || "";
    my $org_groupname	= $group{"org_cn"} || $groupname;
    my $gid		= $group{"gidNumber"};
    my $org_gid		= $group{"org_gidNumber"} || $gid;

    if ($what eq "add_group") {
        $gids{$type}{$gid}		= ($gids{$type}{$gid} || 0) + 1;
        $groupnames{$type}{$groupname}	= 1;
	if ($use_gui) {
	    $group_items{$type}{$groupname}	= $self->BuildGroupItem (\%group);
	    $focusline_group 		= $groupname;
	}
    }
    if ($what eq "edit_group") {
        if ($gid != $org_gid) {
	    if (($gids{$org_type}{$org_gid} || 0) > 0) {
                $gids{$org_type}{$org_gid}	= $gids{$org_type}{$org_gid} - 1;
	    }
            $gids{$type}{$gid}			= ($gids{$type}{$gid} || 0) + 1;
        }
        if ($groupname ne $org_groupname || $type ne $org_type) {
            delete $groupnames{$org_type}{$org_groupname};
            $groupnames{$type}{$groupname}			= 1;
        }
	$focusline_group = $groupname;
    }
    if ($what eq "edit_group" || $what eq "user_change" ||
        $what eq "user_change_default") {

	if ($use_gui) {
	    delete $group_items{$org_type}{$org_groupname};
	    $group_items{$type}{$groupname}	= $self->BuildGroupItem (\%group);
	}
	if ($org_type ne $type) {
	    undef $focusline_group;
	}
    }
    if ($what eq "delete_group") {
	if (($gids{$org_type}{$org_gid} || 0) > 0) {
            $gids{$org_type}{$org_gid}	= $gids{$org_type}{$org_gid} - 1;
	}
        delete $groupnames{$org_type}{$org_groupname};
	if ($use_gui) {
	    delete $group_items{$org_type}{$org_groupname};
	    undef $focusline_group;
	}
    }
}


##-------------------------------------------------------------------------
##----------------- read routines -----------------------------------------
    
##------------------------------------
# initialize constants with the values from Security module
BEGIN { $TYPEINFO{InitConstants} = ["function",
    "void",
    ["map", "string", "string" ]];
}
sub InitConstants {

    my $self		= shift;
    my $security	= $_[0];
    if (ref ($security) ne "HASH") {
	return undef;
    }

    $min_uid{"local"}	= $security->{"UID_MIN"}	|| $min_uid{"local"};
    $max_uid{"local"}	= $security->{"UID_MAX"}	|| $max_uid{"local"};

    $min_uid{"system"}	= $security->{"SYS_UID_MIN"} || $min_uid{"system"};
    $max_uid{"system"}	= $security->{"SYS_UID_MAX"} || $max_uid{"system"};

    $min_gid{"local"}	= $security->{"GID_MIN"}	|| $min_gid{"local"};
    $max_gid{"local"}	= $security->{"GID_MAX"}	|| $max_gid{"local"};

    $min_gid{"system"}	= $security->{"SYS_GID_MIN"} || $min_gid{"system"};
    $max_gid{"system"}	= $security->{"SYS_GID_MAX"} || $max_gid{"system"};
}

##------------------------------------
# This is used when users are read some other way than using ag-passwd, e.g.
# for autoinstallation configuration
BEGIN { $TYPEINFO{BuildUserLists} = ["function",
    "void",
    ["map", "integer", [ "map", "string", "any"]] ];
}
sub BuildUserLists {

    my $self		= shift;
    my $type		= $_[0];
    my %map_of_users	= %{$_[1]};
    $uids{$type}	= {};
    $homes{$type}	= {};
    $usernames{$type}	= {};

    foreach my $uid (keys %map_of_users) {
        $uids{$type}{$uid}	= ($uids{$type}{$uid} || 0) + 1;
	my $username		= $map_of_users{$uid}{"uid"};
	if (defined ($username)) {
	    $usernames{$type}{$username}	= 1;
	}
	my $home	= $map_of_users{$uid}{"homeDirectory"};
	if (defined ($home)) {
	    $homes{$type}{$home}	= 1;
	}
    }
}

##------------------------------------
# This is used when groups are read some other way than using ag-passwd, e.g.
# for autoinstallation configuration
BEGIN { $TYPEINFO{BuildGroupLists} = ["function",
    "void",
    ["map", "integer", [ "map", "string", "any"]] ];
}
sub BuildGroupLists {

    my $self		= shift;
    my $type		= $_[0];
    my %map_of_groups	= %{$_[1]};
    $gids{$type}	= {};
    $groupnames{$type}	= {};

    foreach my $gid (keys %map_of_groups) {
        $gids{$type}{$gid}	= ($gids{$type}{$gid} || 0) + 1;
	my $groupname		= $map_of_groups{$gid}{"cn"};
	if (defined ($groupname)) {
	    $groupnames{$type}{$groupname}	= 1;
	}
    }
}


##------------------------------------
sub ReadUsers {

    my $self	= shift;
    my $type	= $_[0];

    if ($type eq "ldap") {
        %userdns	= %{SCR->Read (".ldap.users.userdns")};
    }
    elsif ($type ne "nis") { # only local/system
	$self->SetLastUID (UsersPasswd->GetLastUID ($type), $type);
	$homes{$type} 		= UsersPasswd->GetHomes ($type);
	$usernames{$type}	= UsersPasswd->GetUsernames ($type);
	$uids{$type}		= UsersPasswd->GetUIDs ($type);
	return 1;
    }

    $homes{$type} 	= \%{SCR->Read (".$type.users.homes")};
    $usernames{$type}	= \%{SCR->Read (".$type.users.usernames")};
    $uids{$type}	= \%{SCR->Read (".$type.users.uids")};
    return 1;
}

##------------------------------------
sub ReadGroups {

    my $self	= shift;
    my $type	= shift;

    if ($type eq "local" || $type eq "system") {
	# only adapt to minimal value
	$self->SetLastGID ($min_gid{$type}, $type);
	$gids{$type}		= UsersPasswd->GetGIDs ($type);
	$groupnames{$type}	= UsersPasswd->GetGroupnames ($type);
	return 1;
    }
    $gids{$type}	= \%{SCR->Read (".$type.groups.gids")};
    $groupnames{$type}	= \%{SCR->Read (".$type.groups.groupnames")};
    return 1;
}


##------------------------------------
BEGIN { $TYPEINFO{Read} = ["function", "void"];}
sub Read {

    my $self	= shift;

    # read cache data for local & system: passwd agent:
    $self->ReadUsers ("local");
    $self->ReadUsers ("system");

    $self->ReadGroups ("local");
    $self->ReadGroups ("system");
}

##-------------------------------------------------------------------------

# create a term with list of users available as members of given group
BEGIN { $TYPEINFO{BuildAdditional} = ["function",
    ["list", "term"],
    ["map", "string", "any"]];
}
sub BuildAdditional {

    my $self		= shift;
    my $group		= $_[0];
    my @additional 	= ();
    my %additional	= ();
    my $true		= YaST::YCP::Boolean (1);
    my $false		= YaST::YCP::Boolean (0);
    
    # when LDAP/NIS users were not yet read, they are not in %usernames ->
    # check for userlist before going through %usernames
    foreach my $user (keys %{$group->{"userlist"}}) {
	my $id = YaST::YCP::Term ("id", $user);
	$additional{$user}	= YaST::YCP::Term ("item", $id, $user, $true);
    }

    foreach my $type (keys %usernames) {

	# LDAP groups can contain only LDAP users...
	if ($group_type eq "ldap") {
	    if ($type ne "ldap") { next; }
	    foreach my $dn (keys %userdns) {
	    
		my $id = YaST::YCP::Term ("id", $dn);
		if (defined $group->{Ldap->member_attribute ()}{$dn}) {
		    $additional{$dn} = YaST::YCP::Term("item", $id, $dn, $true);
		}
		elsif (!defined $group->{"more_users"}{$dn}) {
		    $additional{$dn} = YaST::YCP::Term("item", $id, $dn,$false);
		}
	    }
	    next;
	}
	foreach my $user (keys %{$usernames{$type}}) {
	
	    my $id = YaST::YCP::Term ("id", $user);
	    if (!defined $group->{"userlist"}{$user} &&
		!defined $group->{"more_users"}{$user}) {
		$additional{$user} = YaST::YCP::Term("item", $id, $user,$false);
	    }
	}
    }
    # to return list of terms sorted, use the hash with sortable keys:
    foreach my $key (sort keys %additional) {
	push @additional, $additional{$key};
    }
    return \@additional;
}

BEGIN { $TYPEINFO{SetGUI} = ["function", "void", "boolean"];}
sub SetGUI {
    my $self 		= shift;
    $use_gui 		= $_[0];
}

# reset the internal cache 
BEGIN { $TYPEINFO{ResetCache} = ["function", "void"];}
sub ResetCache {

    %usernames		= ();
    %homes		= ();
    %uids		= ();
    %user_items		= ();
    %userdns		= ();
    %groupnames		= ();
    %gids		= ();
}

1
# EOF
