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
# File:		modules/UsersSimple.pm
# Package:	Configuration of users and groups
# Summary:	module for first stage user configuration
#
# $Id$
#

package UsersSimple;

use strict;
use Data::Dumper;

use YaST::YCP qw(:LOGGING sformat);
use YaPI;

textdomain("users");

our %TYPEINFO;


my $root_password		= "";

# only for first stage, remember if root pw dialog should be skipped
my $skip_root_dialog		= 0;

# data of users configured during installation
my @users			= ();


# password encryption method
my $encryption_method		= "sha512";

# mail alias for root
my $root_alias			= "";

my %min_pass_length	= (
    "local"		=> 5,
    "system"		=> 5,
    "ldap"		=> 5
);

my %max_pass_length	= (
    "local"		=> 72,
    "system"		=> 72,
    "ldap"		=> 72
);


# Number of sigificant characters in the password for given encryption method
my %max_lengths			= (
    "des"	=> 8,
    "md5"	=> 127,
    "blowfish"	=> 72,
    "sha256"	=> 127, # arbitrary high number, there's probably no limit
    "sha512"	=> 127
);

# name of user that should be logged in automatically
my $autologin_user		= "";

# path to cracklib dictionary
my $cracklib_dictpath		= "";

# if cracklib is used for password checking
my $use_cracklib 		= 1;

# User/group names must match the following regex expression. (/etc/login.defs)
my $character_class 		= "[[:alpha:]_][[:alnum:]_.-]*[[:alnum:]_.\$-]\\?";

my $max_length_login 	= 32; # reason: see for example man utmp, UT_NAMESIZE
my $min_length_login 	= 2;

# see SYS_UID_MAX and SYS_GID_MAX in /etc/login.defs
my $max_system_uid	= 499;

# maps for user data read in 1st stage ('from previous installation')
my %imported_users		= ();
my %imported_shadow		= ();

# if importing users during installation is possible
my $import_available;

##------------------------------------
##------------------- global imports

YaST::YCP::Import ("Directory");
YaST::YCP::Import ("FileUtils");
YaST::YCP::Import ("InstExtensionImage");
YaST::YCP::Import ("Language");
YaST::YCP::Import ("Mode");
YaST::YCP::Import ("SCR");
YaST::YCP::Import ("Stage");
YaST::YCP::Import ("SystemFilesCopy");
YaST::YCP::Import ("UsersUI");
YaST::YCP::Import ("SSHAuthorizedKeys");

# known system users (hard-written here to check user name conflicts)
# number may mean the UID (but it don't have to be defined)
my %system_users	= (
	"root"		=> 0,
	"bin"		=> 1,
	"uucp"		=> 10,
	"daemon"	=> 2,
	"lp"		=> 4,
	"mail"		=> 8,
	"news" 		=> 9,
	"uucp" 		=> 10,
	"games" 	=> 12,
	"man" 		=> 13,
	"at" 		=> 25,
	"wwwrun"	=> 30,
	"ftp" 		=> 40,
	"named" 	=> 0,
	"gdm" 		=> 0,
	"postfix" 	=> 51,
	"sshd" 		=> 71,
	"ntp" 		=> 74,
	"ldap" 		=> 76,
	"nobody" 	=> 65534,
	"amanda" 	=> 0,
	"vscan" 	=> 0,
	"bigsister" 	=> 0,
	"wnn" 		=> 0,
	"cyrus" 	=> 0,
	"dpbox" 	=> 0,
	"gnats" 	=> 0,
	"gnump3d" 	=> 0,
	"hacluster" 	=> 0,
	"irc" 		=> 0,
	"mailman" 	=> 0,
	"mdom" 		=> 0,
	"mysql" 	=> 0,
	"oracle" 	=> 0,
	"postgres" 	=> 0,
	"pop" 		=> 0,
	"sapdb" 	=> 0,
	"snort" 	=> 0,
	"squid" 	=> 31,
	"stunnel" 	=> 0,
	"zope" 		=> 0,
	"radiusd" 	=> 0,
	"otrs" 		=> 0,
	"privoxy" 	=> 0,
	"vdr" 		=> 0,
	"icecream" 	=> 0,
	"bitlbee" 	=> 0,
	"dhcpd" 	=> 0,
	"distcc" 	=> 0,
	"dovecot" 	=> 0,
	"fax" 		=> 0,
	"partimag" 	=> 0,
	"avahi"		=> 0,
	"beagleindex"	=> 0,
	"casaauth"	=> 0,
	"dvbdaemon"	=> 0,
	"festival"	=> 0,
	"haldaemon"	=> 0,
	"icecast"	=> 0,
	"lighttpd"	=> 0,
	"nagios"	=> 0,
	"pdns"		=> 0,
	"polkituser"	=> 0,
	"pound"		=> 0,
	"pulse"		=> 0,
	"quagga"	=> 0,
	"sabayon-admin"	=> 0,
	"tomcat"	=> 0,
	"pegasus"	=> 0,
	"cimsrvr"	=> 0,
	"ulogd"		=> 0,
	"uuidd"		=> 0,
	"suse-ncc"	=> 0,
	"messagebus"    => 0,
	"nx"      	=> 0
);

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

##------------------------------------
# set new value for $character_class
BEGIN { $TYPEINFO{SetCharacterClass} = ["function", "void", "string"];}
sub SetCharacterClass {
    my $self            = shift;
    $character_class    = shift;
}

##------------------------------------
# set new cracklib dictionary path
BEGIN { $TYPEINFO{SetCrackLibDictPath} = ["function", "void", "string"];}
sub SetCrackLibDictPath {
    my $self	= shift;
    $cracklib_dictpath	= shift;
}

##------------------------------------
# return the value of current encryption method
BEGIN { $TYPEINFO{EncryptionMethod} = ["function", "string"];}
sub EncryptionMethod {
    return $encryption_method;
}

# is cracklib used for password checking?
BEGIN { $TYPEINFO{CrackLibUsed} = ["function", "boolean"]; }
sub CrackLibUsed {
    return $use_cracklib;
}

# set the new value of cracklib usage for password checking
BEGIN { $TYPEINFO{UseCrackLib} = ["function", "void", "boolean"]; }
sub UseCrackLib {
    my $self	= shift;
    my $crack	= shift;
    $use_cracklib = bool ($crack) if (defined $crack);
}

##------------------------------------
# set new encryption method
BEGIN { $TYPEINFO{SetEncryptionMethod} = ["function", "void", "string"];}
sub SetEncryptionMethod {

    my $self	= shift;
    my $method	= shift;
    if ($encryption_method ne $method) {
	$encryption_method 		= $method;
	if (defined $max_lengths{$encryption_method}) {
	    $max_pass_length{"local"}	= $max_lengths{$encryption_method};
	    $max_pass_length{"system"}	= $max_lengths{$encryption_method};
	}
    }
}

BEGIN { $TYPEINFO{GetAutologinUser} = ["function", "string"]; }
sub GetAutologinUser {
    return $autologin_user;
}

BEGIN { $TYPEINFO{AutologinUsed} = ["function", "boolean"]; }
sub AutologinUsed {
    return bool ($autologin_user ne "");
}

BEGIN { $TYPEINFO{SetAutologinUser} = ["function", "void", "string"]; }
sub SetAutologinUser {
    my $self		= shift;
    $autologin_user	= shift;
}

BEGIN { $TYPEINFO{GetRootAlias} = ["function", "string"]; }
sub GetRootAlias {
    return $root_alias;
}

BEGIN { $TYPEINFO{SetRootAlias} = ["function", "void", "string"]; }
sub SetRootAlias {
    my $self		= shift;
    $root_alias		= shift;
}

##------------------------------------
# Returns the list users configured during installation
# @return the list of user maps
BEGIN { $TYPEINFO{GetUsers} = [ "function", ["list", "any" ]]; }
sub GetUsers {
    return \@users;
}

##------------------------------------
# Saves the user data into the list
# @param list with user data maps (could be empty)
BEGIN { $TYPEINFO{SetUsers} = ["function",
    "string",
    ["list", "any" ]];		# data to fill in
}
sub SetUsers {

    my $self	= shift;
    my $data	= shift;
    if (defined $data && (ref ($data) eq "ARRAY")) {
	@users	= @{$data};
    }
    return "";
}

##------------------------------------
# save the root password into variable
BEGIN { $TYPEINFO{SetRootPassword} = ["function", "void", "string"];}
sub SetRootPassword {

    my $self		= shift;
    $root_password 	= $_[0];
}

##------------------------------------
BEGIN { $TYPEINFO{GetRootPassword} = ["function", "string"];}
sub GetRootPassword {
    return $root_password;
}

# remember if the checkbox 'Use this password for root' was checked
BEGIN { $TYPEINFO{SkipRootPasswordDialog} = ["function", "void", "boolean"];}
sub SkipRootPasswordDialog {
    my $self	= shift;
    my $skip	= shift;
    $skip_root_dialog = bool ($skip) if (defined $skip);
}

# was the checkbox 'Use this password for root' was checked
BEGIN { $TYPEINFO{RootPasswordDialogSkipped} = ["function", "boolean"];}
sub RootPasswordDialogSkipped {
    return bool ($skip_root_dialog);
}


##------------------------------------
# crypt given password
BEGIN { $TYPEINFO{CryptPassword} = ["function",
    "string", "string"];
}
sub CryptPassword {

    my $self	= shift;
    my $pw	= shift;
    
    return $pw if (!defined $pw);
    return UsersUI->HashPassword (lc ($encryption_method), $pw);
}

##------------------------------------
# Writes password of superuser
# This is called during install
# @return true on success
BEGIN { $TYPEINFO{WriteRootPassword} = ["function", "boolean"];}
sub WriteRootPassword {

    my $self		= shift;
    my $crypted		= $self->CryptPassword ($root_password, "system");
    return SCR->Write (".target.passwd.root", $crypted);
}

# "-" means range! -> at the begining or at the end!
# now CHARACTER_CLASS from /etc/login.defs is used
my $valid_logname_chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ._-";

my $valid_password_chars = "[-0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!@#\$%^&*() ,;:._+/|?{}=\['\"`~<>]|]";# the ']' is or-ed...

# error popup	
my $valid_password_message = __("The password may only contain the following characters:
0-9, a-z, A-Z, and any of \"`~!\@#\$%^&* ,.;:._-+/|\?='{[(<>)]}\\\".
Try again.");

my $valid_home_chars = "[0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ@/_.-]";

##------------------------------------
BEGIN { $TYPEINFO{ValidLognameChars} = ["function", "string"]; }
sub ValidLognameChars {
    return $valid_logname_chars;
}

##------------------------------------
BEGIN { $TYPEINFO{ValidPasswordChars} = ["function", "string"]; }
sub ValidPasswordChars {
    return $valid_password_chars;
}

##------------------------------------
BEGIN { $TYPEINFO{ValidHomeChars} = ["function", "string"]; }
sub ValidHomeChars {
    return $valid_home_chars;
}

##------------------------------------
BEGIN { $TYPEINFO{ValidPasswordMessage} = ["function", "string"]; }
sub ValidPasswordMessage {
    return $valid_password_message;
}

##------------------------------------
# Return the part of help text about valid password characters
BEGIN { $TYPEINFO{ValidPasswordHelptext} = ["function", "string"]; }
sub ValidPasswordHelptext {
    # help text (default part shown in more places)
    return __("<p>
For the password, use only characters that can be found on an English keyboard
layout.  In cases of system error, it may be necessary to log in without a
localized keyboard layout.
</p>");
}

##------------------------------------
BEGIN { $TYPEINFO{GetMinPasswordLength} = ["function", "integer", "string"]; }
sub GetMinPasswordLength {

    my $self		= shift;
    my $type		= shift;
    if (defined $type && defined ($min_pass_length{$type})) {
	return $min_pass_length{$type};
    }
    else { return 5;}
}

##------------------------------------
# Set the minimum password length for given user type
# @param type
# @param length
BEGIN { $TYPEINFO{SetMinPasswordLength} = ["function",
    "void", "string", "integer"];
}
sub SetMinPasswordLength {
    my ($self, $type, $len)	= @_;
    $min_pass_length{$type}	= $len;
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
# Set the maximum password length for given user type
# @param type
# @param length
BEGIN { $TYPEINFO{SetMaxPasswordLength} = ["function",
    "void", "string", "integer"];
}
sub SetMaxPasswordLength {
    my ($self, $type, $len)	= @_;
    $max_pass_length{$type}	= $len;
}

##------------------------------------
BEGIN { $TYPEINFO{GetMinLoginLength} = ["function", "integer" ]; }
sub GetMinLoginLength {
    my $self	= shift;
    return $min_length_login;
}

##------------------------------------
BEGIN { $TYPEINFO{GetMaxLoginLength} = ["function", "integer" ]; }
sub GetMaxLoginLength {
    my $self	= shift;
    return $max_length_login;
}


##---------------------------------------------------------------------------
## check functions

##------------------------------------
# check fullname contents
BEGIN { $TYPEINFO{CheckFullname} = ["function", "string", "string"]; }
sub CheckFullname {

    my ($self, $fullname)        = @_;

    if (defined $fullname && $fullname =~ m/[:,]/) {
	# error popup
        return __("The user's full name cannot contain
\":\" or \",\" characters.
Try again.");
    }
    return "";
}

##------------------------------------
# Just some simple checks for password contens
# @param usernames list of  user or group names
# @param pw password
# @param user/group
# @return error message (password too simple) or empty string (OK)
BEGIN { $TYPEINFO{CheckObscurity} = ["function", "string",
    ["list", "string"],
    "string", "string"];}
sub CheckObscurity {

    my $self		= shift;
    my $names		= shift;
    my $pw 		= shift;
    my $what		= shift;

    foreach my $name (@$names) {
      if ($pw =~ m/$name/) {
	if ($what eq "groups") {
	    # popup question
	    return __("You have used the group name as a part of the password.");
	}
	# popup question
        return __("You have used the username as a part of the password.");
      }
    }

    # check for lowercase
    my $filtered 	= $pw;
    $filtered 		=~ s/[[:lower:]]//g;
    if ($filtered eq "") {
	# popup question
        return __("You have used only lowercase letters for the password.");
    }

    # check for uppercase
    $filtered 		= $pw;
    $filtered 		=~ s/[[:upper:]]//g;
    if ($filtered eq "") {
	# popup question
        return __("You have used only uppercase letters for the password.");
    }
    
    # check for palindroms
    $filtered 		= reverse $pw;
    if ($filtered eq $pw) {
	# popup question
        return __("You have used a palindrome for the password.");
    }

    # check for numbers
    $filtered 		= $pw;
    $filtered 		=~ s/[0-9]//g;
    if ($filtered eq "") {
	# popup question
        return __("You have used only digits for the password.");
    }
    return "";
}

##------------------------------------
# Checks if password is not too long
# @param pw password
# @param user/group type
BEGIN { $TYPEINFO{CheckPasswordMaxLength} = ["function",
    "string", "string", "string"];
}
sub CheckPasswordMaxLength {

    my $self		= shift;
    my $pw 		= shift;
    my $type		= shift;
    my $max_length 	= $self->GetMaxPasswordLength ($type);
    my $ret		= "";

    if (length ($pw) > $max_length) {
	# popup question
        $ret = sprintf (__("The password is too long for the current encryption method.
It will be truncated to %s characters."), $max_length);
    }
    return $ret;
}

##------------------------------------
# Try to crack password using cracklib
# @param pw password
# @return utility output: either "" or error message
BEGIN { $TYPEINFO{CrackPassword} = ["function", "string", "string"];}
sub CrackPassword {

    my $self	= shift;
    my $pw 	= shift;
    my $ret 	= "";

    if (!defined $pw || $pw eq "") {
	return $ret;
    }
    if (!defined $cracklib_dictpath || $cracklib_dictpath eq "" ||
	!FileUtils->Exists ("$cracklib_dictpath.pwd")) {
	$ret = SCR->Execute (".crack", $pw);
    }
    else {
	$ret = SCR->Execute (".crack", $pw, $cracklib_dictpath);
    }
    if (!defined ($ret)) { $ret = ""; }
    return $ret if ($ret eq "");
    return UsersUI->RecodeUTF ($ret);
}

##------------------------------------
# check the password of given user
# @param password
# @param user type
# return value is error message
BEGIN { $TYPEINFO{CheckPassword} = ["function", "string", "string", "string"]; }
sub CheckPassword {

    my ($self, $pw, $type)	= @_;
    my $min_length 	= $self->GetMinPasswordLength ($type);

    if ((!defined $pw) || ($pw eq "" && $min_length > 0)) {
	# error popup
	return __("No password entered.
Try again.");
    }

    my $filtered = $pw;
    $filtered =~ s/$valid_password_chars//g;
    $filtered =~ s/\\//g; # bug 175706

    if ($filtered ne "") {
	return $self->ValidPasswordMessage ();
    }
    return "";
}

# Check the password of given user or group: part 2, checking for
# problems that may be skipped (accepted) by user
# @param data map containing user/group name, password and type
#
# Merges all error reports and returns them in the list
BEGIN { $TYPEINFO{CheckPasswordUI} = ["function",
    ["list", "string"],
    ["map", "string", "any"]];
}
sub CheckPasswordUI {

    my ($self, $data)	= @_;
    my $pw		= $data->{"userPassword"} || "";
    my $name		= $data->{"uid"};
    $name		= ($data->{"cn"} || "") if (!defined $name);
    my $type		= $data->{"type"} || "local";
    my $min_length 	= $self->GetMinPasswordLength ($type);

    my @ret		= ();

    if ($pw eq "") {
	return \@ret;
    }

    if ($self->CrackLibUsed ()) {
	my $error = $self->CrackPassword ($pw);
	if ($error ne "") {
	    # error message
	    push @ret, sprintf (__("The password is too simple:
%s."), $error);
	}
    }
    
    my $what	= "users";
    $what       = "groups" if (! defined $data->{"uid"});
    my @names   = ( $name );
    push @names, "root" if $data->{"root"} || 0;
    my $error	= $self->CheckObscurity (\@names, $pw, $what);
    push @ret, $error if $error;

    if (length ($pw) < $min_length) {
	# popup error, %i is number
	push @ret, sprintf (__("The password should have at least %i characters."), $min_length);
    }
    
    $error = $self->CheckPasswordMaxLength ($pw, $type);
    push @ret, $error if $error;

    return \@ret;
}

##------------------------------------
# Check the length of given user name
# @param user name
# @return error message
BEGIN { $TYPEINFO{CheckUsernameLength} = ["function", "string", "string"]; }
sub CheckUsernameLength {

    my $self		= shift;
    my $username	= shift;

    if (!defined $username || $username eq "") {
	# error popup
        return __("No username entered.
Try again.");
    }

    my $min		= $self->GetMinLoginLength ();
    my $max		= $self->GetMaxLoginLength ();

    if (length ($username) < $min || length ($username) > $max) {

	# error popup
	return sprintf (__("The username must be between %i and %i characters in length.
Try again."), $min, $max);
    }
    return "";
}

##------------------------------------
# check given user name for valid contents
# @param user name
# @param user type (local/ldap etc.)
# @return error message
BEGIN { $TYPEINFO{CheckUsernameContents} = ["function",
    "string", "string", "string"];
}
sub CheckUsernameContents {

    my ($self, $username, $type)	= @_;
    my $filtered	= $username;

    # Samba users may need to have '$' at the end of username (#40433)
    if ($type eq "ldap") {
	$filtered =~ s/\$$//g;
    }
    my $grep = SCR->Execute (".target.bash_output", "echo '$filtered' | grep '\^$character_class\$'", { "LANG" => "C" });
    my $stdout = $grep->{"stdout"} || "";
    $stdout =~ s/\n//g;
    if ($stdout ne $filtered) {
	y2warning ("username $username doesn't match to $character_class");
	# error popup
	return __("The username may contain only
letters, digits, \"-\", \".\", and \"_\"
and must begin with a letter or \"_\".
Try again.");
    }
    return "";
}



##------------------------------------
# check given user name for a conflict with a (fixed) set of system users
# @param user name
# @return error message
BEGIN { $TYPEINFO{CheckUsernameConflicts} = ["function", "string", "string" ]; }
sub CheckUsernameConflicts {
    
    my ($self, $username)	= @_;

    if (defined $system_users{$username}) {
	# error popup
	return __("There is a conflict between the entered
username and an existing username.
Try another one.");
    }
}

##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
## Read/Write functions

# Writes the root password configured in the 1st stage
BEGIN { $TYPEINFO{Write} = ["function", "boolean"];}
sub Write {
    my $self		= shift;

    if ($root_password ne "") {
	# write root password now
	return $self->WriteRootPassword ();
    }

    SSHAuthorizedKeys->write_keys("/root");

    return bool (1);
}

# Empty function (kept for backward compatibility)
BEGIN { $TYPEINFO{Read} = ["function", "boolean", "boolean"];}
sub Read {

    my $self	= shift;
    my $force	= shift;

    return bool (1);
}

##---------------------------------------------------------------------------
## functions for handling passwd/shadow files in the 1st stage
## (simplified version of functions from UsersPasswd and Users)


# read 'shadow' file from a given directory
# return hash with shadow description
sub read_shadow {

    my $base_directory	= shift;
    my $file		= "$base_directory/shadow";
    my %shadow_tmp	= ();
    my $in		= SCR->Read (".target.string", $file);

    if (! defined $in) {
	y2warning ("$file cannot be opened for reading!");
	return undef;
    }

    foreach my $shadow_entry (split (/\n/,$in)) {
	chomp $shadow_entry;
	next if ($shadow_entry eq "");

	my ($uname,$pass,$last_change,$min, $max, $warn, $inact, $expire, $flag)
	    = split(/:/,$shadow_entry);  
        my $first = substr ($uname, 0, 1);

	if ($first ne "#" && $first ne "+" && $first ne "-")
	{
	    if (!defined $uname || $uname eq "") {
		y2error ("strange line in shadow file: '$shadow_entry'");
		return undef;
	    }
	    if (defined $shadow_tmp{$uname})
	    {
		y2error ("duplicated username in /etc/shadow! Exiting...");
		return undef;
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
    }
    return \%shadow_tmp;
}

# read content of 'passwd' file under given directory
# - save data into internal structure
# return boolean (success)
sub read_passwd {

    my $base_directory	= shift;
    my $shadow_tmp	= shift;
    my $file		= "$base_directory/passwd";

    %imported_users 		= ();
    %imported_shadow		= ();
    my %usernames		= ();

    my $in	= SCR->Read (".target.string", $file);
    if (! defined $in) {
	y2warning ("$file cannot be opened for reading!");
	return 0;
    }

    foreach my $user (split (/\n/,$in)) {
	chomp $user;
	next if ($user eq "");

	my ($username, $password, $uid, $gid, $full, $home, $shell)
	    = split(/:/,$user);
        my $first = substr ($username, 0, 1);

	if ($first ne "#" && $first ne "+" && $first ne "-") {

	    if (!defined $password || !defined $uid || !defined $gid ||
		!defined $full || !defined $home || !defined $shell ||
		$username eq "" || $uid eq "" || $gid eq "") {
		y2error ("strange line in passwd file: '$user'");
		return 0;
	    }
		
            my $user_type	= "local";

	    if (($uid <= $max_system_uid) || ($username eq "nobody")) {
		$user_type = "system";
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
	    
	    if (defined $usernames{"local"}{$username} ||
		defined $usernames{"system"}{$username})
	    {
		y2error ("duplicated username in /etc/passwd! Exiting...");
		return 0;
	    }
	    else
	    {
		$usernames{$user_type}{$username} = 1;
	    }
    
	    # such map we would like to export from the read script...
	    $imported_users{$user_type}{$username} = {
		"addit_data"	=> $additional,
		"cn"		=> $full,
		"homeDirectory"	=> $home,
		"uid"		=> $username,
		"uidNumber"	=> $uid,
		"gidNumber"	=> $gid,
		"loginShell"	=> $shell,
	    };
	    if (defined $shadow_tmp->{$username}) {
		# divide shadow map accoring to user type
		$imported_shadow{$user_type}{$username} =
		    $shadow_tmp->{$username};
	    }
	}
    }
    return 1;
}

##------------------------------------
# Read passwd and shadow files in 1st stage of the installation
# string parameter is path to directory with passwd, shadow files
BEGIN { $TYPEINFO{ReadUserData} = ["function", "boolean", "string"]; }
sub ReadUserData {

    my ($self, $base_directory)	= @_;
    my $ret			= 0;
    my $shadow_tmp	= read_shadow ($base_directory);
    if (defined $shadow_tmp && ref ($shadow_tmp) eq "HASH") {
	$ret	= read_passwd ($base_directory, $shadow_tmp);
    }
    return $ret;
}

##------------------------------------
# returns hash with imported users of given type
# @param user type
BEGIN { $TYPEINFO{GetImportedUsers} = [
    "function", ["map", "string", "any"], "string"];
}
sub GetImportedUsers {

    my ($self, $type)	= @_;
    my %ret		= ();

    if (defined $imported_users{$type} && ref($imported_users{$type}) eq "HASH")
    {
	%ret 	= %{$imported_users{$type}};
	return \%ret if (!defined $imported_shadow{$type});
	# add the shadow data into each user map
	foreach my $username (keys %ret) {
	    next if (!defined $imported_shadow{$type}{$username});
	    foreach my $key (keys %{$imported_shadow{$type}{$username}}) {
	      $ret{$username}{$key} = $imported_shadow{$type}{$username}{$key};
	    }
	}
    }
    return \%ret;
}

##------------------------------------
# load cracklib image into the inst-sys
BEGIN { $TYPEINFO{LoadCracklib} = ["function", "boolean"]; }
sub LoadCracklib {

    if (!Stage->initial () || Mode->live_installation ()) {
	y2debug ("no extend in this stage/mode");
	return 1;
    }
    return InstExtensionImage->LoadExtension ("cracklib-dict-full.rpm",
	# busy popup message
	sformat (__("Retrieving %1 extension..."), "cracklib-dict-full.rpm"));
}

##------------------------------------
# release cracklib image from the inst-sys
BEGIN { $TYPEINFO{UnLoadCracklib} = ["function", "boolean"]; }
sub UnLoadCracklib {
	
    if (!Stage->initial () || Mode->live_installation ()) {
	y2debug ("no extend in this stage/mode");
	return 1;
    }
    return InstExtensionImage->UnLoadExtension ("cracklib-dict-full.rpm",
	# busy popup message
	sformat (__("Releasing %1 extension..."), "cracklib-dict-full.rpm"));
}

##------------------------------------
# use iconv transliteration feature to convert special characters to similar
# ASCII ones (bnc#442225)
BEGIN { $TYPEINFO{Transliterate} = ["function", "string", "string"]; }
sub Transliterate {

    my ($self, $text)	= @_;

    return "" if ! $text;
    my $language	= Language->language ();
    my $out = SCR->Execute (".target.bash_output",
	"echo '$text' | iconv -f utf-8 -t ascii//translit",
	{ "LANG" => $language });
    my $stdout = $out->{"stdout"} || "";
    chomp($stdout);

    return $stdout;
}

42
# EOF
