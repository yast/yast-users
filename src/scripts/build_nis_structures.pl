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
#   build_nis.structures.pl output_directory encoding
#
#  Example:
#   build_nis_structures.pl /tmp iso-8859-2
#
#

# for encoding the fullnames
use Encode 'from_to';

# the input parameters:

$output_dir     = $ARGV[0];
$encod          = $ARGV[1];

$nis_output         = $output_dir."/nis.ycp";
$nis_byname_output  = $output_dir."/nis_byname.ycp";

$usernamelist_nis   = $output_dir."/usernamelist_nis.ycp";

$homelist_nis       = $output_dir."/homelist_nis.ycp";

$nis_itemlist       = $output_dir."/itemlist_nis.ycp";

$uidlist_nis        = $output_dir."/uidlist_nis.ycp";

$group_nis          = $output_dir."/group_nis.ycp";
$group_nis_byname   = $output_dir."/group_nis_byname.ycp";
$group_nis_itemlist = $output_dir."/group_nis_itemlist.ycp";
$gidlist_nis        = $output_dir."/gidlist_nis.ycp";
$groupnamelist_nis  = $output_dir."/groupnamelist_nis.ycp";


$the_answer = 42; # ;-)
$max_length_id = length("60000");

# addBlanks to uid entry in table
sub addBlanks {

    my ($id) = @_;
    $missing = $max_length_id - length ($id);
    if ($missing > 0)
    {
        for ($i = 0; $i < $missing; $i++)
        {
            $id = " ".$id;
        }
    }
    return $id;
}

@ypcat_group = `ypcat group`;

foreach my $group (@ypcat_group)
{

    chop $group;
    my ($groupname, $pass, $gid, $users) = split (/:/,$group);

    $groupmap{$gid} = $group;

    # for each user generate list of groups, where the user is contained
    my @userlist = split(/,/,$users);
    foreach my $u (@userlist)
    {
        if (defined $users_groups{$u})
        {
            $users_groups{$u} = $users_groups{$u}.",$groupname";
        }
        else
        {
            $users_groups{$u} = $groupname;
        }
    }
}

@ypcat = `ypcat passwd`;  # add a check for existence !

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

foreach my $user (@ypcat)
{
    my ($username, $password, $uid, $gid, $full, $home, $shell)
        = split(/:/,$user);
    chomp $shell;

    print YCP_NIS_UIDLIST " $uid,";
        
    my $groupname = "";
    if (defined $groupmap{$gid})
    {
        ($groupname) = split (/:/,$groupmap{$gid});

        # modify default group's more_users entry
        if (defined $more_usersmap{$gid})
        {
            $more_usersmap{$gid} .= ",$username";
        }
        else
        {
            $more_usersmap{$gid} = $username;
        }
    }

    # add the grouplist
    my $grouplist = "";
    if (defined $users_groups{$username})
    {
        $grouplist = $users_groups{$username};
    }

    print YCP_NIS_HOMES " \"$home\",";
    print YCP_NIS_USERNAMES " \"$username\",";

    # recode the fullname to utf
    from_to($full, $encod, "utf-8");

    print YCP_NIS "\t$uid : \$[\n";
    print YCP_NIS "\t\t\"username\": \"$username\",\n";
    print YCP_NIS "\t\t\"password\": \"$password\",\n";
    print YCP_NIS "\t\t\"uid\": $uid,\n";
    print YCP_NIS "\t\t\"gid\": $gid,\n";
    print YCP_NIS "\t\t\"cn\": \"$full\",\n";
    print YCP_NIS "\t\t\"home\": \"$home\",\n";
    print YCP_NIS "\t\t\"org_home\": \"$home\",\n";
    print YCP_NIS "\t\t\"shell\": \"$shell\",\n";
    print YCP_NIS "\t\t\"groupname\": \"$groupname\",\n";
    print YCP_NIS "\t\t\"grouplist\": \"$grouplist\",\n";
    print YCP_NIS "\t\t\"type\": \"nis\"\n";
    print YCP_NIS "\t],\n";

    print YCP_NIS_BYNAME "\t\"$username\" : $uid,\n";

    if ( $groupname ne "" )
    {
        if ($grouplist eq "")
        {
            $all_groups = $groupname;
        }
        else
        {
            $all_groups = "$groupname,$grouplist";
        }
    }
    else
    {
        $all_groups = $grouplist;
    }
    $all_groups .= "...";

    $uid_wide = addBlanks ($uid);
    print YCP_NIS_ITEMLIST "\t`item(`id($uid), \"$username\", ".
        "\"$full\", \"$uid_wide\", \"$all_groups\"),\n";
}

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


#--- and now... the NIS groups!

open YCP_NISGROUP, "> $group_nis";
open YCP_NISGROUP_BYNAME, "> $group_nis_byname";
open YCP_NISGROUP_ITEMLIST, "> $group_nis_itemlist";
open YCP_NISGIDLIST, "> $gidlist_nis";
open YCP_NISGROUPNAMELIST, "> $groupnamelist_nis";

print YCP_NISGIDLIST "[\n";
print YCP_NISGROUPNAMELIST "[\n";
print YCP_NISGROUP "\$[\n";
print YCP_NISGROUP_BYNAME "\$[\n";
print YCP_NISGROUP_ITEMLIST "[\n";

foreach (values %groupmap)
{
    my ($groupname, $pass, $gid, $userlist) = split (/:/,$_);
    if (defined $more_usersmap{$gid}) {
        $more_users = $more_usersmap{$gid};
    }
    else {
        $more_users = "";
    }

    my $group_type = "nis";
    
    print YCP_NISGROUP "\t$gid: \$[\n";
    print YCP_NISGROUP "\t\t\"groupname\": \"$groupname\",\n";
    print YCP_NISGROUP "\t\t\"pass\": \"$pass\",\n";
    print YCP_NISGROUP "\t\t\"gid\": $gid,\n";
    print YCP_NISGROUP "\t\t\"userlist\": \"$userlist\",\n";
    print YCP_NISGROUP "\t\t\"more_users\": \"$more_users\",\n";
    print YCP_NISGROUP "\t\t\"type\": \"$group_type\"\n";
    print YCP_NISGROUP "\t],\n";

    print YCP_NISGROUP_BYNAME "\t\"$groupname\": \$[\n";
    print YCP_NISGROUP_BYNAME "\t\t\"groupname\": \"$groupname\",\n";
    print YCP_NISGROUP_BYNAME "\t\t\"pass\": \"$pass\",\n";
    print YCP_NISGROUP_BYNAME "\t\t\"gid\": $gid,\n";
    print YCP_NISGROUP_BYNAME "\t\t\"userlist\": \"$userlist\",\n";
    print YCP_NISGROUP_BYNAME "\t\t\"more_users\": \"$more_users\",\n";
    print YCP_NISGROUP_BYNAME "\t\t\"type\": \"$group_type\"\n";
    print YCP_NISGROUP_BYNAME "\t],\n";
           
    print YCP_NISGROUPNAMELIST "\"$groupname\",";
    
    print YCP_NISGIDLIST " $gid,";

    $all_users = $userlist;
    if ($userlist ne "" && $more_users ne "")
    {
       $all_users .= ",";
    }
    $all_users .= $more_users;

    # shorten the list, if it is too long
    @users_list = split (/,/,$all_users);
    if (@users_list > $the_answer)
    {
        $all_users = "";
        for ($i=0; $i < $the_answer; $i++)
        {
            $all_users .= "$users_list[$i],";
        }
        $all_users .= "...";
    }

    $gid_wide = addBlanks ($gid);
    print YCP_NISGROUP_ITEMLIST "\t`item(`id($gid), \"$groupname\", ".
            "\"$gid_wide\", \"$all_users\"),\n";

}

print YCP_NISGROUP_BYNAME "]\n";
print YCP_NISGROUP_ITEMLIST "]\n";
print YCP_NISGIDLIST "]\n";
print YCP_NISGROUPNAMELIST "]\n";
print YCP_NISGROUP "]\n";

close YCP_NISGIDLIST;
close YCP_NISGROUPNAMELIST;
close YCP_NISGROUP_BYNAME;
close YCP_NISGROUP_ITEMLIST;
close YCP_NISGROUP;
