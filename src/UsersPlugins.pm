#! /usr/bin/perl -w
#
# This module handles povides an interface to all installed plugins defined
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
	YaST::YCP::Import ($module);
	# we could use 'eval (use $module)'
	my $func        = $module."::Interface";
	my @list 	= &$func ();
	if (@list) {
	    foreach my $action (@list) {
		$plugins{$module}{$action}	= 1;
	    }
	}
    }
}
 
##------------------------------------
# apply the action passwed as argument to all plugins
# actions: Edit/Write/Verify etc.
BEGIN { $TYPEINFO{Apply} = ["function", "boolean", "string", "any"]; }
sub Apply {

    my $action	= $_[0];
    my $param	= $_[1];

    y2milestone ("action to call: $action");

    foreach my $module (@available_plugins) {

	if (!defined $plugins{$module}{$action}) { next; }
		
	my $func	= $module."::$action";
	&$func ($param);
    }
    return 1;
}

##------------------------------------
# get the data from plugins
# actions: Summary/GUIClient etc.
BEGIN { $TYPEINFO{Get} = ["function", ["list", "string"], "string"]; }
sub Get {

    my $action  = $_[0];
    my @ret	= ();

    y2milestone ("action to call: $action");

    foreach my $module (@available_plugins) {

	if (!defined $plugins{$module}{$action}) { next; }
		
	my $func	= $module."::$action";
	push @ret, &$func ();
    }

    return @ret;
}

1
# EOF
