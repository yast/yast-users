#!/usr/bin/perl -w
#
#  File:
#       build_additional_users.pl
#
#  Module:
#       Users and groups configuration
#
#  Authors:
#       Jiri Suchomel <jsuchome@suse.cz>
#
#  Description:
#       Builds the structure for MultiSelectionBox in EditGroup dialog.
#
#  Usage:
#       The only parameter is a directory, where input files are located
#       and output files written.
#

$dir              = $ARGV[0];

$userlist_file    = $dir."/additional_userlist";
$more_users_file  = $dir."/additional_moreusers";
$usernames_file   = $dir."/additional_usernames";

$output_ulist      = $dir."/additional_ulist.ycp";
$output_more       = $dir."/additional_more.ycp";


open USERLIST, "< $userlist_file";

$userlist = <USERLIST>;
@userlist_list = ();
if (defined $userlist)
{
    @userlist_list = split (/,/, $userlist);
}

close USERLIST;

open MORE_USERS, "< $more_users_file";

$more_users = <MORE_USERS>;
@more_list = ();
if (defined $more_users)
{
    @more_list = split (/,/, $more_users);
}
    
close MORE_USERS;

open USERNAMES, "< $usernames_file";

foreach my $line (<USERNAMES>)
{
    chomp $line;
    $usernames .= $line;
}

close USERNAMES;

my @nameslist = ();

while (index ($usernames, "\"") > -1)
{
    $first_idx = index($usernames, ":");
    $last_idx = index($usernames, "]");
    $names = substr ($usernames, $first_idx, $last_idx - $first_idx + 1, "");
    if (index ($names, "\"") > -1)
    {
        $names =~s/[:\[\]\"]//g;
        push (@nameslist, split (/,/, $names));
    }
}

open ULIST, "> $output_ulist";
open MORE, "> $output_more";
print ULIST "[\n";
print MORE "[\n";


%more_map = ();
foreach $user (@more_list)
{
    $more_map{$user} = 1; 
    print MORE "\t`item( `id(\"$user\"), \"$user\", true ),\n";
}

%userlist_map = ();
foreach $user (@userlist_list)
{
    $userlist_map{$user} = 1; 
    print ULIST "\t`item( `id(\"$user\"), \"$user\", true ),\n";
}


foreach $user (@nameslist)
{
    $user =~s/ //g;
    if ( !defined $more_map{$user} && !defined $userlist_map{$user} )
    {
        print ULIST "\t`item( `id(\"$user\"), \"$user\", false ),\n";
    }
}

print ULIST "]";
print MORE "]";
close ULIST;
close MORE;
