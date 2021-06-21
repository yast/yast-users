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

# password encryption method
my $encryption_method		= "sha512";

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

# path to cracklib dictionary
my $cracklib_dictpath		= "";

# if cracklib is used for password checking
my $use_cracklib 		= 1;

# User/group names must match the following regex expression. (/etc/login.defs)
my $character_class 		= "[[:alpha:]_][[:alnum:]_.-]*[[:alnum:]_.\$-]\\?";

my $max_length_login 	= 32; # reason: see for example man utmp, UT_NAMESIZE
my $min_length_login 	= 2;

##------------------------------------
##------------------- global imports

YaST::YCP::Import ("FileUtils");
YaST::YCP::Import ("InstExtensionImage");
YaST::YCP::Import ("Mode");
YaST::YCP::Import ("SCR");
YaST::YCP::Import ("Stage");
YaST::YCP::Import ("String");
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

# "-" means range! -> at the begining or at the end!
# now CHARACTER_CLASS from /etc/login.defs is used
my $valid_logname_chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ._-";

my $valid_password_chars = "[-0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!@#\$%^&*() ,;:._+/|?{}=\['\"`~<>]|]";# the ']' is or-ed...

# TRANSLATORS: Keep symbols in its ASCII variants that can be preset on default us keyboard layout
my $valid_password_message = __("The password may only contain the following characters:
0-9, a-z, A-Z, and any of \"`~!\@#\$%^&* ,.;:._-+/|\?='{[(<>)]}\\\".
Basically these are the available keys on the default keyboard layout to prevent
problems when an emergency login from the console is needed.
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
    # NOTE: To avoid dependencies, this help text has been duplicated at
    #   Y2Users::HelpTexts#valid_password_text. Please, keep them in sync.
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
	# TRANSLATORS: take care to preserve the ASCII characters
        #  : (U+003A COLON)  , (U+002C COMMA),
        #  not replacing them with your native script variants
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
    my $grep = SCR->Execute (".target.bash_output", "/usr/bin/echo '".String->Quote($filtered)."' | /usr/bin/grep '\^".String->Quote($character_class)."\$'", { "LANG" => "C" });
    my $stdout = $grep->{"stdout"} || "";
    $stdout =~ s/\n//g;
    if ($stdout ne $filtered) {
	y2warning ("username $username doesn't match to $character_class");
	# TRANSLATORS: take care to preserve the ASCII characters
        #  - (U+002D HYPHEN-MINUS)  . (U+002E FULL STOP) _ (U+005F UNDERSCORE),
        #  not replacing them with your native script variants
	return __("The username may contain only
Latin letters and digits, \"-\", \".\", and \"_\"
and must begin with a letter or \"_\".
Try again.");
    }
    return "";
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

1
# EOF
