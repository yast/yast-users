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
$user_type      = $ARGV[2]; # not necessary
$host           = $ARGV[3];
$base           = $ARGV[4];

$groups_corrected               = $output_dir."/group_correct.ycp";

$ldap_output                    = $output_dir."/ldap.ycp";
$ldap_byname_output             = $output_dir."/ldap_byname.ycp";

$usernamelist_ldap  = $output_dir."/usernamelist_ldap.ycp";

$homelist_ldap      = $output_dir."/homelist_ldap.ycp";

$ldap_itemlist                   = $output_dir."/itemlist_ldap.ycp";

$uidlist_ldap       = $output_dir."/uidlist_ldap.ycp";

$last_ldap      =   $output_dir."/last_ldap_uid.ycp";

# hash with the form: user => group1,group2
%users_groups = ();

%groupmap = ();
%shadowmap = ();
%gshadowmap = ();

%groupnamelists = ();

$last_ldap_uid = 1;


$the_answer = 42; # ;-)

%corrected_groups = ();

$ldap = Net::LDAP->new($host) or die;

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
    print YCP_LDAP_ITEMLIST "\t`item(`id($uid), \"$username\", ".
        "\"$fullname\", \"$uid\", \"$groups{$gid}\"),\n";

    if ($last_ldap_uid < $uid)
    {
        $last_ldap_uid = $uid;
    }

    if (defined ($corrected_groups{$gid}))
    {
        $corrected_groups{$gid} .= ",$username";
    }
    else
    {
        $corrected_groups{$gid} = "$username";
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

open CORRECT, "> $groups_corrected";
print CORRECT "\$[\n";
foreach $gid (keys %corrected_groups)
{
    print CORRECT "\t$gid : \"$corrected_groups{$gid}\",\n";
}
print CORRECT "]\n";
close CORRECT;
