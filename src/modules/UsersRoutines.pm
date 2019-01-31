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

use YaST::YCP qw(:LOGGING);

our %TYPEINFO;

 
##------------------------------------
##------------------- global imports

YaST::YCP::Import ("FileUtils");
YaST::YCP::Import ("Pam");
YaST::YCP::Import ("Report");
YaST::YCP::Import ("SCR");
YaST::YCP::Import ("String");

##------------------------------------
##------------------- global variables

# path to cryptconfig
my $cryptconfig		= "/usr/sbin/cryptconfig";

# path to pam_mount configuration file
my $pam_mount_path	= "/etc/security/pam_mount.conf.xml";

# 'volume' information from pam_mount (info about crypted homes)
my $pam_mount		= undef;

# owners of img files
my $img2user		= undef;

# owners of key files
my $key2user		= undef;

# could we use pam_mount? currntly not if fingerprint dev is in use (bnc#390810)
my $crypted_homes_enabled	= undef;

##-------------------------------------------------------------------------
##----------------- helper routines ---------------------------------------

##-------------------------------------------------------------------------
##----------------- directory manipulation routines -----------------------

##------------------------------------
# Create home directory
# @param skeleton skeleton directory for new home
# @param home name of new home directory
# @return success
BEGIN { $TYPEINFO{CreateHome} = ["function",
    "boolean",
    "string", "string", "string"];
}
sub CreateHome {

    my $self	= shift;
    my $skel	= $_[0];
    my $home	= $_[1];
    my $btrfs	= $_[2];

    # create a path to new home directory, if not exists
    my $home_path = substr ($home, 0, rindex ($home, "/"));
    if (length($home_path) and !%{SCR->Read (".target.stat", $home_path)}) {
	SCR->Execute (".target.mkdir", $home_path);
    }
    my %stat	= %{SCR->Read (".target.stat", $home)};
    if (%stat) {
        if ($home ne "/var/lib/nobody") {
	    y2error ("$home directory already exists: no mkdir");
	}
	return 0;
    }

    # if skeleton does not exist, do not copy it
    if ($skel eq "" || !%{SCR->Read (".target.stat", $skel)}) {
	if (! SCR->Execute (".target.mkdir", $home)) {
	    y2error ("error creating $home");
	    return 0;
	}
    }
    # now copy homedir from skeleton
    else {
	my $command	= "/usr/bin/cp -r '".String->Quote($skel)."' '".String->Quote($home)."'";
	my %out		= %{SCR->Execute (".target.bash_output", $command)};
	if (($out{"stderr"} || "") ne "") {
	    y2error ("error calling $command: ", $out{"stderr"} || "");
	    return 0;
	}
	y2usernote ("Home directory created: '$command'.");
    }
    y2milestone ("The directory $home was successfully created.");
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

    my $self	= shift;
    my $home	= $_[0];

    my %stat	= %{SCR->Read (".target.stat", $home)};
    if (!%stat || !($stat{"isdir"} || 0)) {
	y2warning("home directory does not exist or is not a directory: no rm");
	return 1;
    }
    my $command	= "/usr/bin/rm -rf '".String->Quote($home)."'";
    my %out	= %{SCR->Execute (".target.bash_output", $command)};
    if (($out{"stderr"} || "") ne "") {
	y2error ("error calling $command: ", $out{"stderr"} || "");
	return 0;
    }
    y2milestone ("The directory $home was succesfully deleted");
    y2usernote ("Home directory removed: '$command'");
    return 1;
}

##------------------------------------
# Delete the crypted directory
# @param home path to home directory
# @param user name (to know the key and img name)
# @return success
BEGIN { $TYPEINFO{DeleteCryptedHome} = ["function", "boolean", "string", "string"];}
sub DeleteCryptedHome {

    my $self		= shift;
    my $home		= shift;
    my $username	= shift;
    my $ret		= 1;

    return 0 if ((not defined $home) || (not defined $username));

    my $img_path	= $self->CryptedImagePath ($username);
    my $key_path	= $self->CryptedKeyPath ($username);

    if (%{SCR->Read (".target.stat", $key_path)}) {
	my $cmd	= "/usr/bin/rm -rf '".String->Quote($key_path)."'";
	my $out	= SCR->Execute (".target.bash_output", $cmd);
	if (($out->{"exit"} || 0) ne 0) {
	    y2error ("error while removing $key_path file: ", $out->{"stderr"} || "");
	    $ret	= 0;
	}
	y2usernote ("Encrypted directory key removed: '$cmd'");
    }
    if (%{SCR->Read (".target.stat", $img_path)}) {
	my $cmd	= "/usr/bin/rm -rf '".String->Quote($img_path)."'";
	my $out	= SCR->Execute (".target.bash_output", $cmd);
	if (($out->{"exit"} || 0) ne 0) {
	    y2error ("error while removing $img_path file: ", $out->{"stderr"} || "");
	    $ret	= 0;
	}
	y2usernote ("Encrypted directory image removed: '$cmd'");
	$cmd	= "$cryptconfig pm-disable '".String->Quote($username)."'";
	$out	= SCR->Execute (".target.bash_output", $cmd);
	if ($out->{"exit"} ne 0 && $out->{"stderr"}) {
	    y2error ("error calling $cmd: ", $out->{"stderr"});
	    Report->Error ($out->{"stderr"});
	    $ret	= 0;
	}
	y2usernote ("Disabled pam_mount for $username: '$cmd'");
    }
    return $ret;
}

##------------------------------------
# Return size of given file in MB (rounded down)
# @param path to file
# @return size
BEGIN { $TYPEINFO{FileSizeInMB} = ["function", "string", "string"];}
sub FileSizeInMB {
    my $self    = shift;
    my $file	= shift;

    return "0" if not defined $file;

    my $stat	= SCR->Read (".target.stat", $file);

    my $size	= $stat->{"size"};
    return "0" if not $size;

    my $mb	= 1024 * 1024;
    return ($size < $mb) ? "1" : sprintf ("%i", $size / $mb);
}

# Read the 'volume' data from pam_mount config file and fill in the global map
BEGIN { $TYPEINFO{ReadCryptedHomesInfo} = ["function", "boolean"];}
sub ReadCryptedHomesInfo {

    return 1 if (defined $pam_mount);
    y2milestone ("pam_mount not read yet, doing it now");
    if (FileUtils->Exists ($pam_mount_path)) {
	my $pam_mount_cont	= SCR->Read (".anyxml", $pam_mount_path);
	if (defined $pam_mount_cont &&
	    defined $pam_mount_cont->{"pam_mount"}[0]{"volume"})
	{
	    my $volumes	= $pam_mount_cont->{"pam_mount"}[0]{"volume"};
	    if (ref ($volumes) eq "ARRAY") {
		foreach my $usermap (@{$volumes}) {
		    my $username	= $usermap->{"user"};
		    next if !defined $username;
		    $pam_mount->{$username}	= $usermap;
		    my $img	= $usermap->{"path"} || "";
		    $img2user->{$img}	= $username if $img;
		    my $key	= $usermap->{"fskeypath"} || "";
		    $key2user->{$key}	= $username if $key;
		}
	    }
	}
	return 1 if defined $pam_mount;
    }
    else {
	y2milestone ("file $pam_mount_path not found");
	$pam_mount	= {};
    }
    return 0;
}

##------------------------------------
# Return the owner of given crypted directory image
# @param image name
# @return string
BEGIN { $TYPEINFO{CryptedImageOwner} = ["function", "string", "string"];}
sub CryptedImageOwner {

    my $self    = shift;
    my $img_file= shift;

    if ($self->ReadCryptedHomesInfo ()) {
	return $img2user->{$img_file} || "";
    }
    return "";
}

##------------------------------------
# Return the owner of given crypted directory key
# @param key name
# @return string
BEGIN { $TYPEINFO{CryptedKeyOwner} = ["function", "string", "string"];}
sub CryptedKeyOwner {

    my $self    = shift;
    my $key_file= shift;

    if ($self->ReadCryptedHomesInfo ()) {
	return $key2user->{$key_file} || "";
    }
    return "";
}

##------------------------------------
# Return the path to user's crypted directory image; returns empty string if there is none defined
# @param user name
# @return string
BEGIN { $TYPEINFO{CryptedImagePath} = ["function", "string", "string"];}
sub CryptedImagePath {

    my $self    = shift;
    my $user	= shift;

    if ($self->ReadCryptedHomesInfo ()) {
	return $pam_mount->{$user}{"path"} || "";
    }
    return "";
}

##------------------------------------
# Return the path to user's crypted directory key; returns empty string if there is none defined
# @param user name
# @return string
BEGIN { $TYPEINFO{CryptedKeyPath} = ["function", "string", "string"];}
sub CryptedKeyPath {

    my $self    = shift;
    my $user	= shift;

    if ($self->ReadCryptedHomesInfo ()) {
	return $pam_mount->{$user}{"fskeypath"} || "";
    }
    return "";
}


1
# EOF
