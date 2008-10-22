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
use Data::Dumper;

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

# root password already written
my $root_password_written	= 0;

# users from 1st stage already written
my $users_written		= 0;

# only for first stage, remember if root pw dialog should be skipped
my $skip_root_dialog		= 0;

# data of user configured during installation
#my %user			= ();

# data of users configured during installation
my @users			= ();


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
    "local"		=> 72,
    "system"		=> 72,
    "ldap"		=> 72
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

# see SYSTEM_UID_MAX and SYSTEM_GID_MAX in /etc/login.defs
my $max_system_uid	= 499;

# maps for user data read in 1st stage ('from previous installation')
my %imported_users		= ();
my %imported_shadow		= ();

# if importing users during installation is possible
my $import_available;

# if check for LDAP/Kerberos via DNS was done
my $network_methods_checked	= 0;

# prevent re-reading data map with 1st stage settingss
my $first_stage_data_not_read	= 1;

##------------------------------------
##------------------- global imports

YaST::YCP::Import ("Directory");
YaST::YCP::Import ("FileUtils");
YaST::YCP::Import ("Hostname");
YaST::YCP::Import ("InstExtensionImage");
YaST::YCP::Import ("Mode");
YaST::YCP::Import ("ProductControl");
YaST::YCP::Import ("SCR");
YaST::YCP::Import ("Stage");
YaST::YCP::Import ("SystemFilesCopy");
YaST::YCP::Import ("UsersUI");

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

    my %ret	= ();
    %ret	= %{$users[0]} if (defined $users[0]);
    return \%ret;
}

##------------------------------------
# Returns the list users configured during installation
# @return the list of user maps
BEGIN { $TYPEINFO{GetUsers} = [ "function", ["list", "any" ]]; }
sub GetUsers {

    return \@users;
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
	my %user	= %{$data};
	@users	= ();
	push @users, %user;
    }
    return "";
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

# were users from 1st stage already written?
BEGIN { $TYPEINFO{UsersWritten} = ["function", "boolean"];}
sub UsersWritten {
    return bool ($users_written);
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

##------------------------------------
# Check the password of given user or group: part 2, checking for
# problems that may be skipped (accepted) by user
# @param data map containing user/group name, password and type
# @param answer map containing all the problems that were already skipped by
# user
# @return value is map with the problem found FIXME example
BEGIN { $TYPEINFO{CheckPasswordUI} = ["function",
    ["map", "string", "string"],
    ["map", "string", "any"], ["map", "string", "any"]];
}
sub CheckPasswordUI {

    my ($self, $data, $ui_map)	= @_;
    my $pw		= $data->{"userPassword"} || "";
    my $name		= $data->{"uid"};
    $name		= ($data->{"cn"} || "") if (!defined $name);
    my $type		= $data->{"type"} || "local";
    my $min_length 	= $self->GetMinPasswordLength ($type);

    my %ret		= ();

    if ($pw eq "") {
	return \%ret;
    }

    if ($self->CrackLibUsed () && (($ui_map->{"crack"} || "") ne $pw)) {
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
    
    if ($self->ObscureChecksUsed () && (($ui_map->{"obscure"} || "") ne $pw)) {
	my $what	= "users";
	$what		= "groups" if (! defined $data->{"uid"});
	my $error	= $self->CheckObscurity ($name, $pw, $what);
	if ($error ne "") {
	    $ret{"question_id"}	= "obscure";
	    $ret{"question"}	= $error;
	    return \%ret;
	}
    }

    if (($ui_map->{"short"} || "") ne $pw) {
	if (length ($pw) < $min_length) {
	    $ret{"question_id"}	= "short";
	    # popup questionm, %i is number
	    $ret{"question"}	= sprintf (__("The password should have at least %i characters.
Really use this shorter password?"), $min_length);
	}
    }
    
    if (($ui_map->{"truncate"} || "") ne $pw) {
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

    if (defined $system_users{$username}) {
	# error popup
	return __("There is a conflict between the entered
username and an existing username.
Try another one.");
    }
}

# return the %system_users map = these are NOT the current system users,
# but the names that could be used for system users by packages
BEGIN { $TYPEINFO{GetSystemUserNames} = ["function", ["map", "string", "integer"]];}
sub GetSystemUserNames {
    return \%system_users;
}

##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
## Read/Write functions

# Writes the settings configured in 1st stage
BEGIN { $TYPEINFO{Write} = ["function", "boolean"];}
sub Write {

    my $self		= shift;
    my $user_defined	= 0;
    foreach my $user (@users) {
	if (defined $user->{"userPassword"}) {
	    if (!defined $user->{"__imported"}) {
		$user->{"userPassword"}	=
		    $self->CryptPassword($user->{"userPassword"});
	    }
	    $user->{"encrypted"}	= YaST::YCP::Integer (1);
	}
	$user_defined	= 1;
    }
    my %data = (
        "after_auth"		=> $after_auth,
	"run_krb_config"	=> YaST::YCP::Integer ($run_krb_config),
        "users"			=> \@users,
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
    # enable inst_user to either run auth client or write first user
    if ($after_auth ne "users" || $user_defined) {
	y2milestone ("enabling step 'user' for second stage");
	if ($user_defined) {
	    ProductControl->EnableModule ("user_non_interactive");
	}
	else {
	    ProductControl->EnableModule ("user");
	}
    }
    # no user entered + 2nd stage visible => enable clients (bnc#393722)
    elsif (!ProductControl->GetUseAutomaticConfiguration ()) {
	y2milestone ("enabling steps 'auth' and 'user' for second stage");
	ProductControl->EnableModule ("auth");
	ProductControl->EnableModule ("user");
    }

    return $ret;
}

# Read the settings configured in 1st stage
BEGIN { $TYPEINFO{Read} = ["function", "boolean", "boolean"];}
sub Read {

    my $self	= shift;
    my $force	= shift;
    my $file	= Directory->vardir()."/users_first_stage.ycp";
    my $ret	= 0;

    if (FileUtils->Exists ($file) && ($force || $first_stage_data_not_read)) {
	my $data	= SCR->Read (".target.ycp", $file);
	$first_stage_data_not_read	= 0;
	if (defined $data && ref ($data) eq "HASH") {

	    $autologin_user	= $data->{"autologin_user"}	|| "";
	    $root_alias		= $data->{"root_alias"}		|| "";
	    $after_auth		= $data->{"after_auth"}		|| $after_auth;
	    $encryption_method	=
		$data->{"encryption_method"} || $encryption_method; 
	    $run_krb_config	= bool ($data->{"run_krb_config"});
	    if (ref ($data->{"users"}) eq "ARRAY") {
		@users		= @{$data->{"users"}};
	    }
	    $root_password_written = bool ($data->{"root_password_written"});
	    $users_written	= bool ($data->{"users_written"});
	    $ret	= 1;
	}
#	SCR->Execute (".target.remove", $file);
    }
    return bool ($ret);
}

# Remove the private data from users_first_stage.ycp after they were
# written (bnc#395796)
BEGIN { $TYPEINFO{RemoveUserData} = ["function", "boolean"];}
sub RemoveUserData {

    my $self	= shift;
    my $file	= Directory->vardir()."/users_first_stage.ycp";
    my $ret	= 1;

    if (FileUtils->Exists ($file)) {
	my $data	= SCR->Read (".target.ycp", $file);
	if (defined $data && ref ($data) eq "HASH") {
	    if (defined $data->{"users"}) {
		delete $data->{"users"};
	    }
	    $data->{"users_written"}	= YaST::YCP::Integer (1);
	    $ret	= SCR->Write (".target.ycp", $file, $data);
	}
    }
    return bool ($ret);
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
	next if (!defined $imported_shadow{$type});
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
# Check if importing user data from the system is available:
# if yes, go and read the data
BEGIN { $TYPEINFO{ImportAvailable} = ["function", "boolean"]; }
sub ImportAvailable {

    return $import_available if defined $import_available;

    my $self		= shift;
    my $tmp_dir		= Directory->tmpdir()."/users";
    my $vardir		= Directory->vardir();
    my $import_dir	= $tmp_dir.$vardir."/imported/userdata/etc";

    $import_available	= (
	SCR->Execute (".target.mkdir", $tmp_dir) &&
	SystemFilesCopy->CopyFilesToSystem ($tmp_dir) &&
	FileUtils->Exists ($import_dir."/passwd") &&
	FileUtils->Exists ($import_dir."/shadow") &&
	$self->ReadUserData ($import_dir)
    );
    y2milestone ("import available: $import_available");

    # remove the directory with copied data after reading it
    SCR->Execute (".target.bash", "/bin/rm -rf $tmp_dir");

    return $import_available;
}

##------------------------------------
# check if LDAP/Kerberos are available (fate#301340)
BEGIN { $TYPEINFO{CheckNetworkMethodsAvailability} = ["function", "boolean"]; }
sub CheckNetworkMethodsAvailability {
     
    my $self	= shift;

    return $network_methods_checked if $network_methods_checked;

    my $call_extend	= Stage->initial () && !Mode->live_installation ();

    if ($call_extend && !InstExtensionImage->LoadExtension ("bind.rpm",
	# busy popup message, %1 is package name
	sformat (__("Retrieving %1 extension..."), "bind.rpm")))
    {
	y2error ("loading bind.rpm failed, check for network methods skipped");
	return 0;
    }

    my $domain	= Hostname->CurrentDomain ();
    y2milestone ("current domain : '$domain'");

    if (!$domain && Stage->cont ())
    {
	my $out = SCR->Execute (".target.bash_output", "domainname");
	if ($out->{"exit"} eq 0) {
	    $domain	= $out->{"stdout"};
	    chomp $domain;
	    y2milestone ("current domain from domainname: '$domain'");
	}
    }

    # First, check if LDAP server is available
    my $out = SCR->Execute (".target.bash_output", "dig '_ldap._tcp.$domain' SRV +short");
    y2debug ("dig output: ", Dumper ($out));
    my $ldap_server	= "";
    if ($out->{"exit"} eq 0) {
	foreach my $line (split (/\n/,$out->{"stdout"} || "")) {
	    y2debug ("line: $line");
	    if ($line !~ m/^;/) {
		$ldap_server	= (split (/[ \t]/, $line))[3] || ".";
		chop $ldap_server;
		y2debug ("proposed LDAP server '$ldap_server'");
	    }
	    last if $ldap_server ne "";
	}
    }
    if ($ldap_server ne "")
    {
	y2milestone ("LDAP server found, proposing LDAP authentication");
	$self->SetAfterAuth ("ldap");
    }

    # check if AD server is available
    $out = SCR->Execute (".target.bash_output", "dig '_ldap._tcp.dc._msdcs.$domain' SRV +short");
    y2debug ("dig output: ", Dumper ($out));
    my $ad_server	= "";
    if ($out->{"exit"} eq 0) {
	foreach my $line (split (/\n/,$out->{"stdout"} || "")) {
	    y2debug ("line: $line");
	    if ($line !~ m/^;/) {
		$ad_server	= (split (/[ \t]/, $line))[3] || ".";
		chop $ad_server;
		y2debug ("proposed AD server '$ad_server'");
	    }
	    last if $ad_server ne "";
	}
    }
    if ($ad_server ne "")
    {
	y2milestone ("AD server found, proposing winbind authentication");
	$self->SetAfterAuth ("samba");
	$network_methods_checked	= 1;
	# no check for kerberos when AD is detected
	return 1;
    }
    # check for eDirectory now
    elsif ($ldap_server) {
	$out	= SCR->Execute (".target.bash_output", "ldapsearch -x -h $ldap_server -s base -b '' vendorName | grep -i '^vendorName: Novell'");
	y2debug ("ldapsearch output: ", Dumper ($out));
	if ($out->{"exit"} eq 0) {
	    y2milestone ("eDirectory found, proposing for authentication");
	    $self->SetAfterAuth ("edir_ldap");
	}
    }
	 
    # Now, check if kerberos is available
    $out = SCR->Execute (".target.bash_output", "dig '_kerberos._udp.$domain' SRV +short");
    y2debug ("dig output: ", Dumper ($out));
    my $kdc	= "";
    if ($out->{"exit"} eq 0) {
	foreach my $line (split (/\n/,$out->{"stdout"} || "")) {
	    y2debug ("line: $line");
	    if ($line !~ m/^;/) {
		$kdc	= (split (/[ \t]/, $line))[3] || ".";
		chop $kdc;
	    }
	    last if $kdc ne "";
	}
    }
    if ($kdc ne "" && $ldap_server ne "")
    {
	y2milestone ("KDC found, proposing Kerberos authentication");
	$self->SetKerberosConfiguration (1);
    }
    $network_methods_checked	= 1;

    if ($call_extend)
    {
	InstExtensionImage->UnLoadExtension ("bind.rpm",
	    # busy popup message, %1 is package name
	    sformat (__("Releasing %1 extension..."), "bind.rpm"));
    }

    return 1;
}

##------------------------------------
# load cracklib image into the inst-sys
BEGIN { $TYPEINFO{LoadCracklib} = ["function", "boolean"]; }
sub LoadCracklib {

    return InstExtensionImage->LoadExtension ("cracklib-dict-full.rpm",
	# busy popup message
	sformat (__("Retrieving %1 extension..."), "cracklib-dict-full.rpm"));
}

##------------------------------------
# release cracklib image from the inst-sys
BEGIN { $TYPEINFO{UnLoadCracklib} = ["function", "boolean"]; }
sub UnLoadCracklib {
	
    return InstExtensionImage->UnLoadExtension ("cracklib-dict-full.rpm",
	# busy popup message
	sformat (__("Releasing %1 extension..."), "cracklib-dict-full.rpm"));
}

42
# EOF
