#! /usr/bin/perl -w
#
# File:		modules/UsersSimple.pm
# Package:	Configuration of users and groups
# Summary:	module for first stage user configuration
#
# $Id$
#

package UsersSimple;

use strict;

use YaST::YCP qw(:LOGGING sformat);
use YaPI;

textdomain("users");

our %TYPEINFO;

# What client to call after authentication dialog during installation:
# could be "users","nis" or "ldap", for more see inst_auth.ycp
my $after_auth			= "users";

# If kerberos configuration should be called after authentication
# during installation (F120214)
my $run_krb_config		= 0;

my $root_password		= "";

my $root_password_written	= 0;

# data of user configured during installation
my %user			= ();


# password encryption method
my $encryption_method		= "md5";

# mail alias for root
my $root_alias			= "";

my %min_pass_length	= (
    "local"		=> 5,
    "system"		=> 5
);

my %max_pass_length	= (
    "local"		=> 8,
    "system"		=> 8
);

# Number of sigificant characters in the password for given encryption method
my %max_lengths			= (
    "des"	=> 8,
    "md5"	=> 127,
    "blowfish"	=> 72,
);

# name of user that should be logged in automatically
my $autologin_user		= "";

##------------------------------------
##------------------- global imports

YaST::YCP::Import ("Directory");
YaST::YCP::Import ("SCR");
YaST::YCP::Import ("UsersUI");

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
# return the value of current encryption method
BEGIN { $TYPEINFO{EncryptionMethod} = ["function", "string"];}
sub EncryptionMethod {
    return $encryption_method;
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

BEGIN { $TYPEINFO{AfterAuth} = ["function", "string"];}
sub AfterAuth {
    return $after_auth;
}

BEGIN { $TYPEINFO{SetAfterAuth} = ["function", "void", "string"];}
sub SetAfterAuth {
    my $self	= shift;
    $after_auth = $_[0];
}

# return the value of run_krb_config (should the kerberos config be run?)
BEGIN { $TYPEINFO{KerberosConfiguration} = ["function", "boolean"];}
sub KerberosConfiguration {
    return bool ($run_krb_config);
}

# set the new value for run_krb_config
BEGIN { $TYPEINFO{SetKerberosConfiguration} = ["function", "void", "boolean"];}
sub SetKerberosConfiguration {
    my $self	= shift;
    my $krb	= shift;
    $run_krb_config = bool ($krb) if (defined $krb);
}

    

##------------------------------------
# Returns the map of user configured during installation
# @return the map of user
BEGIN { $TYPEINFO{GetUser} = [ "function",
    ["map", "string", "any" ]];
}
sub GetUser {

    return \%user;
}

##------------------------------------
# Saves the user data into the map
# @param data user initial data (could be an empty map)
BEGIN { $TYPEINFO{SetUser} = ["function",
    "string",
    ["map", "string", "any" ]];		# data to fill in
}
sub SetUser {

    my $self	= shift;
    my $data	= shift;
    if (defined $data && (ref ($data) eq "HASH")) {
	%user	= %{$data};
    }
    return "";
}

# was root password written in 1st stage?
BEGIN { $TYPEINFO{RootPasswordWritten} = ["function", "boolean"];}
sub RootPasswordWritten {
    return bool ($root_password_written);
}

##------------------------------------
# save the root password into variable
BEGIN { $TYPEINFO{SetRootPassword} = ["function", "void", "string"];}
sub SetRootPassword {

    my $self		= shift;
    $root_password 	= $_[0];
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

my $valid_home_chars = "[0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ/_.-]";

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

# Writes the settings configured in 1st stage
BEGIN { $TYPEINFO{Write} = ["function", "boolean"];}
sub Write {

    my $self	= shift;
    if (defined $user{"userpassword"}) {
	$user{"userpassword"}	= $self->CryptPassword ($user{"userpassword"});
	$user{"encrypted"}	= YaST::YCP::Integer (1);
    }
    my %data = (
        "after_auth"		=> $after_auth,
	"run_krb_config"	=> YaST::YCP::Integer ($run_krb_config),
        "user"			=> \%user,
	"encryption_method"	=> $encryption_method,
	"root_alias"		=> $root_alias,
	"autologin_user"	=> $autologin_user
    );
    if ($root_password) {
	# indication to inst_root
	$data{"root_password_written"}	= YaST::YCP::Integer (1);
    }
    my $file	= Directory->vardir()."/users_first_stage.ycp";
    my $ret	= SCR->Write (".target.ycp", $file, \%data);

    y2milestone ("1st stage user information written: ", $ret);

    # make the file root only readable
    SCR->Execute (".target.bash", "chmod 600 $file") if ($ret);
 
    # write root password now
    $self->WriteRootPassword () if ($root_password);

    return $ret;
}

# Read the settings configured in 1st stage
BEGIN { $TYPEINFO{Read} = ["function", "boolean"];}
sub Read {

    my $self	= shift;
    my $file	= Directory->vardir()."/users_first_stage.ycp";
    my $ret	= 0;

    if (FileUtils->Exists ($file)) {
	my $data	= SCR->Read (".target.ycp", $file);
	if (defined $data && ref ($data) eq "HASH") {

	    $autologin_user	= $data->{"autologin_user"}	|| "";
	    $root_alias		= $data->{"root_alias"}		|| "";
	    $after_auth		= $data->{"after_auth"}		|| $after_auth;
	    $encryption_method	=
		$data->{"encryption_method"} || $encryption_method; 
	    $run_krb_config	= bool ($data->{"run_krb_config"});
	    if (ref ($data->{"user"}) eq "HASH") {
		%user		= %{$data->{"user"}};
	    }
	    $root_password_written = bool ($data->{"root_password_written"});
	    $ret	= 1;
	}
#	SCR->Execute (".target.remove", $file); TODO
    }
    return bool ($ret);
}
1
# EOF
