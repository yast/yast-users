#!/usr/bin/perl -w
#
#  File:
#       build_ldap_structures.pl
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
#   build_ldap.structures.pl output_directory encoding ldap server_adress base
#
#  Example:
#   build_ldap_structures.pl /tmp iso-8859-2 ldap 10.20.3.130 dc=suse,dc=cz
#
#

# LDAP library
use Net::LDAP;

# for encoding the fullnames
use Encode 'from_to';

# the input parameters:

$output_dir     = $ARGV[0];
$encod          = $ARGV[1];
$user_type      = $ARGV[2]; # not necessary, used to differ from YaST
$host           = $ARGV[3];
$base           = $ARGV[4];

$ldap_output                    = $output_dir."/ldap.ycp";
$ldap_byname_output             = $output_dir."/ldap_byname.ycp";

$usernamelist_ldap  = $output_dir."/usernamelist_ldap.ycp";
$homelist_ldap      = $output_dir."/homelist_ldap.ycp";
$ldap_itemlist      = $output_dir."/itemlist_ldap.ycp";
$uidlist_ldap       = $output_dir."/uidlist_ldap.ycp";

$last_ldap      =   $output_dir."/last_ldap_uid.ycp";

$group_ldap          = $output_dir."/group_ldap.ycp";
$group_ldap_byname   = $output_dir."/group_ldap_byname.ycp";
$group_ldap_itemlist = $output_dir."/group_ldap_itemlist.ycp";
$gidlist_ldap        = $output_dir."/gidlist_ldap.ycp";
$groupnamelist_ldap  = $output_dir."/groupnamelist_ldap.ycp";


# hash with the form: user => group1,group2
#%users_groups = ();

$last_ldap_uid = 1;

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

#%corrected_groups = ();

$ldap = Net::LDAP->new($host) or die;

$ldap->bind ; # database must allow anonymous binds...

$mesg = $ldap->search(
     base => $base,
     filter => "objectclass=posixGroup",
     attrs => [ "cn", "gidNumber" ] );

%groups = ();

# all ldap groups
foreach $entry ($mesg->all_entries)
{ 
    $groups{$entry->get_value("gidNumber")} = $entry->get_value("cn");
# get the userlist and save it to users_groups...
}

# this should be configurable...
$mesg = $ldap->search(
     base => $base,
     filter => "objectclass=posixAccount",
     attrs => [ "uid", "uidNumber", "gidNumber", "homeDirectory",
                "loginShell", "cn" ]);

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
#        print YCP_LDAP "\t\"grouplist\": \"\",\n";

    my $fullname = $entry->get_value("cn");
    # recode the fullname to utf
    from_to($fullname, $encod, "utf-8");
    print YCP_LDAP "\t\"fullname\": \"$fullname\",\n";
    
#        my $surname = $entry->get_value("sn");
#        print YCP_LDAP "\t\"surname\": \"$surname\",\n";
#        
#        my $forename = $entry->get_value("givenname");
#        print YCP_LDAP "\t\"forename\": \"$forename\",\n";
    
    my $home = $entry->get_value("homeDirectory");
    print YCP_LDAP "\t\"home\": \"$home\",\n";
    
    my $shell = $entry->get_value("loginShell");
    print YCP_LDAP "\t\"shell\": \"$shell\",\n";

    print YCP_LDAP "\t\"type\": `ldap\n";
        
    print YCP_LDAP "\t],\n";

    print YCP_LDAP_BYNAME "\t\"$username\" : $uid,\n";
    print YCP_LDAP_UIDLIST "$uid, ";
    print YCP_LDAP_USERNAMES "\"$username\", ";
    print YCP_LDAP_HOMES "\"$home\", ";
    
    $uid_wide = addBlanks ($uid);
    print YCP_LDAP_ITEMLIST "\t`item(`id($uid), \"$username\", ".
        "\"$fullname\", \"$uid_wide\", \"$groups{$gid}\"),\n";

    if ($last_ldap_uid < $uid)
    {
        $last_ldap_uid = $uid;
    }

#    if (defined ($corrected_groups{$gid}))
#    {
#        $corrected_groups{$gid} .= ",$username";
#    }
#    else
#    {
#        $corrected_groups{$gid} = "$username";
#    }
#
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

open MAX_LDAP_UID, "> $last_ldap";
print MAX_LDAP_UID "$last_ldap_uid";
close MAX_LDAP_UID;

#open CORRECT, "> $groups_corrected";
#print CORRECT "\$[\n";
#foreach $gid (keys %corrected_groups)
#{
#    print CORRECT "\t$gid : \"$corrected_groups{$gid}\",\n";
#}
#print CORRECT "]\n";
#close CORRECT;

#-------------------------

open YCP_LDAPGROUP, "> $group_ldap";
open YCP_LDAPGROUP_BYNAME, "> $group_ldap_byname";
open YCP_LDAPGROUP_ITEMLIST, "> $group_ldap_itemlist";
open YCP_LDAPGIDLIST, "> $gidlist_ldap";
open YCP_LDAPGROUPNAMELIST, "> $groupnamelist_ldap";

print YCP_LDAPGIDLIST "[\n";
print YCP_LDAPGROUPNAMELIST "[\n";
print YCP_LDAPGROUP "\$[\n";
print YCP_LDAPGROUP_BYNAME "\$[\n";
print YCP_LDAPGROUP_ITEMLIST "[\n";

foreach my $gid (keys %groups)
{
#    my ($groupname, $pass, $gid, $userlist) = split (/:/,$_);
    
    my $groupname = $groups{$gid};

# I don't know how to get userlist...
    my $userlist = "";
    
    if (defined $more_usersmap{$gid}) {
        $more_users = $more_usersmap{$gid};
    }
    else {
        $more_users = "";
    }

    my $group_type = "ldap";
    
    print YCP_LDAPGROUP "\t$gid: \$[\n";
    print YCP_LDAPGROUP "\t\t\"groupname\": \"$groupname\",\n";
#    print YCP_LDAPGROUP "\t\t\"pass\": \"$pass\",\n";
    print YCP_LDAPGROUP "\t\t\"gid\": $gid,\n";
#    print YCP_LDAPGROUP "\t\t\"userlist\": \"$userlist\",\n";
    print YCP_LDAPGROUP "\t\t\"more_users\": \"$more_users\",\n";
    print YCP_LDAPGROUP "\t\t\"type\": `$group_type\n";
    print YCP_LDAPGROUP "\t],\n";

    print YCP_LDAPGROUP_BYNAME "\t\"$groupname\": \$[\n";
    print YCP_LDAPGROUP_BYNAME "\t\t\"groupname\": \"$groupname\",\n";
#    print YCP_LDAPGROUP_BYNAME "\t\t\"pass\": \"$pass\",\n";
    print YCP_LDAPGROUP_BYNAME "\t\t\"gid\": $gid,\n";
#    print YCP_LDAPGROUP_BYNAME "\t\t\"userlist\": \"$userlist\",\n";
    print YCP_LDAPGROUP_BYNAME "\t\t\"more_users\": \"$more_users\",\n";
    print YCP_LDAPGROUP_BYNAME "\t\t\"type\": `$group_type\n";
    print YCP_LDAPGROUP_BYNAME "\t],\n";
           
    print YCP_LDAPGROUPNAMELIST "\"$groupname\",";
    
    print YCP_LDAPGIDLIST " $gid,";

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
    print YCP_LDAPGROUP_ITEMLIST "\t`item(`id($gid), \"$groupname\", ".
            "\"$gid_wide\", \"$all_users\"),\n";

}

print YCP_LDAPGROUP_BYNAME "]\n";
print YCP_LDAPGROUP_ITEMLIST "]\n";
print YCP_LDAPGIDLIST "]\n";
print YCP_LDAPGROUPNAMELIST "]\n";
print YCP_LDAPGROUP "]\n";

close YCP_LDAPGIDLIST;
close YCP_LDAPGROUPNAMELIST;
close YCP_LDAPGROUP_BYNAME;
close YCP_LDAPGROUP_ITEMLIST;
close YCP_LDAPGROUP;

