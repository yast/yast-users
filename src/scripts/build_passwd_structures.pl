#!/usr/bin/perl -w
#
#  File:
#       build_passwd_structures.pl
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
#  Example of usage:
#   build_passwd_structures.pl /etc /tmp 499 499 iso-8859-2
#

# for encoding the fullnames
use Encode 'from_to';

# the input parameters:

$input_dir      = $ARGV[0];
$output_dir     = $ARGV[1];
$max_system_uid = $ARGV[2];
$max_system_gid = $ARGV[3];
$encod          = $ARGV[4];

$group_input    = $input_dir."/group";
$passwd_input   = $input_dir."/passwd";
$shadow_input   = $input_dir."/shadow";
$gshadow_input  = $input_dir."/gshadow";

$group_system_output            = $output_dir."/group_system.ycp";
$group_local_output             = $output_dir."/group_local.ycp";
$group_byname_local             = $output_dir."/group_local_byname.ycp";
$group_byname_system            = $output_dir."/group_system_byname.ycp";
$group_system_itemlist          = $output_dir."/group_system_itemlist.ycp";
$group_local_itemlist           = $output_dir."/group_local_itemlist.ycp";

$shadow_local                   = $output_dir."/shadow_local.ycp";
$shadow_system                  = $output_dir."/shadow_system.ycp";

$gshadow_local                  = $output_dir."/gshadow_local.ycp";
$gshadow_system                 = $output_dir."/gshadow_system.ycp";

$passwd_system_output           = $output_dir."/passwd_system.ycp";
$passwd_local_output            = $output_dir."/passwd_local.ycp";
$passwd_system_byname_output    = $output_dir."/passwd_system_byname.ycp";
$passwd_local_byname_output     = $output_dir."/passwd_local_byname.ycp";

$usernamelist_local  = $output_dir."/usernamelist_local.ycp";
$usernamelist_system = $output_dir."/usernamelist_system.ycp";

$homelist_local      = $output_dir."/homelist_local.ycp";
$homelist_system     = $output_dir."/homelist_system.ycp";

$passwd_system_itemlist         = $output_dir."/itemlist_system.ycp";
$passwd_local_itemlist          = $output_dir."/itemlist_local.ycp";

$uidlist_local          = $output_dir."/uidlist_local.ycp";
$uidlist_system         = $output_dir."/uidlist_system.ycp";

$groupnamelist_local    = $output_dir."/groupnamelist_local.ycp";
$groupnamelist_system   = $output_dir."/groupnamelist_system.ycp";
$gidlist_local          = $output_dir."/gidlist_local.ycp";
$gidlist_system         = $output_dir."/gidlist_system.ycp";

$plus_passwd_file   = $output_dir."/plus_passwd.ycp";
$plus_group_file    = $output_dir."/plus_group.ycp";
$plus_shadow_file   = $output_dir."/plus_shadow.ycp";
$plus_gshadow_file  = $output_dir."/plus_gshadow.ycp";

$last_local      =   $output_dir."/last_local_uid.ycp";
$last_system     =   $output_dir."/last_system_uid.ycp";

# hash with the form: user => group1,group2
%users_groups = ();

%groupmap = ();
%shadowmap = ();
%gshadowmap = ();

%uids = ();

%groupnamelists = ();

$last_local_uid = $max_system_uid + 1;
$last_system_uid = 0;

$the_answer = 42; # ;-)
$max_length_id = length("60000");

# for debugging
sub print_date {

#    my ($message) = @_;
#    $date = `date +%X`;
#    print STDERR "$message: $date";
}
        
# addBlanks to uid entry in table
sub addBlanks {

    my ($id) = @_;
    my $missing = $max_length_id - length ($id);
    if ($missing > 0)
    {
        for ($i = 0; $i < $missing; $i++)
        {
            $id = " ".$id;
        }
    }
    return $id;
}
    

#---------------------------------------------
# read shadow, write it as a YCP map and prepare shadowmap structure

open SHADOW, "< $shadow_input";

foreach my $shadow_entry (<SHADOW>)
{
    chomp $shadow_entry;

    my $first = substr ($shadow_entry, 0, 1);
    if ( $first ne "+" && $first ne "-" )
    {
        my @list = split(/:/,$shadow_entry);
        my $username = $list[0];
        $shadowmap{$username} = $shadow_entry;
    }
    else
    {
        # save the possible "+"/"-" entries
        open PLUS_SHADOW, "> $plus_shadow_file";
        print PLUS_SHADOW "\"$shadow_entry\"\n";
        close PLUS_SHADOW;
    }
}
close SHADOW;

print_date ("shadow done");

#---------------------------------------------
# reading gshadow and writing it as a YCP map

open GSHADOW, "< $gshadow_input";

foreach (<GSHADOW>)
{
    chomp $_;
    my ($groupname, $password, $disposer, $userlist) = split(/:/,$_);

    my $first = substr ($groupname, 0, 1);
    if ( $first ne "+" && $first ne "-" )
    {
        $gshadowmap{$groupname} = $_;
    }
    else
    {
        # save the possible "+"/"-" entries
        open PLUS_GSHADOW, "> $plus_gshadow_file";
        print PLUS_GSHADOW "\"$_\"\n";
        close PLUS_GSHADOW;
    }
}
close GSHADOW;

print_date ("gshadow done");

#---------------------------------------------
# reading /etc/group and preparing users_groups structure

open GROUP, "< $group_input";

foreach (<GROUP>)
{
    chop $_;
    my ($groupname, $pass, $gid, $users) = split (/:/,$_);

    my $first = substr ($groupname, 0, 1);
    if ( $first ne "+" && $first ne "-" )
    {
        $groupmap{$gid} = $_;

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
    else # save the possible "+"/"-" entries
    {
        open PLUS_GROUP, "> $plus_group_file";
        print PLUS_GROUP "\"$_\"\n";
        close PLUS_GROUP;
    }
}

close GROUP;
print_date ("group read");

#---------------------------------------------
# and finally read the passwd

open PASSWD, "< $passwd_input";

open YCP_SYSTEM_ITEMLIST, "> $passwd_system_itemlist";
open YCP_SYSTEM, "> $passwd_system_output";
open YCP_SYSTEM_BYNAME, "> $passwd_system_byname_output";
open YCP_LOCAL_ITEMLIST, "> $passwd_local_itemlist";
open YCP_LOCAL, "> $passwd_local_output";
open YCP_LOCAL_BYNAME, "> $passwd_local_byname_output";

print YCP_SYSTEM_ITEMLIST "[\n";
print YCP_SYSTEM "\$[\n";
print YCP_SYSTEM_BYNAME "\$[\n";
print YCP_LOCAL_ITEMLIST "[\n";
print YCP_LOCAL "\$[\n";
print YCP_LOCAL_BYNAME "\$[\n";

open YCP_LOCAL_UIDLIST, "> $uidlist_local";
print YCP_LOCAL_UIDLIST "[ ";

open YCP_SYSTEM_UIDLIST, "> $uidlist_system";
print YCP_SYSTEM_UIDLIST "[ ";

open YCP_LOCAL_USERNAMES, "> $usernamelist_local";
print YCP_LOCAL_USERNAMES "[ ";

open YCP_SYSTEM_USERNAMES, "> $usernamelist_system";
print YCP_SYSTEM_USERNAMES "[ ";

open YCP_LOCAL_HOMES, "> $homelist_local";
print YCP_LOCAL_HOMES "[ ";

open YCP_SYSTEM_HOMES, "> $homelist_system";
print YCP_SYSTEM_HOMES "[ ";

open YCP_SHADOW_LOCAL, "> $shadow_local";
print YCP_SHADOW_LOCAL "\$[\n";

open YCP_SHADOW_SYSTEM, "> $shadow_system";
print YCP_SHADOW_SYSTEM "\$[\n";

print_date ("passwd start");

foreach my $user (<PASSWD>)
{
    chomp $user;
    my ($username, $password, $uid, $gid, $full, $home, $shell)
     = split(/:/,$user);

    my $first = substr ($username, 0, 1);

    if ( $first ne "+" && $first ne "-" )
    {

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

        my $user_type = "local";
        my $YCP_PASSWD = YCP_LOCAL;
        my $YCP_PASSWD_ITEMLIST = YCP_LOCAL_ITEMLIST;
        my $YCP_PASSWD_BYNAME = YCP_LOCAL_BYNAME;
        my $YCP_PASSWD_HOMES = YCP_LOCAL_HOMES;
        my $YCP_PASSWD_USERNAMES = YCP_LOCAL_USERNAMES;
        my $YCP_PASSWD_UIDLIST = YCP_LOCAL_UIDLIST;
        my $YCP_SHADOW = YCP_SHADOW_LOCAL;
        
        if (($uid <= $max_system_uid) || ($username eq "nobody"))
        {
            $user_type = "system";
            $YCP_PASSWD = YCP_SYSTEM;
            $YCP_PASSWD_ITEMLIST = YCP_SYSTEM_ITEMLIST;
            $YCP_PASSWD_BYNAME = YCP_SYSTEM_BYNAME;
            $YCP_PASSWD_HOMES = YCP_SYSTEM_HOMES;
            $YCP_PASSWD_USERNAMES = YCP_SYSTEM_USERNAMES;
            $YCP_PASSWD_UIDLIST = YCP_SYSTEM_UIDLIST;
            $YCP_SHADOW = YCP_SHADOW_SYSTEM;
            if ($last_system_uid < $uid && $username ne "nobody")
            {
                $last_system_uid = $uid;
            }
        }
        else
        {
            if ($last_local_uid < $uid)
            {
                $last_local_uid = $uid;
            }
        }
        # recode the fullname to utf
        from_to ($full, $encod, "utf-8"); # this slows a bit...
    
        my $colon = index ($full, ",");
        my $additional = "";
        if ( $colon > -1)
        {
            $additional = $full;
            $full = substr ($additional, 0, $colon);
            $additional = substr ($additional, $colon + 1,length ($additional));
        }

        print $YCP_PASSWD_HOMES "\"$home\", ";
        print $YCP_PASSWD_USERNAMES "\"$username\", ";
        print $YCP_PASSWD_UIDLIST " $uid,";

        if (defined $uids{$uid})
        {
            print STDERR "Duplicated UID:$uid! Exiting...\n";
            exit 1;
        }
        else
        {
            $uids{$uid} = 1;
        }
    
        # YCP maps are generated...
        print $YCP_PASSWD "\t$uid : \$[\n";
        print $YCP_PASSWD "\t\t\"username\": \"$username\",\n";
        print $YCP_PASSWD "\t\t\"password\": \"$password\",\n";
        print $YCP_PASSWD "\t\t\"uid\": $uid,\n";
        print $YCP_PASSWD "\t\t\"gid\": $gid,\n";
            
        print $YCP_PASSWD "\t\t\"fullname\": \"$full\",\n";
        if ($additional ne "")
        {
            print $YCP_PASSWD "\t\t\"addit_data\": \"$additional\",\n";
        }
        print $YCP_PASSWD "\t\t\"home\": \"$home\",\n";
        print $YCP_PASSWD "\t\t\"org_home\": \"$home\",\n";
        print $YCP_PASSWD "\t\t\"shell\": \"$shell\",\n";
        print $YCP_PASSWD "\t\t\"groupname\": \"$groupname\",\n";
        print $YCP_PASSWD "\t\t\"grouplist\": \"$grouplist\",\n";
        print $YCP_PASSWD "\t\t\"type\": `$user_type\n";
        print $YCP_PASSWD "\t],\n";

        print $YCP_PASSWD_BYNAME "\t\"$username\" : $uid,\n";

        my ($uname, $pass, $last_change, $min, $max, $warn, $inact,
         $expire, $flag) = split(/:/,$shadowmap{$username});  

        print $YCP_SHADOW "\t\"$uname\": \$[\n";
        print $YCP_SHADOW "\t\t\"password\": \"$pass\",\n";
        print $YCP_SHADOW "\t\t\"last_change\": \"$last_change\",\n";
        print $YCP_SHADOW "\t\t\"min\": \"$min\",\n";
        print $YCP_SHADOW "\t\t\"max\": \"$max\",\n";
        print $YCP_SHADOW "\t\t\"warn\": \"$warn\",\n";
        print $YCP_SHADOW "\t\t\"inact\": \"$inact\",\n";
        print $YCP_SHADOW "\t\t\"expire\": \"$expire\",\n";
        print $YCP_SHADOW "\t\t\"flag\": \"$flag\"\n";
        print $YCP_SHADOW "\t],\n";

        # check for duplicates !
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

        $uid_wide = addBlanks ($uid);
        if ($user_type eq "local")
        {
            print $YCP_PASSWD_ITEMLIST "\t`item(`id($uid), \"$username\", \"$full\", \"$uid_wide\", \"$all_groups\"),\n";
        }
        else
        {
            print $YCP_PASSWD_ITEMLIST "\t`item(`id($uid), \"$username\", ".
#                "SystemUsers[\"$username\"]:\"$full\", \"$uid_wide\", ".
                "SystemUsers[\"$full\"]:\"$full\", \"$uid_wide\", ".
                "\"$all_groups\"),\n";
        } 
    }
    else # the "+" entry
    {
        open PLUS_PASSWD, "> $plus_passwd_file";
        print PLUS_PASSWD "\"$user\"\n";
        close PLUS_PASSWD;
    }
}

print YCP_LOCAL_ITEMLIST "]\n";
print YCP_LOCAL "]\n";
print YCP_LOCAL_BYNAME "]\n";
print YCP_SYSTEM_ITEMLIST "]\n";
print YCP_SYSTEM "]\n";
print YCP_SYSTEM_BYNAME "]\n";
print YCP_LOCAL_UIDLIST "]\n";
print YCP_SYSTEM_UIDLIST "]\n";
print YCP_LOCAL_HOMES "]\n";
print YCP_SYSTEM_HOMES "]\n";
print YCP_LOCAL_USERNAMES "]\n";
print YCP_SYSTEM_USERNAMES "]\n";
print YCP_SHADOW_SYSTEM "]\n";
print YCP_SHADOW_LOCAL "]\n";

close YCP_LOCAL_ITEMLIST;
close YCP_LOCAL;
close YCP_LOCAL_BYNAME;
close YCP_SYSTEM_ITEMLIST;
close YCP_SYSTEM;
close YCP_SYSTEM_BYNAME;
close YCP_LOCAL_UIDLIST;
close YCP_SYSTEM_UIDLIST;
close YCP_LOCAL_HOMES;
close YCP_SYSTEM_HOMES;
close YCP_LOCAL_USERNAMES;
close YCP_SYSTEM_USERNAMES;
close YCP_SHADOW_SYSTEM;
close YCP_SHADOW_LOCAL;

close PASSWD;

open MAX_LOCAL_UID, "> $last_local";
print MAX_LOCAL_UID "$last_local_uid";
close MAX_LOCAL_UID;

open MAX_SYSTEM_UID, "> $last_system";
print MAX_SYSTEM_UID "$last_system_uid";
close MAX_SYSTEM_UID;

print_date ("passwd done");

#---------------------------------------------
# save the modified map of groups

open YCP_GROUP_LOCAL, "> $group_local_output";
open YCP_GROUP_SYSTEM, "> $group_system_output";
open YCP_GROUP_BYNAME_LOCAL, "> $group_byname_local";
open YCP_GROUP_BYNAME_SYSTEM, "> $group_byname_system";
open YCP_GROUP_ITEMLIST_SYSTEM, "> $group_system_itemlist";
open YCP_GROUP_ITEMLIST_LOCAL, "> $group_local_itemlist";

open YCP_GIDLIST_LOCAL, "> $gidlist_local";
print YCP_GIDLIST_LOCAL "[\n";

open YCP_GIDLIST_SYSTEM, "> $gidlist_system";
print YCP_GIDLIST_SYSTEM "[\n";

open YCP_GROUPNAMELIST_LOCAL, "> $groupnamelist_local";
print YCP_GROUPNAMELIST_LOCAL "[\n";

open YCP_GROUPNAMELIST_SYSTEM, "> $groupnamelist_system";
print YCP_GROUPNAMELIST_SYSTEM "[\n";

print YCP_GROUP_LOCAL "\$[\n";
print YCP_GROUP_SYSTEM "\$[\n";
print YCP_GROUP_BYNAME_LOCAL "\$[\n";
print YCP_GROUP_BYNAME_SYSTEM "\$[\n";
print YCP_GROUP_ITEMLIST_LOCAL "[\n";
print YCP_GROUP_ITEMLIST_SYSTEM "[\n";

open YCP_GSHADOW_LOCAL, "> $gshadow_local";
print YCP_GSHADOW_LOCAL "\$[\n";

open YCP_GSHADOW_SYSTEM, "> $gshadow_system";
print YCP_GSHADOW_SYSTEM "\$[\n";

foreach (values %groupmap)
{
    my ($groupname, $pass, $gid, $userlist) = split (/:/,$_);
    if (defined $more_usersmap{$gid}) {
        $more_users = $more_usersmap{$gid};
    }
    else {
        $more_users = "";
    }

    my $group_type = "local";
    $YCP_GROUP = YCP_GROUP_LOCAL;
    $YCP_GROUP_ITEMLIST = YCP_GROUP_ITEMLIST_LOCAL;
    $YCP_GSHADOW = YCP_GSHADOW_LOCAL;
    $YCP_GIDLIST = YCP_GIDLIST_LOCAL;
    $YCP_GROUPNAMELIST = YCP_GROUPNAMELIST_LOCAL;
    $YCP_GROUP_BYNAME = YCP_GROUP_BYNAME_LOCAL;
    if (($gid <= $max_system_gid || $groupname eq "nobody" ||
         $groupname eq "nogroup") &&
        ($groupname ne "users"))
    {
        $group_type = "system";
        $YCP_GROUP = YCP_GROUP_SYSTEM;
        $YCP_GROUP_ITEMLIST = YCP_GROUP_ITEMLIST_SYSTEM;
        $YCP_GSHADOW = YCP_GSHADOW_SYSTEM;
        $YCP_GIDLIST = YCP_GIDLIST_SYSTEM;
        $YCP_GROUPNAMELIST = YCP_GROUPNAMELIST_SYSTEM;
        $YCP_GROUP_BYNAME = YCP_GROUP_BYNAME_SYSTEM;
    }

    if (defined $gshadowmap{$groupname})
    {
        my ($name, $shadow_pass, $disp, $ulist)
            = split(/:/,$gshadowmap{$groupname});

        if ( $shadow_pass ne "" && $shadow_pass ne "+" &&
             $shadow_pass ne "*" && $shadow_pass ne "!")
        {
            $pass = $shadow_pass;
        }

        print $YCP_GSHADOW "\t\"$name\": \$[\n";
        print $YCP_GSHADOW "\t\t\"password\": \"$shadow_pass\",\n";
        print $YCP_GSHADOW "\t\t\"disposer\": \"$disp\",\n";
        print $YCP_GSHADOW "\t\t\"userlist\": \"$ulist\"\n";
        print $YCP_GSHADOW "\t],\n";
    }
    
    print $YCP_GROUP "\t$gid: \$[\n";
    print $YCP_GROUP "\t\t\"groupname\": \"$groupname\",\n";
    print $YCP_GROUP "\t\t\"pass\": \"$pass\",\n";
    print $YCP_GROUP "\t\t\"gid\": $gid,\n";
    print $YCP_GROUP "\t\t\"userlist\": \"$userlist\",\n";
    print $YCP_GROUP "\t\t\"more_users\": \"$more_users\",\n";
    print $YCP_GROUP "\t\t\"type\": `$group_type\n";
    print $YCP_GROUP "\t],\n";

    print $YCP_GROUP_BYNAME "\t\"$groupname\": \$[\n";
    print $YCP_GROUP_BYNAME "\t\t\"groupname\": \"$groupname\",\n";
    print $YCP_GROUP_BYNAME "\t\t\"pass\": \"$pass\",\n";
    print $YCP_GROUP_BYNAME "\t\t\"gid\": $gid,\n";
    print $YCP_GROUP_BYNAME "\t\t\"userlist\": \"$userlist\",\n";
    print $YCP_GROUP_BYNAME "\t\t\"more_users\": \"$more_users\",\n";
    print $YCP_GROUP_BYNAME "\t\t\"type\": `$group_type\n";
    print $YCP_GROUP_BYNAME "\t],\n";
           
    print $YCP_GROUPNAMELIST "\"$groupname\",";
    
    print $YCP_GIDLIST " $gid,";

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
    print $YCP_GROUP_ITEMLIST "\t`item(`id($gid), \"$groupname\", ".
            "\"$gid_wide\", \"$all_users\"),\n";
}

print YCP_GROUP_LOCAL "]\n";
print YCP_GROUP_SYSTEM "]\n";
print YCP_GROUP_BYNAME_LOCAL "]\n";
print YCP_GROUP_BYNAME_SYSTEM "]\n";
print YCP_GROUP_ITEMLIST_SYSTEM "]\n";
print YCP_GROUP_ITEMLIST_LOCAL "]\n";

print YCP_GIDLIST_LOCAL "]\n";
close YCP_GIDLIST_LOCAL;
print YCP_GIDLIST_SYSTEM "]\n";
close YCP_GIDLIST_SYSTEM;

print YCP_GROUPNAMELIST_LOCAL "]\n";
close YCP_GROUPNAMELIST_LOCAL;
print YCP_GROUPNAMELIST_SYSTEM "]\n";
close YCP_GROUPNAMELIST_SYSTEM;

close YCP_GROUP_LOCAL;
close YCP_GROUP_SYSTEM;
close YCP_GROUP_BYNAME_LOCAL;
close YCP_GROUP_BYNAME_SYSTEM;
close YCP_GROUP_ITEMLIST_SYSTEM;
close YCP_GROUP_ITEMLIST_LOCAL;

print YCP_GSHADOW_LOCAL "]\n";
close YCP_GSHADOW_LOCAL;
print YCP_GSHADOW_SYSTEM "]\n";
close YCP_GSHADOW_SYSTEM;

print_date ("group done");
