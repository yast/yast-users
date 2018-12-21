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

package YaPI::ADMINISTRATOR;

use strict;
use YaST::YCP qw(:LOGGING);
use YaPI;

textdomain ("users");

# ------------------- imported modules
YaST::YCP::Import ("MailAliases");
YaST::YCP::Import ("Mode");
YaST::YCP::Import ("SCR");
YaST::YCP::Import ("Users");
# -------------------------------------

our $VERSION		= '1.0.0';
our @CAPABILITIES 	= ('SLES11');
our %TYPEINFO;

=item *
C<$hash Read ();>

Returns the information about system administrator (root).
Currently return hash contains the list of mail aliases.

=cut

BEGIN{$TYPEINFO{Read} = ["function",
    [ "map", "string", "any" ]];
}
sub Read {

    my $self	= shift;

    # FIXME HACK to prevent setting mode to testsuite (bnc#243624)
    Mode->SetUI ("commandline");

    my $root_mail	= MailAliases->GetRootAlias ();
    return {} if !defined $root_mail;

    my @root_aliases	= ();
    foreach my $alias (split (/,/, $root_mail)) {
	$alias	=~ s/[ \t]//g;
	push @root_aliases, $alias;
    }

    return {
	"aliases"	=> \@root_aliases
    }
}

=item *
C<$string Write ($argument_hash);>

write the system adminstrator data. Supported keys of the argument hash are:

    "aliases"	=> list of mail aliases
    "password"	=> new password

Returns error message on error.

=cut

BEGIN{$TYPEINFO{Write} = ["function",
    "string",
    [ "map", "string", "any" ]];
}
sub Write {

    my $self	= shift;
    my $args	= shift;
    my $ret	= "";

    Mode->SetUI ("commandline");

    if ($args->{"aliases"} && ref ($args->{"aliases"}) eq "ARRAY") {

	my $root_mail	= join (", ", @{$args->{"aliases"}});
	if (!MailAliases->SetRootAlias ($root_mail)) {
	    # error popup
	    $ret = __("An error occurred while setting forwarding for root's mail.");
	    return $ret;
	}
	my $out = SCR->Execute (".target.bash_output", "/usr/bin/newaliases");
	$ret = $out->{"stderr"} || "";
    }
    if ($args->{"password"}) {
	Users->SetRootPassword ($args->{"password"});
	Users->WriteRootPassword ();
    }
    return $ret;
}

