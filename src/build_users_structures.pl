#!/usr/bin/perl -w

# the input parameters:
$input_dir      = $ARGV[0];
$output_dir     = $ARGV[1];
$max_system_uid = $ARGV[2];
$max_system_gid = $ARGV[3];

$group_input    = $input_dir."/group";
$passwd_input   = $input_dir."/passwd";
$shadow_input   = $input_dir."/shadow";
$gshadow_input  = $input_dir."/gshadow";

$group_system_output            = $output_dir."/group_system.ycp";
$group_local_output             = $output_dir."/group_local.ycp";
$group_byname_output            = $output_dir."/group_byname.ycp";
#$group_system_itemlist          = $output_dir."/group_system_itemlist.ycp";
#$group_local_itemlist           = $output_dir."/group_local_itemlist.ycp";
$shadow_output                  = $output_dir."/shadow.ycp";
$gshadow_output                 = $output_dir."/gshadow.ycp";
$nis_output                     = $output_dir."/nis.ycp";
#$nis_itemlist                   = $output_dir."/nis_itemlist.ycp";
$nis_byname_output              = $output_dir."/nis_byname.ycp";
$passwd_system_output           = $output_dir."/passwd_system.ycp";
$passwd_local_output            = $output_dir."/passwd_local.ycp";
$passwd_system_byname_output    = $output_dir."/passwd_system_byname.ycp";
$passwd_local_byname_output     = $output_dir."/passwd_local_byname.ycp";
#$passwd_system_itemlist         = $output_dir."/passwd_system_itemlist.ycp";
#$passwd_local_itemlist          = $output_dir."/passwd_local_itemlist.ycp";
        
$usernamelist_file  = $output_dir."/usernamelist.ycp";
$homelist_file      = $output_dir."/homelist.ycp";
$uidlist_file       = $output_dir."/uidlist.ycp";

$last_passwd_file = $output_dir."/last_passwd.ycp";
$last_group_file = $output_dir."/last_group.ycp";
$last_shadow_file = $output_dir."/last_shadow.ycp";
$last_gshadow_file = $output_dir."/last_gshadow.ycp";

# hash with the form: user => group1,group2
%users_groups = ();

%groupmap = ();
%passwdmap = ();
%shadowmap = ();

%usernamelists = ();
%homelists = ();

$last_passwd = "";
$last_group = "";
$last_shadow = "";
$last_gshadow = "";

#############################################
# reading shadow, writing it as a YCP map and prepatin shadowmap structure

open SHADOW, "< $shadow_input";

open YCP_SHADOW, "> $shadow_output";
print YCP_SHADOW "\$[\n";

foreach (<SHADOW>)
{
    chomp $_;
    ($username, $password, $last_change, $min, $max, $warn, $inact, $expire,
     $flag) = split(/:/,$_);

    $shadowmap{$username} = $_;

    $first = substr ($username, 0, 1);
    if ( $first ne "+" && $first ne "-" )
    {
        print YCP_SHADOW "\t\"$username\": \$[\n";
        print YCP_SHADOW "\t\t\"password\": \"$password\",\n";
        print YCP_SHADOW "\t\t\"last_change\": \"$last_change\",\n";
        print YCP_SHADOW "\t\t\"min\": \"$min\",\n";
        print YCP_SHADOW "\t\t\"max\": \"$max\",\n";
        print YCP_SHADOW "\t\t\"warn\": \"$warn\",\n";
        print YCP_SHADOW "\t\t\"inact\": \"$inact\",\n";
        print YCP_SHADOW "\t\t\"expire\": \"$expire\",\n";
        print YCP_SHADOW "\t\t\"flag\": \"$flag\"\n";
        print YCP_SHADOW "\t],\n";
    }
    else
    {
        $last_shadow = $_;
    }
}
print YCP_SHADOW "]\n";
close YCP_SHADOW;
close SHADOW;

#############################################
# reading gshadow and writing it as a YCP map

open GSHADOW, "< $gshadow_input";

open YCP_GSHADOW, "> $gshadow_output";
print YCP_GSHADOW "\$[\n";

foreach (<GSHADOW>)
{
    chomp $_;
    ($groupname, $password, $disposer, $userlist) = split(/:/,$_);

    $first = substr ($groupname, 0, 1);
    if ( $first ne "+" && $first ne "-" )
    {
        print YCP_GSHADOW "\t\"$groupname\": \$[\n";
        print YCP_GSHADOW "\t\t\"password\": \"$password\",\n";
        print YCP_GSHADOW "\t\t\"disposer\": \"$disposer\",\n";
        print YCP_GSHADOW "\t\t\"userlist\": \"$userlist\"\n";
        print YCP_GSHADOW "\t],\n";
    }
    else
    {
        $last_gshadow = $_;
    }
}
print YCP_GSHADOW "]\n";
close YCP_GSHADOW;
close GSHADOW;

#############################################
# reading /etc/group and preparing users_groups structure

open GROUP, "< $group_input";

foreach (<GROUP>)
{
    # change last "\n" to ":"
    substr($_, - 1, 1, ":");

    (my $groupname, my $pass, my $gid, my $users) = split (/:/,$_);

    $first = substr ($groupname, 0, 1);
    if ( $first ne "+" && $first ne "-" )
    {
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
        $groupmap{$gid} = $_;
    }
    else
    {
        chop $_; # remove additional ":"
        $last_group = $_;
    }
}

close GROUP;

#############################################

open PASSWD, "< $passwd_input";

#open YCP_PASSWD_ITEMLIST_SYSTEM, "> $passwd_system_itemlist";
open YCP_PASSWD_SYSTEM, "> $passwd_system_output";
open YCP_PASSWD_SYSTEM_BYNAME, "> $passwd_system_byname_output";
#open YCP_PASSWD_ITEMLIST_LOCAL, "> $passwd_local_itemlist";
open YCP_PASSWD_LOCAL, "> $passwd_local_output";
open YCP_PASSWD_LOCAL_BYNAME, "> $passwd_local_byname_output";

#print YCP_PASSWD_ITEMLIST_SYSTEM "\$[\n";
print YCP_PASSWD_SYSTEM "\$[\n";
print YCP_PASSWD_SYSTEM_BYNAME "\$[\n";
#print YCP_PASSWD_ITEMLIST_LOCAL "\$[\n";
print YCP_PASSWD_LOCAL "\$[\n";
print YCP_PASSWD_LOCAL_BYNAME "\$[\n";

foreach $user (<PASSWD>)
{
    chomp $user;
    ($username, $password, $uid, $gid, $full, $home, $shell) = split(/:/,$user);

    $first = substr ($username, 0, 1);
    if ( $first ne "+" && $first ne "-" )
    {

        my $default_group = $groupmap{$gid};
        my @default_group_as_list = split (/:/,$default_group);
        my $groupname = $default_group_as_list[0];

        # modify default group's more_users entry
        if (substr ($default_group, - 1, 1) eq ":")
        {
            $groupmap{$gid} = $default_group.$username;
        }
        else
        {
            $groupmap{$gid} = $default_group.",$username";
        }

        # add the grouplist
        my $grouplist = "";
        if (defined $users_groups{$username})
        {
            $grouplist = $users_groups{$username};
        }

        $passwdmap{$uid} = $username; # only nis users check this map

        my $user_type = "local";
        my $YCP_PASSWD = YCP_PASSWD_LOCAL;
#        my $YCP_PASSWD_ITEMLIST = YCP_PASSWD_ITEMLIST_LOCAL;
        my $YCP_PASSWD_BYNAME = YCP_PASSWD_LOCAL_BYNAME;
        #  499 or 500??
        if (($uid <= $max_system_uid) || ($username eq "nobody"))
        {
            $user_type = "system";
            $YCP_PASSWD = YCP_PASSWD_SYSTEM;
#            $YCP_PASSWD_ITEMLIST = YCP_PASSWD_ITEMLIST_SYSTEM;
            $YCP_PASSWD_BYNAME = YCP_PASSWD_SYSTEM_BYNAME;
        }

        # I could directly write to files, instead of generating structure...
        if (defined  $usernamelists{$user_type})
        {
            $usernamelists{$user_type} .= ", \"$username\"";
            if ($home ne "") # and can be??
            {
                 $homelists{$user_type} .= ", \"$home\"";
            }
        }
        else
        {
            $usernamelists{$user_type} = "\"$username\"";
            $homelists{$user_type} = "\"$home\"";
        }

        # YCP maps are generated...
        print $YCP_PASSWD "\t$uid : \$[\n";
        print $YCP_PASSWD "\t\t\"username\": \"$username\",\n";
        print $YCP_PASSWD "\t\t\"password\": \"$password\",\n";
        print $YCP_PASSWD "\t\t\"uid\": $uid,\n";
        print $YCP_PASSWD "\t\t\"gid\": $gid,\n";
        print $YCP_PASSWD "\t\t\"fullname\": \"$full\",\n";
        print $YCP_PASSWD "\t\t\"home\": \"$home\",\n";
        print $YCP_PASSWD "\t\t\"org_home\": \"$home\",\n";
        print $YCP_PASSWD "\t\t\"shell\": \"$shell\",\n";
        print $YCP_PASSWD "\t\t\"groupname\": \"$groupname\",\n";
        print $YCP_PASSWD "\t\t\"grouplist\": \"$grouplist\",\n";
        print $YCP_PASSWD "\t\t\"shadow\": \$[\n";

        # this split is done twice... !!
        ($uname, $pass, $last_change, $min, $max, $warn, $inact, $expire,
         $flag) = split(/:/,$shadowmap{$username});

            print $YCP_PASSWD "\t\t\t\"password\": \"$pass\",\n";
            print $YCP_PASSWD "\t\t\t\"last_change\": \"$last_change\",\n";
            print $YCP_PASSWD "\t\t\t\"min\": \"$min\",\n";
            print $YCP_PASSWD "\t\t\t\"max\": \"$max\",\n";
            print $YCP_PASSWD "\t\t\t\"warn\": \"$warn\",\n";
            print $YCP_PASSWD "\t\t\t\"inact\": \"$inact\",\n";
            print $YCP_PASSWD "\t\t\t\"expire\": \"$expire\",\n";
            print $YCP_PASSWD "\t\t\t\"flag\": \"$flag\"\n";
            print $YCP_PASSWD "\t\t],\n";
        
        print $YCP_PASSWD "\t\t\"type\": `$user_type\n";
        print $YCP_PASSWD "\t],\n";

        print $YCP_PASSWD_BYNAME "\t\"$username\" : $uid,\n";

        # this doesn't look good...
        @l_grouplist = split (/,/, $grouplist);
        $filtered = grep ($groupname, @l_grouplist);
        if ( $filtered == 0 )
        {
            if ($grouplist eq "")
            {
                $all_groups = $groupname;
            }
            else
            {
                $all_groups = "$groupname, $grouplist";
            }
        }
        else
        {
            $all_groups = $grouplist;
        }

#        print $YCP_PASSWD_ITEMLIST "\t`item(`id($uid), \"$username\", ".
#            "\"$full\", \"$uid\", \"$all_groups\"),\n";

    }
    else # the "+" entry
    {
        $last_passwd = $user;
    }
}

#print YCP_PASSWD_ITEMLIST_LOCAL "]\n";
print YCP_PASSWD_LOCAL "]\n";
print YCP_PASSWD_LOCAL_BYNAME "]\n";
#print YCP_PASSWD_ITEMLIST_SYSTEM "]\n";
print YCP_PASSWD_SYSTEM "]\n";
print YCP_PASSWD_SYSTEM_BYNAME "]\n";

#close YCP_PASSWD_ITEMLIST_LOCAL;
close YCP_PASSWD_LOCAL;
close YCP_PASSWD_LOCAL_BYNAME;
#close YCP_PASSWD_ITEMLIST_SYSTEM;
close YCP_PASSWD_SYSTEM;
close YCP_PASSWD_SYSTEM_BYNAME;
close PASSWD;

#############################################

@getent = `getent passwd`;

open YCP_NIS, "> $nis_output";
open YCP_NIS_BYNAME, "> $nis_byname_output";
#open YCP_NIS_ITEMLIST, "> $nis_itemlist";
open YCP_UIDLIST, "> $uidlist_file";

print YCP_NIS "\$[\n";
print YCP_NIS_BYNAME "\$[\n";
#print YCP_NIS_ITEMLIST "\$[\n";
print YCP_UIDLIST "[\n";

foreach $user (@getent)
{
    ($username, $password, $uid, $gid, $full, $home, $shell) = split(/:/,$user);
    chomp $shell;

    print YCP_UIDLIST " $uid,";

    if (!defined $passwdmap{$uid})
    {
        my $groupname = "";
        if (defined $groupmap{$gid})
        {
            my $default_group = $groupmap{$gid};
            my @default_group_as_list = split (/:/,$default_group);
            $groupname = $default_group_as_list[0];
    
            # modify group's userlist
            if (substr ($default_group, length($default_group) - 1, 1) eq ":")
            {
                $groupmap{$gid} = $default_group.$username;
            }
            else
            {
                $groupmap{$gid} = $default_group.",$username";
            }
        }

        # add the grouplist
        my $grouplist = "";
        if (defined $users_groups{$username})
        {
            $grouplist = $users_groups{$username};
        }

        if (defined  $usernamelists{"nis"})
        {
            $usernamelists{"nis"} .= ", \"$username\"";
            if ($home ne "") # and can be??
            {
                 $homelists{"nis"} .= ", \"$home\"";
            }
        }
        else
        {
            $usernamelists{"nis"} = "\"$username\"";
            $homelists{"nis"} = "\"$home\"";
        }

        # YCP map is generated...
        print YCP_NIS "\t$uid : \$[\n";
        print YCP_NIS "\t\t\"username\": \"$username\",\n";
        print YCP_NIS "\t\t\"password\": \"$password\",\n";
        print YCP_NIS "\t\t\"uid\": $uid,\n";
        print YCP_NIS "\t\t\"gid\": $gid,\n";
        print YCP_NIS "\t\t\"fullname\": \"$full\",\n";
        print YCP_NIS "\t\t\"home\": \"$home\",\n";
        print YCP_NIS "\t\t\"org_home\": \"$home\",\n";
        print YCP_NIS "\t\t\"shell\": \"$shell\",\n";
        print YCP_NIS "\t\t\"groupname\": \"$groupname\",\n";
        print YCP_NIS "\t\t\"grouplist\": \"$grouplist\",\n";
        print YCP_NIS "\t\t\"type\": `nis\n";
        print YCP_NIS "\t],\n";

        print YCP_NIS_BYNAME "\t\"$username\" : $uid,\n";

        # this doesn't look good...
        @l_grouplist = split (/,/, $grouplist);
        $filtered = grep ($groupname, @l_grouplist);
        if ( $filtered == 0 )
        {
            if ($grouplist eq "")
            {
                $all_groups = $groupname;
            }
            else
            {
                $all_groups = "$groupname, $grouplist";
            }
        }
        else
        {
            $all_groups = $grouplist;
        }

#        print YCP_NIS_ITEMLIST "\t`item(`id($uid), \"$username\", ".
#            "\"$full\", \"$uid\", \"$all_groups\"),\n";
    }
}

print YCP_NIS "]\n";
print YCP_NIS_BYNAME "]\n";
#print YCP_NIS_ITEMLIST "]\n";
print YCP_UIDLIST "\n]";

close YCP_NIS;
close YCP_NIS_BYNAME;
#close YCP_NIS_ITEMLIST;
close YCP_UIDLIST;

#############################################
open YCP_USERNAMES, "> $usernamelist_file";
print YCP_USERNAMES "\$[\n";
print YCP_USERNAMES "\t`system: [ ".$usernamelists{"system"}." ],\n";
print YCP_USERNAMES "\t`local: [ ".$usernamelists{"local"}." ],\n";
print YCP_USERNAMES "\t`nis: [ ".$usernamelists{"nis"}." ]\n";
print YCP_USERNAMES "]\n";
close YCP_USERNAMES;
    
open YCP_HOMES, "> $homelist_file";
print YCP_HOMES "\$[\n";
print YCP_HOMES "\t`system: [ ".$homelists{"system"}." ],\n";
print YCP_HOMES "\t`local: [ ".$homelists{"local"}." ],\n";
print YCP_HOMES "\t`nis: [ ".$homelists{"nis"}." ]\n";
print YCP_HOMES "]\n";
close YCP_HOMES;

#############################################
# save the modified map of groups

open YCP_GROUP_LOCAL, "> $group_local_output";
open YCP_GROUP_SYSTEM, "> $group_system_output";
open YCP_GROUP_BYNAME, "> $group_byname_output";
#open YCP_GROUP_ITEMLIST_SYSTEM, "> $group_system_itemlist";
#open YCP_GROUP_ITEMLIST_LOCAL, "> $group_local_itemlist";

print YCP_GROUP_LOCAL "\$[\n";
print YCP_GROUP_SYSTEM "\$[\n";
print YCP_GROUP_BYNAME "\$[\n";
#print YCP_GROUP_ITEMLIST_LOCAL "\$[\n";
#print YCP_GROUP_ITEMLIST_SYSTEM "\$[\n";

foreach (values %groupmap)
{
    ($groupname, $pass, $gid, $userlist, $more_users) = split (/:/,$_);

    my $group_type = "local";
    $YCP_GROUP = YCP_GROUP_LOCAL;
#    $YCP_GROUP_ITEMLIST = YCP_GROUP_ITEMLIST_LOCAL;
    if ($gid <= $max_system_gid || $groupname eq "nobody" ||
        $groupname eq "nogroup" )
    {
        $group_type = "system";
        $YCP_GROUP = YCP_GROUP_SYSTEM;
#        $YCP_GROUP_ITEMLIST = YCP_GROUP_ITEMLIST_SYSTEM;
    }
    print $YCP_GROUP "\t$gid: \$[\n";
    print $YCP_GROUP "\t\t\"groupname\": \"$groupname\",\n";
    print $YCP_GROUP "\t\t\"pass\": \"$pass\",\n";
    print $YCP_GROUP "\t\t\"gid\": $gid,\n";
    print $YCP_GROUP "\t\t\"userlist\": \"$userlist\",\n";
    print $YCP_GROUP "\t\t\"more_users\": \"$more_users\",\n";
    print $YCP_GROUP "\t\t\"type\": `$group_type\n";
    print $YCP_GROUP "\t],\n";

    print YCP_GROUP_BYNAME "\t\"$groupname\": \$[\n";
    print YCP_GROUP_BYNAME "\t\t\"groupname\": \"$groupname\",\n";
    print YCP_GROUP_BYNAME "\t\t\"pass\": \"$pass\",\n";
    print YCP_GROUP_BYNAME "\t\t\"gid\": $gid,\n";
    print YCP_GROUP_BYNAME "\t\t\"userlist\": \"$userlist\",\n";
    print YCP_GROUP_BYNAME "\t\t\"more_users\": \"$more_users\",\n";
    print YCP_GROUP_BYNAME "\t\t\"type\": `$group_type\n";
    print YCP_GROUP_BYNAME "\t],\n";


    $all_users = $userlist;
    if ($userlist ne "" && $more_users ne "")
    {
       $all_users .= ",";
    }
    $all_users .= $more_users;  

#    print $YCP_GROUP_ITEMLIST "\t`item(`id($gid), \"$groupname\", ".
#            "\"$gid\", \"$all_users\"),\n";
}

print YCP_GROUP_LOCAL "]\n";
print YCP_GROUP_SYSTEM "]\n";
print YCP_GROUP_BYNAME "]\n";
#print YCP_GROUP_ITEMLIST_SYSTEM "[\n";
#print YCP_GROUP_ITEMLIST_LOCAL "[\n";

close YCP_GROUP_LOCAL;
close YCP_GROUP_SYSTEM;
close YCP_GROUP_BYNAME;
#close YCP_GROUP_ITEMLIST_SYSTEM;
#close YCP_GROUP_ITEMLIST_LOCAL;


#############################################
# save the possible "+" entries

open LAST_GROUP, "> $last_group_file";
# print map or string ?? and what about the additional ":"?
print LAST_GROUP "\"$last_group\"\n";
close LAST_GROUP;

open LAST_PASSWD, "> $last_passwd_file";
# print map or string ?? and what about the additional ":"?
print LAST_PASSWD "\"$last_passwd\"\n";
close LAST_PASSWD;

open LAST_SHADOW, "> $last_shadow_file";
# print map or string ?? and what about the additional ":"?
print LAST_SHADOW "\"$last_shadow\"\n";
close LAST_SHADOW;

open LAST_GSHADOW, "> $last_gshadow_file";
# print map or string ?? and what about the additional ":"?
print LAST_GSHADOW "\"$last_gshadow\"\n";
close LAST_GSHADOW;
