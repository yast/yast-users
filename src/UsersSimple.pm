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

# only for first stage, remember if root pw dialog should be skipped
my $skip_root_dialog		= 0;

# data of user configured during installation
my %user			= ();


# password encryption method
my $encryption_method		= "blowfish";

# mail alias for root
my $root_alias			= "";

my %min_pass_length	= (
    "local"		=> 5,
    "system"		=> 5,
    "ldap"		=> 5
);

my %max_pass_length	= (
    "local"		=> 8,
    "system"		=> 8,
    "ldap"		=> 8
);


# Number of sigificant characters in the password for given encryption method
my %max_lengths			= (
    "des"	=> 8,
    "md5"	=> 127,
    "blowfish"	=> 72,
);

# name of user that should be logged in automatically
my $autologin_user		= "";

# path to cracklib dictionary
my $cracklib_dictpath		= "";

# if cracklib is used for password checking
my $use_cracklib 		= 1;

my $obscure_checks 		= 1;

# User/group names must match the following regex expression. (/etc/login.defs)
my $character_class 		= "[[:alpha:]_][[:alnum:]_.-]*[[:alnum:]_.\$-]\\?";

my $max_length_login 	= 32; # reason: see for example man utmp, UT_NAMESIZE
my $min_length_login 	= 2;


##------------------------------------
##------------------- global imports

YaST::YCP::Import ("Directory");
YaST::YCP::Import ("ProductControl");
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

# are 'obscure checks' used for password checking?
BEGIN { $TYPEINFO{ObscureChecksUsed} = ["function", "boolean"]; }
sub ObscureChecksUsed {
    return $obscure_checks;
}

# set the new value of 'obscure checks' usage for password checking
BEGIN { $TYPEINFO{UseObscureChecks} = ["function", "void", "boolean"]; }
sub UseObscureChecks {
    my $self	= shift;
    my $checks	= shift;
    $obscure_checks = bool ($checks) if (defined $checks);
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
    my ($self, $krb)	= @_;
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
# @param username user or group name
# @param pw password
# @param user/group
# @return error message (password too simple) or empty string (OK)
BEGIN { $TYPEINFO{CheckObscurity} = ["function", "string",
    "string", "string", "string"];}
sub CheckObscurity {

    my $self		= shift;
    my $name		= shift;
    my $pw 		= shift;
    my $what		= shift;

    if ($pw =~ m/$name/) {
	if ($what eq "groups") {
	    # popup question
	    return __("You have used the group name as a part of the password.
This is not a good security practice. Really use this password?");
	}
	# popup question
        return __("You have used the username as a part of the password.
This is not a good security practice. Really use this password?");
    }

    # check for lowercase
    my $filtered 	= $pw;
    $filtered 		=~ s/[[:lower:]]//g;
    if ($filtered eq "") {
	# popup question
        return __("You have used only lowercase letters for the password.
This is not a good security practice. Really use this password?");
    }

    # check for uppercase
    $filtered 		= $pw;
    $filtered 		=~ s/[[:upper:]]//g;
    if ($filtered eq "") {
	# popup question
        return __("You have used only uppercase letters for the password.
This is not a good security practice. Really use this password?");
    }
    
    # check for palindroms
    $filtered 		= reverse $pw;
    if ($filtered eq $pw) {
	# popup question
        return __("You have used a palindrom for the password.
This is not a good security practice. Really use this password?");
    }

    # check for numbers
    $filtered 		= $pw;
    $filtered 		=~ s/[0-9]//g;
    if ($filtered eq "") {
	# popup question
        return __("You have used only digits for the password.
This is not a good security practice. Really use this password?");
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
Truncate it to %s characters?"), $max_length);
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

##------------------------------------
# Check the password of given user or group: part 2, checking for
# problems that may be skipped (accepted) by user
# @param data map containing user/group name, password and type
# @param answer map containing all the problems that were already skipped by
# user
# @return value is map with the problem found FIXME example
BEGIN { $TYPEINFO{CheckPasswordUI} = ["function",
    ["map", "string", "string"],
    ["map", "string", "any"], ["map", "string", "integer"]];
}
sub CheckPasswordUI {

    my ($self, $data, $ui_map)	= @_;
    my $pw		= $data->{"userpassword"} || "";
    my $name		= $data->{"uid"};
    $name		= ($data->{"cn"} || "") if (!defined $name);
    my $type		= $data->{"type"} || "local";
    my $min_length 	= $self->GetMinPasswordLength ($type);

    my %ret		= ();

    if ($pw eq "") {
	return \%ret;
    }

    if ($self->CrackLibUsed () && (($ui_map->{"crack"} || 0) != 1)) {
	my $error = $self->CrackPassword ($pw);
	if ($error ne "") {
	    $ret{"question_id"}	= "crack";
	    # popup question
	    $ret{"question"}	= sprintf (__("The password is too simple:
%s
Really use this password?"), $error);
	    return \%ret;
	}
    }
    
    if ($self->ObscureChecksUsed () && (($ui_map->{"obscure"} || 0) != 1)) {
	my $what	= "users";
	$what		= "groups" if (! defined $data->{"uid"});
	my $error	= $self->CheckObscurity ($name, $pw, $what);
	if ($error ne "") {
	    $ret{"question_id"}	= "obscure";
	    $ret{"question"}	= $error;
	    return \%ret;
	}
    }

    if (($ui_map->{"short"} || 0) != 1) {
	if (length ($pw) < $min_length) {
	    $ret{"question_id"}	= "short";
	    # popup questionm, %i is number
	    $ret{"question"}	= sprintf (__("The password should have at least %i characters.
Really use this shorter password?"), $min_length);
	}
    }
    
    if (($ui_map->{"truncate"} || 0) != 1) {
	my $error = $self->CheckPasswordMaxLength ($pw, $type);
	if ($error ne "") {
	    $ret{"question_id"}	= "truncate";
	    $ret{"question"}	= $error;
	}
    }
    return \%ret;
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

    my %system_users	= (
	"root"	=> 0,
	"bin"	=> 1,
	"uucp"	=> 10, #FIXME fill this
    );
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
 
    my $redraw	= 0;
    if ($root_password) {
	# write root password now
	$self->WriteRootPassword ();
    }
    else {
	y2milestone ("enabling step 'root' for second stage");
	ProductControl->EnableModule ("root");
    }
    if ($after_auth ne "users" || %user) {
	y2milestone ("enabling step 'user' for second stage");
	ProductControl->EnableModule ("user");
    }

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
#	SCR->Execute (".target.remove", $file); FIXME not removed due to testing
    }
    return bool ($ret);
}
1
# EOF
