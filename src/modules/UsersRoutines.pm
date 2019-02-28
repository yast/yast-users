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
# UsersRoutines module
#

package UsersRoutines;

use strict;

use File::Basename;
use YaST::YCP qw(:LOGGING);

our %TYPEINFO;


##------------------------------------
##------------------- global imports

YaST::YCP::Import ("FileUtils");
YaST::YCP::Import ("Report");
YaST::YCP::Import ("SCR");
YaST::YCP::Import ("String");

##------------------------------------
##------------------- global variables

# path to btrfs
my $btrfs = "/usr/sbin/btrfs";

##-------------------------------------------------------------------------
##----------------- helper routines ---------------------------------------

sub btrfs_subvolume {
    my $path = shift;
    my $cmd  = "$btrfs subvolume show $path";

    return ( SCR->Execute( ".target.bash", $cmd ) eq 0 );
}

##-------------------------------------------------------------------------
##----------------- directory manipulation routines -----------------------

##------------------------------------
# Create home directory
# @param skeleton skeleton directory for new home
# @param home name of new home directory
# @param use_btrfs whether the home directory must be a btrfs subvolume
# @return success
BEGIN { $TYPEINFO{CreateHome} = ["function",
    "boolean",
    "string", "string", "string"];
}
sub CreateHome {

    my $self = shift;
    my ( $skel, $home, $use_btrfs ) = @_;

    # Create a path to new home directory, if not exists
    my $home_path = substr( $home, 0, rindex( $home, "/" ) );
    if ( length($home_path) and !%{ SCR->Read( ".target.stat", $home_path ) } )
    {
        SCR->Execute( ".target.mkdir", $home_path );
    }

    my %stat = %{ SCR->Read( ".target.stat", $home ) };
    if (%stat) {
        if ( $home ne "/var/lib/nobody" ) {
            y2error("$home directory already exists: no mkdir");
        }
        return 0;
    }

    # Create the home as btrfs subvolume
    if ($use_btrfs) {
        my $cmd = "btrfs subvolume create $home";
        my %cmd_out = %{ SCR->Execute( ".target.bash_output", $cmd ) };
        my $stderr = $cmd_out{"stderr"} || "";
        if ($stderr)
        {
            y2error("Error creating '$home' as btrfs subvolume: $stderr");

            return 0;
        }
    }
    # or as a plain directory
    else {
        if ( !SCR->Execute( ".target.mkdir", $home ) ) {
            y2error("Error creating '$home'");

            return 0;
        }
    }

    # Now copy the skeleton
    if ( $skel ne "" && %{ SCR->Read( ".target.stat", $skel ) } ) {
        my $cmd = sprintf(
            "/usr/bin/cp -r '%s/.' '%s'",
            String->Quote($skel),
            String->Quote($home)
        );
        my %cmd_out = %{ SCR->Execute( ".target.bash_output", $cmd ) };
        my $stderr = $cmd_out{"stderr"} || "";

        if ( $stderr ne "" ) {
            y2error( "Error calling $cmd: $stderr" );
            return 0;
        }

        y2usernote("Home skeleton copied: '$cmd'.");
    }

    y2milestone("The directory $home was successfully created.");

    return 1;
}

##------------------------------------
# Change ownership of directory
# @param uid UID of new owner
# @param gid GID of new owner's default group
# @param home name of new home directory
# @return success
BEGIN { $TYPEINFO{ChownHome} = ["function",
    "boolean",
    "integer", "integer", "string"];
}
sub ChownHome {

    my $self	= shift;
    my $uid	= $_[0];
    my $gid	= $_[1];
    my $home	= $_[2];

    my %stat	= %{SCR->Read (".target.stat", $home)};
    if (!%stat || !($stat{"isdir"} || 0)) {
	y2warning ("directory does not exist or is not a directory: no chown");
	return 0;
    }

    if (($uid == ($stat{"uid"} || -1)) && ($gid == ($stat{"gid"} || -1))) {
	y2milestone ("directory already exists and chown is not needed");
	return 1;
    }

    my $command = "/usr/bin/chown -R $uid:$gid '".String->Quote($home)."'";
    my %out	= %{SCR->Execute (".target.bash_output", $command)};
    if (($out{"stderr"} || "") ne "") {
	y2error ("error calling $command: ", $out{"stderr"} || "");
	return 0;
    }
    y2milestone ("Owner of files in $home changed to user with UID $uid");
    y2usernote ("Home directory ownership changed: '$command'");
    return 1;
}

##------------------------------------
# Change mode of directory
# @param home name of new home directory
# @param mode for the directory
# @return success
BEGIN { $TYPEINFO{ChmodHome} = ["function",
    "boolean",
    "integer", "integer", "string"];
}
sub ChmodHome {

    my $self	= shift;
    my $home	= shift;
    my $mode	= shift;

    if (!defined $home || !defined $mode) {
	y2error ("missing arguments");
	return 0;
    }

    my $command = "/usr/bin/chmod $mode '".String->Quote($home)."'";
    my %out	= %{SCR->Execute (".target.bash_output", $command)};
    if (($out{"stderr"} || "") ne "") {
	y2error ("error calling $command: ", $out{"stderr"} || "");
	return 0;
    }
    y2milestone ("Mode of directory $home changed to $mode");
    y2usernote ("Home directory mode changed: '$command'");
    return 1;
}

##------------------------------------
# Move the directory
# @param org_home original name of directory
# @param home name of new home directory
# @return success
BEGIN { $TYPEINFO{MoveHome} = ["function",
    "boolean",
    "string", "string"];
}
sub MoveHome {

    my $self		= shift;
    my $org_home	= $_[0];
    my $home		= $_[1];

    # create a path to new home directory, if it not exists
    my $home_path = substr ($home, 0, rindex ($home, "/"));
    if (!%{SCR->Read (".target.stat", $home_path)}) {
	SCR->Execute (".target.mkdir", $home_path);
    }
    my %stat	= %{SCR->Read (".target.stat", $home)};
    if (%stat) {
	y2warning ("new home directory ('$home') already exist: do not move '$org_home' here");
	return 0;
    }

    %stat	= %{SCR->Read (".target.stat", $org_home)};
    if (!%stat || !($stat{"isdir"} || 0)) {
	y2warning ("old home does not exist or is not a directory: no moving");
	return 0;
    }
    if ($org_home eq "/var/lib/nobody") {
	y2warning ("no, don't move /var/lib/nobody elsewhere...");
	return 0;
    }

    my $command = "/usr/bin/mv '".String->Quote($org_home)."' '".String->Quote($home)."'";
    my %out	= %{SCR->Execute (".target.bash_output", $command)};
    if (($out{"stderr"} || "") ne "") {
	y2error ("error calling $command: ", $out{"stderr"} || "");
	return 0;
    }
    y2milestone ("The directory $org_home was successfully moved to $home");
    y2usernote ("Home directory moved: '$command'");
    return 1;
}

##------------------------------------
# Delete the directory
# @param home name of directory
# @return success
BEGIN { $TYPEINFO{DeleteHome} = ["function", "boolean", "string"];}
sub DeleteHome {

    my $self = shift;
    my $home = $_[0];
    my %stat = %{ SCR->Read( ".target.stat", $home ) };

    if ( !%stat || !( $stat{"isdir"} || 0 ) ) {
        y2warning("home directory '$home' does not exist or is not a directory: no rm");
        return 1;
    }

    my $cmd;
    my $type;

    if ( btrfs_subvolume($home) ) {
        $cmd  = sprintf( "$btrfs subvolume delete -C '%s'", String->Quote($home) );
        $type = "btrfs subvolume";
    }
    else {
        $cmd  = sprintf( "/usr/bin/rm -rf '%s'", String->Quote($home) );
        $type = "directory";
    }

    my %cmd_output = %{ SCR->Execute( ".target.bash_output", $cmd ) };
    my $stderr  = $cmd_output{"stderr"} || "";

    if ( $stderr ne "" ) {
        y2error( "Error calling '$cmd': $stderr" );

        return 0;
    }

    y2milestone("The $type '$home' was succesfully deleted");
    y2usernote("Home $type removed: '$cmd'");

    return 1;
}

1
# EOF
