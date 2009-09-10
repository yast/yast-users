package YaPI::ADMINISTRATOR;

use strict;
use YaST::YCP qw(:LOGGING);
use YaPI;

textdomain ("users");

# ------------------- imported modules
YaST::YCP::Import ("MailAliases");
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

    if ($args->{"aliases"} && ref ($args->{"aliases"}) eq "ARRAY") {

	my $root_mail	= join (", ", @{$args->{"aliases"}});
	if (!MailAliases->SetRootAlias ($root_mail)) {
	    # error popup
	    $ret = __("An error occurred while setting forwarding for root's mail.");
	    return $ret;
	}
    }
    if ($args->{"password"}) {
	Users->SetRootPassword ($args->{"password"});
	Users->WriteRootPassword ();
    }
    return $ret;
}

