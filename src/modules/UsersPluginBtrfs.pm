#! /usr/bin/perl -w
#
# This is the API part of UsersPluginBtrfs plugin 
# Main task is handle home directories as btrfs subvolumes
# (see fate#316134)
#

package UsersPluginBtrfs;

use strict;

use ycp;
use YaST::YCP;
use YaPI;

our %TYPEINFO;


use Data::Dumper;

textdomain("users");

##--------------------------------------
##--------------------- global imports

YaST::YCP::Import ("FileUtils");
YaST::YCP::Import ("Package");
YaST::YCP::Import ("SCR");

##--------------------------------------
##--------------------- global variables

# error message, returned when some plugin function fails
my $error       = "";

my $pluginName = "UsersPluginBtrfs"; 

my $skel        = "";
 
##--------------------------------------

# All functions have 2 "any" parameters: this will probably mean
# 1st: configuration map (hash) - e.g. saying if we work with user or group
# 2nd: data map (hash) of user (group) to work with

# in 'config' map there is a info of this type:
# "what"		=> "user" / "group"
# "modified"		=> "added"/"edited"/"deleted"

# 'data' map contains the atrtributes of the user. It could also contain
# some keys, which Users module uses internaly (like 'groupname' for name of
# user's default group). Just ignore these values
    
##------------------------------------


# return names of provided functions
BEGIN { $TYPEINFO{Interface} = ["function", ["list", "string"], "any", "any"];}
sub Interface {

    my $self		= shift;
    my @interface 	= (
	    "Restriction",
	    "WriteBefore",
	    "Write",
	    "Add",
	    "AddBefore",
	    "Edit",
	    "EditBefore",
	    "Interface",
	    "PluginPresent",
	    "Error"
    );
    return \@interface;
}

# return error message, generated by plugin
BEGIN { $TYPEINFO{Error} = ["function", "string", "any", "any"];}
sub Error {
    
    my $self = shift;
    my $ret  = $error;
    $error   = "";
    return     $ret;
}


##------------------------------------
# Type of users and groups this plugin is restricted to.
# If this function doesn't exist, plugin is applied for all user (group) types.
BEGIN { $TYPEINFO{Restriction} = ["function", ["map", "string", "any"], "any", "any"];}
sub Restriction {

    my $self	= shift;
    # just a basic check first, if the plugin could be used
    my $supported       = Package->Installed("yast2-snapper") && fs_is_btrfs ("/");

    # read skel now, so we do not have to import Users
    my $command = "grep -i skel /etc/default/useradd | sed s/SKEL=//";
    my $out     = SCR->Execute (".target.bash_output", $command);
    $skel       = $out->{"stdout"} || "";
    chomp $skel;

    return {
      # this plugin applies only for users
      "user"    => $supported,
      # local, or remote with local home directories
      "local"   => $supported,
      "ldap"    => $supported
    };
}

# checks the current data map of user/group (2nd parameter) and returns
# true if given user (group) has our plugin
BEGIN { $TYPEINFO{PluginPresent} = ["function", "boolean", "any", "any"];}
sub PluginPresent {
    my $self	  = shift;
    my $config    = shift;
    my $data      = shift;

    y2debug ("AddBefore Btrfs called");
    return 1 unless %$data; # for AddBefore, PluginPresent called with empty hash

    my $home    = $data->{"homeDirectory"} || "";
    return 0 unless $home;

    # Plugin can be used if user's home directory should be in btrfs file system
    my $home_path = substr ($home, 0, rindex ($home, "/"));
    return fs_is_btrfs($home_path);
}


# this will be called at the beggining of Users::AddUser/AddGroup
# Check if it is possible to add this plugin here.
# (Could be called multiple times for one user/group)
BEGIN { $TYPEINFO{AddBefore} = ["function",
    ["map", "string", "any"],
    "any", "any"];
}
sub AddBefore {

    my ($self, $config, $data)  = @_;
    return $data;
}

# This will be called just after Users::Add - the data map probably contains
# the values which we could use to create new ones
# Could be called multiple times for one user/group!
BEGIN { $TYPEINFO{Add} = ["function", ["map", "string", "any"], "any", "any"];}
sub Add {

    my $self   = shift;
    my $config = shift;
    my $data   = shift;

    y2debug ("Add Btrfs called");

    # forbid standard manipulations with home directory
    $data->{"create_home"}      = YaST::YCP::Boolean (0);
    $data->{"chown_home"}       = YaST::YCP::Boolean (0);

    return $data;
}

# This will be called at the beggining of Users::EditUser/EditGroup
# Check if it is possible to add this plugin here.
# (Could be called multiple times for one user/group)
BEGIN { $TYPEINFO{EditBefore} = ["function",
    ["map", "string", "any"],
    "any", "any"];
}
sub EditBefore {

    my ($self, $config, $data)  = @_;
    return $data;
}


# this will be called just after Users::Edit
BEGIN { $TYPEINFO{Edit} = ["function", ["map", "string", "any"], "any", "any"]; }
sub Edit {

    my $self   = shift;
    my $config = shift;
    my $data   = shift;

    y2debug ("Edit Btrfs called");

    # moving subvolumes is not supported: proceed as with normal user
    if (($data->{"what"} || "") eq "edit_user") {
      return $data;
    }

    # forbid standard manipulations with home directory
    $data->{"create_home"}      = YaST::YCP::Boolean (0);
    $data->{"chown_home"}       = YaST::YCP::Boolean (0);

    return $data;
}

# what should be done before user is finally written
# Must be called before Users module tries to rm -rf home directory
BEGIN { $TYPEINFO{WriteBefore} = ["function", "boolean", "any", "any"];}
sub WriteBefore {

    my $self    = shift;
    my $config  = shift;
    my $user    = shift;

    y2debug ("WriteBefore Btrfs called");

    my $user_mod        = $config->{"modified"} || "no";
    my $home            = $user->{"homeDirectory"} || "";
    my $username        = $user->{"uid"} || "";

    if ($user_mod eq "deleted") {
        unless (SCR->Read (".snapper.is_subvolume", $home)) {
          y2milestone ("directory $home does not look like subvolume");
          return 1;
        }

        unless (SCR->Execute(".snapper.delete_config", { "config_name" => "home_$username"})) {
          y2error ("deleting config $username failed");
          return 0;
        }

        unless (SCR->Execute(".snapper.subvolume.delete", { "path" => $home })) {
          y2error ("deleting subvolume $home failed");
          return 0;
        }
    }
    return 1;
}

# In general: what should be done after user is finally written (e.g. to /etc/passwd)
# Now is the time to handle the directories a special way.
BEGIN { $TYPEINFO{Write} = ["function", "boolean", "any", "any"];}
sub Write {

    my $self    = shift;
    my $config  = shift;
    my $user    = shift;

    y2debug ("Write Btrfs called");

    # re-check that /home is using btrfs
    return 1 unless $self->PluginPresent($config,$user);

    my $user_mod        = $config->{"modified"} || "no";

    my $home            = $user->{"homeDirectory"} || "";
    my $username        = $user->{"uid"} || "";
    my $uid             = $user->{"uidNumber"} || 0;
    my $gid             = $user->{"gidNumber"};

    if ($user_mod eq "imported" || $user_mod eq "added") {

        # no creating/copying if home alredy exists
        if (FileUtils->Exists($home)) {
          y2milestone ("home directory already exists, only chown-ing");
        }
        else {

          # create a subvolume
          unless (SCR->Execute(".snapper.subvolume.create", { "path" => $home })) {
            y2error ("creating subvolume $home failed");
	    # error popup, %1 is name
	    $error	= sformat (__("Creating subvolume \"%1\" failed."), $home);
          }

          # create new config
          unless (SCR->Execute(".snapper.create_config", {
            "config_name"       => "home_$username",
            "subvolume"         => $home,
            "fstype"            => "btrfs"
          })) {
            y2error ("creating config $username failed");
	    # error popup, %1 is name
	    $error	= sformat (__("Creating snapper configuration \"%1\" failed."), $username);
          }
          # adapt ALLOW_USERS (there should be a .snapper call for that...)
          my $command   = "/bin/cp -r '$skel/.' '$home/'";
          SCR->Execute (".target.bash",
            "sed -i -e '/ALLOW_USERS=/ s/\".*\"/\"$username\"/' /etc/snapper/configs/home_$username");


          if ($skel ne "" && FileUtils->Exists($skel)) {
            my $command   = "/bin/cp -r $skel/. '$home/'";
            my $out       = SCR->Execute (".target.bash_output", $command);
            if (($out->{"stderr"} || "") ne "") {
              y2error ("error calling $command: ", $out->{"stderr"} || "");
              return 0;
            }
          }
        }

        # chown all but .snapshots:
        # it would fail on .snapshots if there is already anything inside
        my $out = SCR->Execute (".target.bash_output", "ls -A1 '$home'");
        foreach my $file (split (/\n/,$out->{"stdout"} || "")) {
          unless ($file eq ".snapshots") {
            my $command = "/bin/chown -R $uid:$gid '$home/$file'";
            my $chown   = SCR->Execute (".target.bash_output", $command);
            if (($chown->{"stderr"} || "") ne "") {
              y2error ("error calling $command: ", $out->{"stderr"} || "");
              return 0;
            }
          }
        };

        # owner of .snapshots subdirectory must be root
        my $command = "/bin/chown root:$gid '$home/.snapshots'";
        $out	= SCR->Execute (".target.bash_output", $command);
        if (($out->{"stderr"} || "") ne "") {
          y2error ("error calling $command: ", $out->{"stderr"} || "");
          return 0;
        }
    }
    return 1;
}

#---------------------Helper Soubroutines---------------------------------------------
sub contains {
    my ( $list, $key, $ignorecase ) = @_;
    if ( $ignorecase ) {
        if ( grep /^$key$/i, @{$list} ) {
            return 1;
        }
    } else {
        if ( grep /^$key$/, @{$list} ) {
            return 1;
        }
    }
    return 0;
}

# return true of filesystem used for given path is btrfs
sub fs_is_btrfs {

    my $path    = shift;
    return (0 eq SCR->Execute (".target.bash", "df --type=btrfs $path"));
}

1
# EOF
