#!/usr/bin/perl -w
#
#  File:
#       build_nis_structures.pl
#
#  Module:
#       Users and groups configuration
#
#  Authors:
#       Jiri Suchomel <jsuchome@suse.cz>
#
#  Description:
#       Builds the YCP structures of users/groups to load from module
#       (making it inside YaST is toooo slow)
#
#  Usage:
#   build_nis.structures.pl input_directory output_directory encoding
#
#  Example:
#   build_nis_structures.pl /etc /tmp iso-8859-2
#
#

# for encoding the fullnames
use Encode 'from_to';

# the input parameters:

$input_dir      = $ARGV[0];
$output_dir     = $ARGV[1];
$encod          = $ARGV[2];

$group_input    = $input_dir."/group";
$passwd_input   = $input_dir."/passwd";
$shadow_input   = $input_dir."/shadow";
$gshadow_input  = $input_dir."/gshadow";

$groups_corrected  = $output_dir."/group_correct.ycp";

$nis_output        = $output_dir."/nis.ycp";
$nis_byname_output = $output_dir."/nis_byname.ycp";

$usernamelist_nis  = $output_dir."/usernamelist_nis.ycp";

$homelist_nis      = $output_dir."/homelist_nis.ycp";

$nis_itemlist      = $output_dir."/itemlist_nis.ycp";

$uidlist_nis       = $output_dir."/uidlist_nis.ycp";

$the_answer = 42; # ;-)


@ypcat = `ypcat passwd`;  # add a check for existence !

%corrected_groups = ();

open YCP_NIS, "> $nis_output";
open YCP_NIS_BYNAME, "> $nis_byname_output";
open YCP_NIS_ITEMLIST, "> $nis_itemlist";

open YCP_NIS_UIDLIST, "> $uidlist_nis";
print YCP_NIS_UIDLIST "[\n";

open YCP_NIS_USERNAMES, "> $usernamelist_nis";
print YCP_NIS_USERNAMES "[\n";

open YCP_NIS_HOMES, "> $homelist_nis";
print YCP_NIS_HOMES "[\n";

print YCP_NIS "\$[\n";
print YCP_NIS_BYNAME "\$[\n";
print YCP_NIS_ITEMLIST "[\n";

foreach $user (@ypcat)
{
    my ($username, $password, $uid, $gid, $full, $home, $shell)
        = split(/:/,$user);
    chomp $shell;

    print YCP_NIS_UIDLIST " $uid,";

    my $groupname = "";
    if (defined ($corrected_groups{$gid}))
    {
        $corrected_groups{$gid} .= ",$username";
    }
    else
    {
        $corrected_groups{$gid} = "$username";
    }

    # grouplist is hard to generate
    my $grouplist = "";

    print YCP_NIS_HOMES " \"$home\",";
    print YCP_NIS_USERNAMES " \"$username\",";

    # recode the fullname to utf
    from_to($full, $encod, "utf-8");

    print YCP_NIS "\t$uid : \$[\n";
    print YCP_NIS "\t\t\"username\": \"$username\",\n";
    print YCP_NIS "\t\t\"password\": \"$password\",\n";
    print YCP_NIS "\t\t\"uid\": $uid,\n";
    print YCP_NIS "\t\t\"gid\": $gid,\n";
    print YCP_NIS "\t\t\"fullname\": \"$full\",\n";
    print YCP_NIS "\t\t\"home\": \"$home\",\n";
    print YCP_NIS "\t\t\"org_home\": \"$home\",\n";
    print YCP_NIS "\t\t\"shell\": \"$shell\",\n";
#        print YCP_NIS "\t\t\"groupname\": \"$groupname\",\n";
#        print YCP_NIS "\t\t\"grouplist\": \"$grouplist\",\n";
    print YCP_NIS "\t\t\"type\": `nis\n";
    print YCP_NIS "\t],\n";

    print YCP_NIS_BYNAME "\t\"$username\" : $uid,\n";

    # this doesn't look good...
#        @l_grouplist = split (/,/, $grouplist);
#        $filtered = grep ($groupname, @l_grouplist);
#        if ( $filtered == 0 )
#        {
#            if ($grouplist eq "")
#            {
#                $all_groups = $groupname;
#            }
#            else
#            {
#                $all_groups = "$groupname, $grouplist";
#            }
#        }
#        else
#        {
#            $all_groups = $grouplist;
#        }
    $all_groups = "...";

    print YCP_NIS_ITEMLIST "\t`item(`id($uid), \"$username\", ".
        "\"$full\", \"$uid\", \"$all_groups\"),\n";
}
open CORRECT, "> $groups_corrected";
print CORRECT "\$[\n";
foreach $gid (keys %corrected_groups)
{
    print CORRECT "\t$gid : \"$corrected_groups{$gid}\",\n";
}
print CORRECT "]\n";
close CORRECT;

print YCP_NIS "]\n";
print YCP_NIS_BYNAME "]\n";
print YCP_NIS_ITEMLIST "]\n";
print YCP_NIS_UIDLIST "]\n";
print YCP_NIS_HOMES "]\n";
print YCP_NIS_USERNAMES "]\n";

close YCP_NIS_BYNAME;
close YCP_NIS_ITEMLIST;
close YCP_NIS_UIDLIST;
close YCP_NIS_HOMES;
close YCP_NIS_USERNAMES;
close YCP_NIS;
