#!/usr/bin/perl -w
#
#  File:
#       build_user_structures.pl
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


# the input parameters:

$input_dir      = $ARGV[0];
$output_dir     = $ARGV[1];
$max_system_uid = $ARGV[2];
$max_system_gid = $ARGV[3];
$user_type      = $ARGV[4];

$group_input    = $input_dir."/group";
$passwd_input   = $input_dir."/passwd";
$shadow_input   = $input_dir."/shadow";
$gshadow_input  = $input_dir."/gshadow";

$group_system_output            = $output_dir."/group_system.ycp";
$group_local_output             = $output_dir."/group_local.ycp";
$group_byname_output            = $output_dir."/group_byname.ycp";
#$group_system_itemlist          = $output_dir."/group_system_itemlist.ycp";
#$group_local_itemlist           = $output_dir."/group_local_itemlist.ycp";

$shadow_local                   = $output_dir."/shadow_local.ycp";
$shadow_system                  = $output_dir."/shadow_system.ycp";

$gshadow_local                  = $output_dir."/gshadow_local.ycp";
$gshadow_system                 = $output_dir."/gshadow_system.ycp";

$nis_output                     = $output_dir."/nis.ycp";
$nis_byname_output              = $output_dir."/nis_byname.ycp";

$ldap_output                    = $output_dir."/ldap.ycp";
$ldap_byname_output             = $output_dir."/ldap_byname.ycp";

$passwd_system_output           = $output_dir."/passwd_system.ycp";
$passwd_local_output            = $output_dir."/passwd_local.ycp";
$passwd_system_byname_output    = $output_dir."/passwd_system_byname.ycp";
$passwd_local_byname_output     = $output_dir."/passwd_local_byname.ycp";

#$additional_users               = $output_dir."/additional_users.ycp";
        
$usernamelist_local  = $output_dir."/usernamelist_local.ycp";
$usernamelist_system  = $output_dir."/usernamelist_system.ycp";
$usernamelist_nis  = $output_dir."/usernamelist_nis.ycp";
$usernamelist_ldap  = $output_dir."/usernamelist_ldap.ycp";

$homelist_local      = $output_dir."/homelist_local.ycp";
$homelist_system      = $output_dir."/homelist_system.ycp";
$homelist_nis      = $output_dir."/homelist_nis.ycp";
$homelist_ldap      = $output_dir."/homelist_ldap.ycp";

$passwd_system_itemlist         = $output_dir."/itemlist_system.ycp";
$passwd_local_itemlist          = $output_dir."/itemlist_local.ycp";
$nis_itemlist                   = $output_dir."/itemlist_nis.ycp";
$ldap_itemlist                   = $output_dir."/itemlist_ldap.ycp";

$uidlist_local       = $output_dir."/uidlist_local.ycp";
$uidlist_system       = $output_dir."/uidlist_system.ycp";
$uidlist_nis       = $output_dir."/uidlist_nis.ycp";
$uidlist_ldap       = $output_dir."/uidlist_ldap.ycp";

$groupnamelist_file  = $output_dir."/groupnamelist.ycp";
$gidlist_file       = $output_dir."/gidlist.ycp";

$plus_passwd_file = $output_dir."/plus_passwd.ycp";
$plus_group_file = $output_dir."/plus_group.ycp";
$plus_shadow_file = $output_dir."/plus_shadow.ycp";
$plus_gshadow_file = $output_dir."/plus_gshadow.ycp";

# hash with the form: user => group1,group2
%users_groups = ();

%groupmap = ();
#%passwdmap = ();
%shadowmap = ();
%gshadowmap = ();

%groupnamelists = ();


#############################################
#############################################
sub read_local()
{

    #############################################
    # read shadow, write it as a YCP map and prepare shadowmap structure

    open SHADOW, "< $shadow_input";

    foreach $shadow_entry (<SHADOW>)
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

    #############################################
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

    #############################################
    # reading /etc/group and preparing users_groups structure

    open GROUP, "< $group_input";

    foreach (<GROUP>)
    {
        my ($groupname, $pass, $gid, $users) = split (/:/,$_);

        my $first = substr ($groupname, 0, 1);
        if ( $first ne "+" && $first ne "-" )
        {
            # change last "\n" to ":"
            substr($_, - 1, 1, ":");

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
        else # save the possible "+"/"-" entries
        {
            open PLUS_GROUP, "> $plus_group_file";
            print PLUS_GROUP "\"$_\"\n";
            close PLUS_GROUP;
        }
    }

    close GROUP;

    #############################################
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

    foreach $user (<PASSWD>)
    {
        chomp $user;
        my ($username, $password, $uid, $gid, $full, $home, $shell)
         = split(/:/,$user);

        my $first = substr ($username, 0, 1);
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

#            $passwdmap{$uid} = $username; # only passwd users check this map

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
            }

            # I could directly write to files, instead of generating structure...
            print $YCP_PASSWD_HOMES "\"$home\", ";
            print $YCP_PASSWD_USERNAMES "\"$username\", ";
            print $YCP_PASSWD_UIDLIST " $uid,";
        
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

            my ($uname, $pass, $last_change, $min, $max, $warn, $inact,
             $expire, $flag) = split(/:/,$shadowmap{$username});

                # the shadow entry of this user
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

            print $YCP_PASSWD_ITEMLIST "\t`item(`id($uid), \"$username\", ".
                "\"$full\", \"$uid\", \"$all_groups\"),\n";

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

    #############################################
    # save the modified map of groups
    
    open YCP_GROUP_LOCAL, "> $group_local_output";
    open YCP_GROUP_SYSTEM, "> $group_system_output";
    open YCP_GROUP_BYNAME, "> $group_byname_output";
    #open YCP_GROUP_ITEMLIST_SYSTEM, "> $group_system_itemlist";
    #open YCP_GROUP_ITEMLIST_LOCAL, "> $group_local_itemlist";
    
    open YCP_GIDLIST, "> $gidlist_file";
    print YCP_GIDLIST "[\n";
    
    print YCP_GROUP_LOCAL "\$[\n";
    print YCP_GROUP_SYSTEM "\$[\n";
    print YCP_GROUP_BYNAME "\$[\n";
    #print YCP_GROUP_ITEMLIST_LOCAL "[\n";
    #print YCP_GROUP_ITEMLIST_SYSTEM "[\n";
    
    open YCP_GSHADOW_LOCAL, "> $gshadow_local";
    print YCP_GSHADOW_LOCAL "\$[\n";

    open YCP_GSHADOW_SYSTEM, "> $gshadow_system";
    print YCP_GSHADOW_SYSTEM "\$[\n";
    
    foreach (values %groupmap)
    {
        ($groupname, $pass, $gid, $userlist, $more_users) = split (/:/,$_);
    
        my $group_type = "local";
        $YCP_GROUP = YCP_GROUP_LOCAL;
    #    $YCP_GROUP_ITEMLIST = YCP_GROUP_ITEMLIST_LOCAL;
        $YCP_GSHADOW = YCP_GSHADOW_LOCAL;
        if ($gid <= $max_system_gid || $groupname eq "nobody" ||
            $groupname eq "nogroup" )
        {
            $group_type = "system";
            $YCP_GROUP = YCP_GROUP_SYSTEM;
    #        $YCP_GROUP_ITEMLIST = YCP_GROUP_ITEMLIST_SYSTEM;
            $YCP_GSHADOW = YCP_GSHADOW_SYSTEM;
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
    
        print YCP_GROUP_BYNAME "\t\"$groupname\": \$[\n";
        print YCP_GROUP_BYNAME "\t\t\"groupname\": \"$groupname\",\n";
        print YCP_GROUP_BYNAME "\t\t\"pass\": \"$pass\",\n";
        print YCP_GROUP_BYNAME "\t\t\"gid\": $gid,\n";
        print YCP_GROUP_BYNAME "\t\t\"userlist\": \"$userlist\",\n";
        print YCP_GROUP_BYNAME "\t\t\"more_users\": \"$more_users\",\n";
        print YCP_GROUP_BYNAME "\t\t\"type\": `$group_type\n";
        print YCP_GROUP_BYNAME "\t],\n";
               
        if (defined  $groupnamelists{$group_type})
        {
            $groupnamelists{$group_type} .= ", \"$groupname\"";
        }
        else
        {
            $groupnamelists{$group_type} = "\"$groupname\"";
        }
        
        print YCP_GIDLIST " $gid,";
    
    #    $all_users = $userlist;
    #    if ($userlist ne "" && $more_users ne "")
    #    {
    #       $all_users .= ",";
    #    }
    #    $all_users .= $more_users;  
    #    print $YCP_GROUP_ITEMLIST "\t`item(`id($gid), \"$groupname\", ".
    #            "\"$gid\", \"$all_users\"),\n";
    }
    
    print YCP_GROUP_LOCAL "]\n";
    print YCP_GROUP_SYSTEM "]\n";
    print YCP_GROUP_BYNAME "]\n";
    #print YCP_GROUP_ITEMLIST_SYSTEM "[\n";
    #print YCP_GROUP_ITEMLIST_LOCAL "[\n";
    
    print YCP_GIDLIST "]\n";
    close YCP_GIDLIST;
    
    close YCP_GROUP_LOCAL;
    close YCP_GROUP_SYSTEM;
    close YCP_GROUP_BYNAME;
    #close YCP_GROUP_ITEMLIST_SYSTEM;
    #close YCP_GROUP_ITEMLIST_LOCAL;
    
    print YCP_GSHADOW_LOCAL "]\n";
    close YCP_GSHADOW_LOCAL;
    print YCP_GSHADOW_SYSTEM "]\n";
    close YCP_GSHADOW_SYSTEM;
    
    
    open YCP_GROUPNAMES, "> $groupnamelist_file";
    print YCP_GROUPNAMES "\$[\n";
    print YCP_GROUPNAMES "\t`system: [ ".$groupnamelists{"system"}." ],\n";
    print YCP_GROUPNAMES "\t`local: [ ".$groupnamelists{"local"}." ],\n";
    print YCP_GROUPNAMES "]\n";
    close YCP_GROUPNAMES;
     
}


#############################################
#############################################
sub read_nis ()
{
# load and correct the default group ... ???

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

    foreach $user (@ypcat)
    {
        my ($username, $password, $uid, $gid, $full, $home, $shell)
            = split(/:/,$user);
        chomp $shell;

        print YCP_NIS_UIDLIST " $uid,";

        my $groupname = "";
#        if (defined $groupmap{$gid})
#        {
#            my $default_group = $groupmap{$gid};
#            my @default_group_as_list = split (/:/,$default_group);
#            $groupname = $default_group_as_list[0];
#    
#            # modify group's userlist
#            if (substr ($default_group, length($default_group) - 1, 1) eq ":")
#            {
#                $groupmap{$gid} = $default_group.$username;
#            }
#            else
#            {
#                $groupmap{$gid} = $default_group.",$username";
#            }
#        }
#
#        # add the grouplist
        my $grouplist = "";
#        if (defined $users_groups{$username})
#        {
#            $grouplist = $users_groups{$username};
#        }
#
        print YCP_NIS_HOMES " \"$home\",";
        print YCP_NIS_USERNAMES " \"$username\",";

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

        print YCP_NIS_ITEMLIST "\t`item(`id($uid), \"$username\", ".
            "\"$full\", \"$uid\", \"$all_groups\"),\n";
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
}

#############################################
#############################################
sub read_ldap()
{
    $host = $ARGV[5]; # is it possible here?
    $base = $ARGV[6];
     
    open YCP_LDAP, "> $ldap_output";
    open YCP_LDAP_BYNAME, "> $ldap_byname_output";
    open YCP_LDAP_UIDLIST, "> $uidlist_ldap";
    
    open YCP_LDAP_USERNAMES, "> $usernamelist_ldap";
    print YCP_LDAP_USERNAMES "[\n";
    
    open YCP_LDAP_HOMES, "> $homelist_ldap";
    print YCP_LDAP_HOMES "[\n";
    
    open YCP_LDAP_ITEMLIST, "> $ldap_itemlist";
    print YCP_LDAP_ITEMLIST "[\n";
    
    print YCP_LDAP "\$[\n";
    print YCP_LDAP_BYNAME "\$[\n";
    print YCP_LDAP_UIDLIST "[\n";

    use Net::LDAP; # could it be here ?
    
    $ldap = Net::LDAP->new($host);

    $ldap->bind ; # database must allow anonymous binds...

    $mesg = $ldap->search(
         base => $base,
         filter => "objectclass=posixGroup",
         attrs => [ "cn", "gidNumber" ] );
    
    %groups = ();
    
    foreach $entry ($mesg->all_entries)
    { 
        $groups{$entry->get_value("gidNumber")} = $entry->get_value("cn");
    }
    
    $mesg = $ldap->search(
         base => $base,
         filter => "objectclass=posixAccount",
         attrs => [ "uid", "uidNumber", "gidNumber", "homeDirectory",
                    "loginShell", "cn" ]);
     
    foreach $entry ($mesg->all_entries)
    { 
        my $uid = $entry->get_value("uidNumber");
        print YCP_LDAP "$uid:\t\$[\n";
           
        my $username = $entry->get_value("uid");
        print YCP_LDAP "\t\"username\": \"$username\",\n";
        
        print YCP_LDAP "\t\"uid\": $uid,\n";
        
        my $gid = $entry->get_value("gidNumber");
        print YCP_LDAP "\t\"gid\": $gid,\n";
        
        print YCP_LDAP "\t\"groupname\": \"$groups{$gid}\",\n";
        print YCP_LDAP "\t\"grouplist\": \"\",\n";
 
        my $fullname = $entry->get_value("cn");
        print YCP_LDAP "\t\"fullname\": \"$fullname\",\n";
        
#        my $surname = $entry->get_value("sn");
#        print YCP_LDAP "\t\"surname\": \"$surname\",\n";
#        
#        my $forename = $entry->get_value("givenname");
#        print YCP_LDAP "\t\"forename\": \"$forename\",\n";
        
        my $home = $entry->get_value("homeDirectory");
        print YCP_LDAP "\t\"home\": \"$home\",\n";
        
    #    print YCP_LDAP "\t\"org_home\": \"$home\",\n";
    
        my $shell = $entry->get_value("loginShell");
        print YCP_LDAP "\t\"shell\": \"$shell\",\n";

        print YCP_LDAP "\t\"type\": `ldap\n";
            
        print YCP_LDAP "\t],\n";
    
        print YCP_LDAP_BYNAME "\t\"$username\" : $uid,\n";
        print YCP_LDAP_UIDLIST "$uid, ";
        print YCP_LDAP_USERNAMES "\"$username\", ";
        print YCP_LDAP_HOMES "\"$home\", ";
        print YCP_LDAP_ITEMLIST "\t`item(`id($uid), \"$username\", ".
            "\"$fullname\", \"$uid\", \"$groups{$gid}\"),\n";
    }
    
    $ldap->unbind;          

    print YCP_LDAP "]";
    print YCP_LDAP_BYNAME "]\n";
    print YCP_LDAP_UIDLIST "\n]";
    print YCP_LDAP_HOMES "\n]";
    print YCP_LDAP_USERNAMES "\n]";
    print YCP_LDAP_ITEMLIST "]\n";
            
    close YCP_LDAP_BYNAME;
    close YCP_LDAP_UIDLIST;
    close YCP_LDAP_HOMES;
    close YCP_LDAP_USERNAMES;
    close YCP_LDAP_ITEMLIST;
    close YCP_LDAP;
}

############################################# main

if ($user_type eq "passwd")
{
    read_local();
}
if ($user_type eq "nis")
{
    read_nis();
}
if ($user_type eq "ldap")
{
    read_ldap();
}
