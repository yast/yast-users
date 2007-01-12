#! /usr/bin/perl -w
#
# UsersRoutines module
#


package UsersRoutines;

use strict;

use YaST::YCP qw(:LOGGING);

our %TYPEINFO;

 
##------------------------------------
##------------------- global imports

YaST::YCP::Import ("SCR");

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

    # create a path to new home directory, if not exists
    my $home_path = substr ($home, 0, rindex ($home, "/"));
    if (!%{SCR->Read (".target.stat", $home_path)}) {
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
	my $command	= "/bin/cp -r $skel $home";
	my %out		= %{SCR->Execute (".target.bash_output", $command)};
	if (($out{"stderr"} || "") ne "") {
	    y2error ("error calling $command: ", $out{"stderr"} || "");
	    return 0;
	}
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

    my $command = "/bin/chown -R $uid:$gid $home";
    my %out	= %{SCR->Execute (".target.bash_output", $command)};
    if (($out{"stderr"} || "") ne "") {
	y2error ("error calling $command: ", $out{"stderr"} || "");
	return 0;
    }
    y2milestone ("Owner of files in $home changed to user with UID $uid");
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

    my $command = "/bin/chmod $mode $home";
    my %out	= %{SCR->Execute (".target.bash_output", $command)};
    if (($out{"stderr"} || "") ne "") {
	y2error ("error calling $command: ", $out{"stderr"} || "");
	return 0;
    }
    y2milestone ("Mode of directory $home changed to $mode");
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

    my $command = "/bin/mv $org_home $home";
    my %out	= %{SCR->Execute (".target.bash_output", $command)};
    if (($out{"stderr"} || "") ne "") {
	y2error ("error calling $command: ", $out{"stderr"} || "");
	return 0;
    }
    y2milestone ("The directory $org_home was successfully moved to $home");
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
    my $command	= "/bin/rm -rf $home";
    my %out	= %{SCR->Execute (".target.bash_output", $command)};
    if (($out{"stderr"} || "") ne "") {
	y2error ("error calling $command: ", $out{"stderr"} || "");
	return 0;
    }
    y2milestone ("The directory $home was succesfully deleted");
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
    
    my $home_path 	= substr ($home, 0, rindex ($home, "/"));
    my $path		= "$home_path/$username";

    my $ret		= 1;

    return 0 if ((not defined $home) || (not defined $username));

    if (%{SCR->Read (".target.stat", "$path.img")}) {
	my $out     = SCR->Execute (".target.bash_output", "/bin/rm -rf $path.img");
	if (($out->{"exit"} || 0) ne 0) {
	    y2error ("error while removing $path.img file: ", $out->{"stderr"} || "");
	    $ret	= 0;
	}
    }
    if (%{SCR->Read (".target.stat", "$path.key")}) {
	my $out     = SCR->Execute (".target.bash_output", "/bin/rm -rf $path.key");
	if (($out->{"exit"} || 0) ne 0) {
	    y2error ("error while removing $path.key file: ", $out->{"stderr"} || "");
	    $ret	= 0;
	}
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

    return "0" if not defined $stat->{"size"};
    return sprintf ("%i", $stat->{"size"} / (1024 * 1024));
}

1
# EOF
