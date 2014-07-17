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
# This is the API part of UsersPluginQuota plugin:
# configuration of user and group quota (feature 120106)
#
# For documentation and examples of function arguments and return values, see
# UsersPluginLDAPAll.pm

package UsersPluginQuota;

use strict;

use YaST::YCP qw(:LOGGING sformat);
use YaPI;
use Data::Dumper;

textdomain("users");

our %TYPEINFO;

##--------------------------------------
##--------------------- global imports

YaST::YCP::Import ("SCR");

##--------------------------------------
##--------------------- global variables

# error message, returned when some plugin function fails
my $error	= "";

# internal name
my $name	= "UsersPluginQuota";

# is quota available and set up
my $quota_available	= undef;

# list of keys uses in quota map
my @quota_keys	= ("quota_blocks_soft", "quota_blocks_hard",
    "quota_inodes_soft", "quota_inodes_hard",
    "quota_blocks_grace", "quota_inodes_grace");

# list of filesystems with quota enabled
my @quota_enabled_filesystems	= ();

##----------------------------------------
##--------------------- internal functions

# internal function:
# check if given key (second parameter) is contained in a list (1st parameter)
# if 3rd parameter is true (>0), ignore case
sub contains {
    my ($list, $key, $ignorecase) = @_;
    if (!defined $list || ref ($list) ne "ARRAY" || @{$list} == 0) {
	return 0;
    }
    if ($ignorecase) {
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

# update the object data when removing plugin
sub remove_plugin_data {

    my ($config, $data) = @_;
    foreach my $key (@quota_keys) {
	my $i	= 0;
	foreach my $qmap (@{$data->{"quota"}}) {
	    $data->{"quota"}[$i]{$key} = 0 if defined $data->{"quota"}[$i]{$key};
	    $i	= $i + 1;
	}
    }
    $data->{"plugin_modified"}	= 1;
    return $data;
}

# check which filesystems have quota support enabled
sub get_quota_enabled_filesystems {

    if (! @quota_enabled_filesystems) {
	my $cmd	= "LANG=C grep quota /etc/mtab | cut -f 1 -d ' '";
	my $out	= SCR->Execute (".target.bash_output", $cmd);
	if ($out->{"stdout"}) {
	    # each line in stdout reports quota for one filesystem
	    foreach my $line (split (/\n/, $out->{"stdout"})) {
		chomp $line;
		push @quota_enabled_filesystems, $line if $line;
	    }
	}
    }
    return @quota_enabled_filesystems;
}

# Read the quota information for given user/group and return the object
# map updated with the quota data.
sub read_quota_info {

    my ($config, $data) = @_;

    if (!defined $data->{"quota"}) {

	my $opt	= "-u ".$data->{"uid"} if defined $data->{"uid"};
	if ($config->{"what"} eq "group") {
	    $opt	= "-g ".$data->{"cn"} if defined $data->{"cn"};
	}
	return $data if not defined $opt;

	my %fsystems	= ();
	my @quotalist	= ();

	my $cmd	= "LANG=C quota $opt -pv 2>/dev/null | tail +3";
	my $out	= SCR->Execute (".target.bash_output", $cmd);
	if ($out->{"stdout"}) {
	    # each line in stdout reports quota for one filesystem
	    foreach my $line (split (/\n/, $out->{"stdout"})) {
		chomp $line;
		$line	=~ s/^\s+//; # remove the leading space
		my @l	= split (/\s+/, $line);
		if (@l == 9) {
		    my %item    = ();
		    $fsystems{$l[0]}		= 1;
		    $item{"quota_fs"}		= $l[0];
		    $item{"quota_blocks_soft"}	= $l[2];
		    $item{"quota_blocks_hard"}	= $l[3];
		    $item{"quota_inodes_soft"}	= $l[6];
		    $item{"quota_inodes_hard"}	= $l[7];
		    $item{"quota_blocks_grace_exceeded"} = 1 if $l[4] > 0;
		    $item{"quota_inodes_grace_exceeded"} = 1 if $l[8] > 0;
		    push @quotalist, \%item if %item;
		}
	    }
	}
	# Add empty maps for the filesystems with quota support enabled but
	# without quota set for this user/group
	foreach my $fs (get_quota_enabled_filesystems ()) {
	    if (!defined $fsystems{$fs}) {
		push @quotalist, { "quota_fs"  => $fs };
	    }
	}
	$data->{"quota"}	= \@quotalist if @quotalist;
    }
    return $data;
}

# check if quota is available and configured (globally)
sub is_quota_available {

    return $quota_available if defined $quota_available;
    if (not Package->Installed ("quota")) {
	$quota_available	= 0;
    }
    else {
	$quota_available	= (Service->Status ("quotaon") == 0);
    }
    return $quota_available;
}

# check if user/group has quota enabled
sub has_quota {

    my $opt = shift;
    my $out = SCR->Execute (".target.bash_output", "LANG=C quota $opt -v 2>/dev/null | tail +3");
    return ($out->{"stdout"});
}

##------------------------------------------
##--------------------- global API functions

# All functions have 2 "any" parameters: these mean:
# 1st: configuration map (hash) - e.g. saying if we work with user or group
# 2nd: data map (hash) of user/group to work with
# for details, see UsersPluginLDAPAll.pm

# Return the names of provided functions
BEGIN { $TYPEINFO{Interface} = ["function", ["list", "string"], "any", "any"];}
sub Interface {

    my $self		= shift;
    my @interface 	= (
	    "GUIClient",
	    "Name",
	    "Summary",
	    "Restriction",
	    "Write",
	    "Add",
	    "AddBefore",
	    "Edit",
	    "EditBefore",
	    "Interface",
	    "PluginPresent",
	    "PluginRemovable",
	    "Error",
    );
    return \@interface;
}

# return error message, generated by plugin
BEGIN { $TYPEINFO{Error} = ["function", "string", "any", "any"];}
sub Error {

    return $error;
}


# return plugin name, used for GUI (translated)
BEGIN { $TYPEINFO{Name} = ["function", "string", "any", "any"];}
sub Name {

    # plugin name
    return __("Quota Configuration");
}

##------------------------------------
# Return plugin summary (to be shown in table with all plugins)
BEGIN { $TYPEINFO{Summary} = ["function", "string", "any", "any"];}
sub Summary {

    my ($self, $config, $data)  = @_;

    # user plugin summary (table item)
    return __("Manage Group Quota") if ($config->{"what"} eq "group");

    # user plugin summary (table item)
    return __("Manage User Quota");
}

##------------------------------------
# Checks the current data map of user/group (2nd parameter) and returns
# true if given user/group has this plugin enabled
BEGIN { $TYPEINFO{PluginPresent} = ["function", "boolean", "any", "any"];}
sub PluginPresent {

    return 0 if not is_quota_available ();

    my ($self, $config, $data)  = @_;
    my $opt	= "-u ".$data->{"uid"} if defined $data->{"uid"};
    if ($config->{"what"} eq "group") {
	$opt	= "-g ".$data->{"cn"};
    }
    return 0 if not $opt;
    if (contains ($data->{'plugins'}, $name, 1) || has_quota ($opt)) {
	y2milestone ("Quota plugin present");
	return 1;
    } else {
	y2debug ("Quota plugin not present");
	return 0;
    }
}

##------------------------------------
# Is it possible to remove this plugin from user/group: setting all quota
# values to 0.
BEGIN { $TYPEINFO{PluginRemovable} = ["function", "boolean", "any", "any"];}
sub PluginRemovable {

    return YaST::YCP::Boolean (1);
}


##------------------------------------
# Return name of YCP client defining YCP GUI
BEGIN { $TYPEINFO{GUIClient} = ["function", "string", "any", "any"];}
sub GUIClient {

    return "users_plugin_quota";
}

##------------------------------------
# Type of objects this plugin is restricted to.
# Plugin is restricted to local users
BEGIN { $TYPEINFO{Restriction} = ["function",
    ["map", "string", "any"], "any", "any"];}
sub Restriction {

    return {
	    "local"	=> 1,
	    "group"	=> 1,
	    "user"	=> 1
    };
}


# this will be called at the beggining of Users::AddUser/AddGroup
# Check if it is possible to add this plugin here.
# (Could be called multiple times for one user/group)
BEGIN { $TYPEINFO{AddBefore} = ["function",
    ["map", "string", "any"],
    "any", "any"];
}
sub AddBefore {

    my ($self, $config, $data)  = @_;

    if (!contains ($data->{'plugins_to_remove'}, $name, 1) &&
	!is_quota_available ())
    {
	# error popup
	$error	= __("Quota is not enabled on your system.
Enable quota in the partition settings module.");
	return undef;
    }
    return $data;
}

# This will be called at the end of Users::Add* : modify the object map
# with quota data
BEGIN { $TYPEINFO{Add} = ["function", ["map", "string", "any"], "any", "any"];}
sub Add {

    my ($self, $config, $data)  = @_;
    y2debug ("Add Quota called");
    # "plugins_to_remove" is list of plugins which are set for removal
    if (contains ($data->{'plugins_to_remove'}, $name, 1)) {
	y2milestone ("removing plugin $name...");
	$data   = remove_plugin_data ($config, $data);
    }
    else {
	$data	= read_quota_info ($config, $data);
    }
    return $data;
}

# This will be called at the beggining of Users::EditUser/EditGroup
# Check if it is possible to add this plugin here.
# (Could be called multiple times for one user/group)
BEGIN { $TYPEINFO{EditBefore} = ["function",
    ["map", "string", "any"],
    "any", "any"];
}
sub EditBefore {

    my ($self, $config, $data)  = @_;

    if (!contains ($data->{'plugins_to_remove'}, $name, 1) &&
	!is_quota_available ())
    {
	# error popup
	$error	= __("Quota is not enabled on your system.
Enable quota in the partition settings module.");
	return undef;
    }
    return $data;
}

# This will be called at the end of Users::Edit* : modify the object map
# with quota data
BEGIN { $TYPEINFO{Edit} = ["function",
    ["map", "string", "any"],
    "any", "any"];
}
sub Edit {

    y2debug ("Edit Quota called");
    my ($self, $config, $data)  = @_;
    # "plugins_to_remove" is list of plugins which are set for removal
    if (contains ($data->{'plugins_to_remove'}, $name, 1)) {
	y2milestone ("removing plugin $name...");
	$data   = remove_plugin_data ($config, $data);
    }
    else {
	$data	= read_quota_info ($config, $data);
    }
    return $data;
}

# What should be done after user is finally written (this is called only once)
BEGIN { $TYPEINFO{Write} = ["function", "boolean", "any", "any"];}
sub Write {

    my ($self, $config, $data)  = @_;

    return YaST::YCP::Boolean (1) if not defined $data->{"quota"};

    # do nothing for user intended for deletion
    return YaST::YCP::Boolean (1) if ($config->{"modified"} || "") eq "deleted";

    my $opt	= "-u ".$data->{"uid"} if defined $data->{"uid"};
    if ($config->{"what"} eq "group") {
	$opt	= "-g ".$data->{"cn"};
    }
    return YaST::YCP::Boolean (1) if not $opt;
    
    foreach my $qmap (@{$data->{"quota"}}) {
	my $quota_blocks_soft	= $qmap->{"quota_blocks_soft"} || 0;    
	my $quota_blocks_hard	= $qmap->{"quota_blocks_hard"} || 0;    
	my $quota_inodes_soft	= $qmap->{"quota_inodes_soft"} || 0;    
	my $quota_inodes_hard	= $qmap->{"quota_inodes_hard"} || 0;    
	my $quota_blocks_grace	= $qmap->{"quota_blocks_grace"} || 0;
	my $quota_inodes_grace	= $qmap->{"quota_inodes_grace"} || 0;
	my $quota_fs		= $qmap->{"quota_fs"};
	next if not $quota_fs;
	my $cmd	= "setquota $opt $quota_blocks_soft $quota_blocks_hard $quota_inodes_soft $quota_inodes_hard $quota_fs";
	my $out	= SCR->Execute (".target.bash_output", $cmd);
	if ($out->{"exit"} && $out->{"stderr"}) {
	    y2error ("error calling $cmd: ", $out->{"stderr"});
	    # error popup, %1 is command, %2 command error output
	    $error	= sformat (__("Error while calling
\"%1\":
%2"), $cmd, $out->{"stderr"});
	    return YaST::YCP::Boolean (0);
	}
	if ($quota_blocks_grace > 0 || $quota_inodes_grace > 0) {
	    $cmd	= "setquota -T $opt $quota_blocks_grace $quota_inodes_grace $quota_fs";
	    $out	= SCR->Execute (".target.bash_output", $cmd);
	    if ($out->{"exit"} && $out->{"stderr"}) {
		y2error ("error calling $cmd: ", $out->{"stderr"});
		# error popup, %1 is command, %2 command error output
		$error	= sformat (__("Error while calling
\"%1\":
%2"), $cmd, $out->{"stderr"});
		return YaST::YCP::Boolean (0);
	    }
	}
    }
    return YaST::YCP::Boolean (1);
}
42
# EOF
