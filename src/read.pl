#!/usr/bin/perl -w

open GROUP, "< /etc/group";
@groups = <GROUP>;
close GROUP;

$gsize = @groups;
$i = 0;

%groupmap = ();
%passwdmap = ();
%nismap = ();

# hash with the form: user => group1,group2
%users_groups = ();

$last_group = "";
$last_passwd = "";

while ($i < $gsize)
{
    my $group = $groups[$i];
    
    # change last "\n" to ":"
    substr($group, length($group) - 1, 1, ":");

    (my $groupname, my $pass, my $gid, my $users) = split (/:/,$group);

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

    if ($groupname eq "+")
    {
        $last_group = $group;
    }
    else
    {
        $groupmap{$gid} = $group;
    }

    $i = $i + 1;
}

open PASSWD, "< /etc/passwd";
@passwd = <PASSWD>;
close PASSWD;

$psize = @passwd;
$i = 0;

while ($i < $psize)
{
    my $user = $passwd[$i];
    my @userlist = split (/:/,$user);
    my $username = $userlist[0];
    if ($username eq "+")
    {
        $last_passwd = $user;
    }
    else
    {
        my $uid = $userlist[2];
        my $gid = $userlist[3];
        my $default_group = $groupmap{$gid};
        my @default_group_as_list = split (/:/,$default_group);
        my $groupname = $default_group_as_list[0];

        # modify group's userlist
        if (substr ($default_group, length($default_group) - 1, 1) eq ":")
        {
            $groupmap{$gid} = $default_group.$username;
        }
        else
        {
            $groupmap{$gid} = $default_group.",$username";
        }

        # add the name of default group (and remove last "\n")
        substr($user, length($user) - 1, 1 + length ($groupname),":$groupname");
        
        # add the grouplist
        if (defined $users_groups{$username})
        {
            $user = $user.":$users_groups{$username}";
        }
        else
        {
            $user = $user.":";
        }

        $passwdmap{$uid} = $user;

        # YCP map could be generated...
    }

    $i = $i + 1;
}

@getent = `getent passwd`;

$gsize = @getent;
$i = 0;

while ($i < $gsize)
{
    my $user = $getent[$i];
    my @userlist = split (/:/,$user);
    my $username = $userlist[0];
    my $uid = $userlist[2];

    if (!defined $passwdmap{$uid})
    {
        $gid = $userlist[3];
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
        # add the name of default group (and remove last "\n")
        substr($user, length($user) - 1, 2 + length ($groupname),":$groupname:");
        
        # add the grouplist
        if (defined $users_groups{$username})
        {
            $user = $user.$users_groups{$username};
        }

        $nismap{$uid} = $user;
    }
    $i = $i + 1;
}

#foreach 
open NEWGROUP, "> /tmp/newgroup";
while ( ($gid, $gr) = each %groupmap)
{
#    print "groupmap: $gid -> $gr\n";
    print NEWGROUP  "$gr\n";
}
if ($last_group ne "")
{
    print NEWGROUP "$last_group\n";
}
close NEWGROUP;

open NEWPASSWD, "> /tmp/newpasswd";
while ( ($uid, $u) = each %passwdmap)
{
    print NEWPASSWD  "$u\n";
}
if ($last_passwd ne "")
{
    print NEWPASSWD "$last_passwd\n";
}
close NEWPASSWD;

open NEWNIS, "> /tmp/newnis";
while ( ($uid, $u) = each %nismap)
{
    print NEWNIS  "$u\n";
}
close NEWNIS;


#    %groupmap{$gid} = ( name => $groupname );
#    @groupmap{$gid} = (substr($group, 0, length($group) - 2), "none");

#    ($group, $more_users) = @groupmap{$gid};
#print "default group of user $username is $default_group\n";
#            $groupmap{$gid} = sprintf ("%s%s", $default_group, $username);

