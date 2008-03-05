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

YaST::YCP::Import ("Report");
YaST::YCP::Import ("SCR");

##------------------------------------
##------------------- global variables

# path to cryptconfig
my $cryptconfig		= "/usr/sbin/cryptconfig";

# path to pam_mount configuration file
my $pam_mount_path	= "/etc/security/pam_mount.conf.xml";

# 'volume' information from pam_mount (info about crypted homes)
my $pam_mount		= undef;

##-------------------------------------------------------------------------
##----------------- helper routines ---------------------------------------

# set new path to cryptconfig
BEGIN { $TYPEINFO{SetCryptconfigPath} = ["function", "void", "string"]; }
sub SetCryptconfigPath {
    my $self		= shift;
    $cryptconfig	= shift;
}

# return current path to cryptconfig
BEGIN { $TYPEINFO{CryptconfigPath} = ["function", "string"]; }
sub CryptconfigPath {
    return $cryptconfig;
}

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
    my $ret		= 1;

    return 0 if ((not defined $home) || (not defined $username));

    my $img_path	= $self->CryptedImagePath ($username);
    my $key_path	= $self->CryptedKeyPath ($username);

    if (%{SCR->Read (".target.stat", $key_path)}) {
	my $out     = SCR->Execute (".target.bash_output", "/bin/rm -rf $key_path");
	if (($out->{"exit"} || 0) ne 0) {
	    y2error ("error while removing $key_path file: ", $out->{"stderr"} || "");
	    $ret	= 0;
	}
    }
    if (%{SCR->Read (".target.stat", $img_path)}) {
	my $out     = SCR->Execute (".target.bash_output", "/bin/rm -rf $img_path");
	if (($out->{"exit"} || 0) ne 0) {
	    y2error ("error while removing $img_path file: ", $out->{"stderr"} || "");
	    $ret	= 0;
	}
	my $command = "$cryptconfig pm-disable $username";
	$out	= SCR->Execute (".target.bash_output", $command);
	if ($out->{"exit"} ne 0 && $out->{"stderr"}) {
	    y2error ("error calling $command: ", $out->{"stderr"});
	    Report->Error ($out->{"stderr"});
	    $ret	= 0;
	}
    }
    return $ret;
}

##------------------------------------
# Adapt (=create/move/enlarge) the crypting of home directory
# @param user map
# @return success
BEGIN { $TYPEINFO{CryptHome} = ["function", "boolean", ["map", "string", "any"]];}
sub CryptHome {
    
    my $self		= shift;
    my $user		= shift;   

    my $username	= $user->{"uid"} || "";
    my $home		= $user->{"homedirectory"} || "";
    my $home_size   	= $user->{"crypted_home_size"} || 0;
    my $org_size 	= $user->{"org_user"}{"crypted_home_size"} || 0;
    my $org_home	= $user->{"org_user"}{"homedirectory"} || $home;
    my $org_username	= $user->{"org_user"}{"uid"} || $username;
    my $pw		= $user->{"current_text_userpassword"};
    my $new_pw		= $user->{"text_userpassword"};
    my $modified	= $user->{"modified"} || "nothing";

    if ($modified eq "added" && !defined $pw) {
	$pw		= $new_pw;
    }
    # now crypt the home directories
    my $tmpdir		= Directory->tmpdir ();

    my $pw_path	= "$tmpdir/pw";
    my $cmd		= "";


    my $key_file	= undef;
    my $image_file	= undef;
    # find the original image and key locations
    my $org_img		= $self->CryptedImagePath ($org_username);
    my $org_key		= $self->CryptedKeyPath ($org_username);

    # solve disabling of crypted directory
    if ($home_size == 0 && $org_size > 0 &&
	FileUtils->Exists ($org_key) && FileUtils->Exists ($org_img))
    {
	SCR->Write (".target.string", $pw_path, $pw);
	my $command = "$cryptconfig open --key-file=$org_key $org_img < $pw_path";
	y2debug ("cmd: $command");
	my $out	= SCR->Execute (".target.bash_output", $command);
	SCR->Execute (".target.remove", $pw_path);
	if ($out->{"exit"} ne 0) {
	    y2error ("error calling $command");
	    Report->Error ($out->{"stderr"}) if ($out->{"stderr"});
	    return 0;
	}
	my @stdout_l = split (/ /, $out->{"stdout"} || "");
	my $image_path	= pop @stdout_l;
	chop $image_path;
	if (!$image_path) {
	    y2error ("path to image could not be acquired from ", $out->{"stdout"} || "");
	    return 0;
	}
	my $mnt_dir	= "$tmpdir/mnt";
	SCR->Execute (".target.bash", "/bin/rm -rf $mnt_dir") if (FileUtils->Exists ($mnt_dir));
	SCR->Execute (".target.mkdir", $mnt_dir);
	$command = "mount -o loop $image_path $mnt_dir";
	y2debug ("cmd: $command");
	$out = SCR->Execute (".target.bash_output", $command);
	if ($out->{"exit"} ne 0 && $out->{"stderr"}) {
	    y2error ("error calling $command: ", $out->{"stderr"}); 
	    # TODO translated message for mount error
	    return 0;
	}
	# copy the directory content to tmp home
	$command = "/bin/cp -ar $mnt_dir $tmpdir/$username";
	y2debug ("cmd: $command");
	$out	= SCR->Execute (".target.bash_output", $command);
	if ($out->{"exit"} ne 0 && $out->{"stderr"}) {
	    y2error ("error calling $command: ", $out->{"stderr"});
	    return 0;
	}
	$command = "umount $mnt_dir";
	y2debug ("cmd: $command");
	$out = SCR->Execute (".target.bash_output", $command);
	if ($out->{"exit"} ne 0 && $out->{"stderr"}) {
	    y2error ("error calling $command: ", $out->{"stderr"}); 
	    return 0;
	}
	$command = "$cryptconfig pm-disable $username";
	y2debug ("cmd: $command");
	$out	= SCR->Execute (".target.bash_output", $command);
	if ($out->{"exit"} ne 0 && $out->{"stderr"}) {
	    y2error ("error calling $command: ", $out->{"stderr"});
	    Report->Error ($out->{"stderr"});
	    return 0;
	}
	$command = "$cryptconfig close $org_img";
	y2debug ("cmd: $command");
	$out	= SCR->Execute (".target.bash_output", $command);
	if ($out->{"exit"} ne 0 && $out->{"stderr"}) {
	    y2error ("error calling $command: ", $out->{"stderr"});
	    Report->Error ($out->{"stderr"});
	    return 0;
	}
	# Now, after everything succeeded, remove old home and replace it
	# with the data from crypted image:
	SCR->Execute (".target.bash", "/bin/rm -rf $home");
	$out = SCR->Execute (".target.bash_output", "/bin/mv $tmpdir/$username $home");
	y2error ("error while mv: ", $out->{"stderr"}) if ($out->{"stderr"});
	# remove image and key files
	SCR->Execute (".target.bash", "/bin/rm -rf $org_img");
	SCR->Execute (".target.bash", "/bin/rm -rf $org_key");
	return 1;
    }

    # check user renaming or directory move
    if ($home ne $org_home || $org_username ne $username) {
	if (FileUtils->Exists ($org_img)) {
	    $image_file	= "$home.img";
	    if ($org_img ne $image_file) {
		my $command = "/bin/mv $org_img $image_file";
		my %out	= %{SCR->Execute (".target.bash_output", $command)};
		if (($out{"stderr"} || "") ne "") {
		    y2error ("error calling $command: ", $out{"stderr"} || "");
		    return 0;
		}
	    }
	}
	if (FileUtils->Exists ($org_key)) {
	    $key_file	= "$home.key";
	    if ($org_key ne $key_file) {
		my $command = "/bin/mv $org_key $key_file";
		my %out	= %{SCR->Execute (".target.bash_output", $command)};
		if (($out{"stderr"} || "") ne "") {
		    y2error ("error calling $command: ", $out{"stderr"} || "");
		    return 0;
		}
	    }
	}
    }
    SCR->Write (".target.string", $pw_path, $pw);

    if (defined $key_file || defined $image_file) {
	$cmd = "$cryptconfig pm-enable --replace ";
	$cmd = $cmd."--key-file=$key_file " if defined $key_file;
	$cmd = $cmd."--image-file=$image_file " if defined $image_file;
	$cmd = $cmd."$username";
	y2debug ("cmd: $cmd");
	my $out = SCR->Execute (".target.bash_output", $cmd);
	if ($out->{"exit"} ne 0 && $out->{"stderr"}) {
	    Report->Error ($out->{"stderr"});
	    SCR->Execute (".target.remove", $pw_path);
	    return 0; 
	}
    }

    # now check if existing image doesn't need resizing
    $key_file	= $org_key if (!defined $key_file && FileUtils->Exists ($org_key));
    $image_file	= $org_img if (!defined $image_file && FileUtils->Exists ($org_img));
 
    # now solve user password change
    if ($modified eq "edited" && defined $key_file && defined $new_pw && $new_pw ne $pw) {
	SCR->Write (".target.string", $pw_path, "$pw\n$new_pw");
	my $command = "$cryptconfig passwd --no-verify $key_file < $pw_path";
	y2debug ("cmd: $command");
	my $out	= SCR->Execute (".target.bash_output", $command);
	if ($out->{"exit"} ne 0) {
	    y2error ("error calling $command");
	    SCR->Execute (".target.remove", $pw_path);
	    Report->Error ($out->{"stderr"}) if ($out->{"stderr"});
	    return 0;
	}
	# from now, new password is active
	SCR->Write (".target.string", $pw_path, $new_pw);
    }

    # resize existing image
    if ($org_size < $home_size && defined $key_file && defined $image_file) {
	my $add	= $home_size - $org_size;
	$cmd	=  "$cryptconfig enlarge-image --key-file=$key_file $image_file $add <  $pw_path";
    }
    # create new image
    elsif ($home_size > $org_size) {
        $cmd = "$cryptconfig make-ehd --no-verify $username $home_size < $pw_path";
    }
    # ok, only password change was needed
    else {
	y2debug ("nothing to do");
	SCR->Execute (".target.remove", $pw_path);
	return 1;
    }

    y2debug ("cmd: $cmd");
    my $out = SCR->Execute (".target.bash_output", $cmd);
    if ($out->{"exit"} ne 0 && $out->{"stderr"}) {
	Report->Error ($out->{"stderr"});
    }
    SCR->Execute (".target.remove", $pw_path);
    return 1;
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

# Read the 'volume' data from pam_mount config file and fill in the global map
BEGIN { $TYPEINFO{ReadCryptedHomesInfo} = ["function", "boolean"];}
sub ReadCryptedHomesInfo {

    return 1 if (defined $pam_mount);
    y2milestone ("pam_mount not read yet, doing it now");
    if (FileUtils->Exists ($pam_mount_path)) {
	my $pam_mount_cont	= SCR->Read (".anyxml", $pam_mount_path);
	if (defined $pam_mount_cont &&
	    defined $pam_mount_cont->{"pam_mount"}{"volume"})
	{
	    my $volumes	= $pam_mount_cont->{"pam_mount"}{"volume"};
	    if (ref ($volumes) eq "HASH") {
		my $username	= $volumes->{"user"}{"value"};
		$pam_mount->{$username} = $volumes if defined $username;
	    }
	    elsif (ref ($volumes) eq "ARRAY") {
		foreach my $usermap (@{$volumes}) {
		    my $username	= $usermap->{"user"}{"value"};
		    next if !defined $username;
		    $pam_mount->{$username}	= $usermap;
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
# Return the path to user's crypted directory image; returns empty string if there is none defined
# @param user name
# @return string
BEGIN { $TYPEINFO{CryptedImagePath} = ["function", "string", "string"];}
sub CryptedImagePath {

    my $self    = shift;
    my $user	= shift;

    if ($self->ReadCryptedHomesInfo ()) {
	return $pam_mount->{$user}{"path"}{"value"} || "";
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
	return $pam_mount->{$user}{"fskeypath"}{"value"} || "";
    }
    return "";
}
1
# EOF
