#! /usr/bin/perl -w
#
# This module povides an interface to all installed plugins defined
# for Users/Groups management
#

package UsersPlugins;

use strict;

use ycp;
use YaST::YCP;

our %TYPEINFO;

no strict 'refs';	# this will allow us to call plugins

my @available_plugins	= ();

my %plugins		= ();

##------------------------------------
##------------------- global imports
YaST::YCP::Import ("Directory");
YaST::YCP::Import ("SCR");
##------------------------------------

##------------------------------------
# read and import all plugins
# + initialize the hash of plugin interface
BEGIN { $TYPEINFO{Read} = ["function", "boolean"]; }
sub Read {

    my $find = "/usr/bin/find ".Directory::moduledir();
    $find .= " -name UsersPlugin*.*"; #TODO use some variable for the name
    my $out     = SCR::Execute (".target.bash_output", $find);
    my $modules = $out->{"stdout"} || "";

    foreach my $module (split (/\n/, $modules)) {
	my @mod = split (/\//, $module);
	my $m = $mod[-1] || "";
	$m =~ s/\.ycp$//g;	# YCP modules cannot be called as variables...
	$m =~ s/\.pm$//g;
	if ($m ne "" && $m ne "UsersPlugins") {
	    push @available_plugins, $m;
	}
    }
    
    foreach my $module (@available_plugins) {
	YaST::YCP::Import ($module); # we could use 'eval (use $module)'
	my $func        = $module."::Interface";
	my $list 	= &$func ({}, {});
	if (defined $list && ref ($list) eq "ARRAY") {
	    # save the plugins interface
	    foreach my $action (@{$list}) {
		$plugins{$module}{$action}	= 1;
		# save the plugin restrictions
		if ($action eq "Restriction") {
		    $func       = $module."::$action";
		    $plugins{$module}{$action}	= &$func ({}, {});
		}
	    }
	}
    }
}
 
##------------------------------------
# Apply the given action (passed as argument) to all plugins
BEGIN { $TYPEINFO{Apply} = ["function",
    # return value: hash, keys are plugin names, values are return values of
    # called functions
    ["map", "string", "any"],
    # 1st parameter: name of function to call from plugins
     "string",
    # 2nd parameter: config parameter of a function to call
     "any",
    # 3rd parameter: data parameter of a function to call
     "any"];
}
sub Apply {

    my $action	= $_[0];
    my $config	= $_[1];
    my $data	= $_[2];
    my %ret	= ();

    y2milestone ("action to call on plugins: $action");

    my $type	= "";
    if (defined $data && ref ($data) eq "HASH" && defined $data->{"type"}) {
	$type	= $data->{"type"};
    }

    foreach my $module (@available_plugins) {

	# check if plugin has this function defined
	if (!defined $plugins{$module}{$action}) {
	    next;
	}

	# check if plugin function is allowed for current user/group type
	if (defined $plugins{$module}{"Restriction"} 		&&
	    ref ($plugins{$module}{"Restriction"}) eq "HASH" 	&&
	    %{$plugins{$module}{"Restriction"}} 		&&
	    !defined $plugins{$module}{"Restriction"}{$type}) {

	    y2debug ("plugin '$module' not defined for entry type '$type'");
	    next;
	# FIXME look also to LDAP Template for allowed plugins
	}
		
	my $func	= $module."::$action";
	$ret{$module}	= &$func ($config, $data);
    }
    return \%ret;
}


1
# EOF
