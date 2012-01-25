#! /usr/bin/perl -w
# ------------------------------------------------------------------------------
# Copyright (c) 2006-2012 Novell, Inc. All Rights Reserved.
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------
#

#
# This module povides an interface to all installed plugins defined
# for Users/Groups management
#

package UsersPlugins;

use strict;

use YaST::YCP qw(:LOGGING);

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

    opendir (MODULEDIR, Directory->moduledir()) || do {
	y2error ("Cannot open directory '".Directory->moduledir()."'");
	return 0;
    };
    foreach my $module (readdir(MODULEDIR)) {
	if ($module =~ s/^(UsersPlugin.+)\..+$/$1/ &&
	    $module ne 'UsersPlugins') {
	    push @available_plugins, $module;
	}
    };
    close (MODULEDIR);
    
    foreach my $module (@available_plugins) {
	y2milestone ("Available plugin: $module");
	YaST::YCP::Import ($module); # we could use 'eval (use $module)'
	my $func        = $module."::Interface";
	my $list 	= &$func ($module, {}, {});
	if (defined $list && ref ($list) eq "ARRAY") {
	    # save the plugins interface
	    foreach my $action (@{$list}) {
		$plugins{$module}{$action}	= 1;
		# save the plugin restrictions
		if ($action eq "Restriction") {
		    $func       = $module."::$action";
		    $plugins{$module}{$action}	= &$func ($module, {}, {});
		}
		# save the plugin internal keys
		if ($action eq "InternalAttributes") {
		    $func       = $module."::$action";
		    $plugins{$module}{$action}	= &$func ($module, {}, {});
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

    my $self	= shift;
    my $action	= $_[0];
    my $config	= $_[1];
    my $data	= $_[2];
    my %ret	= ();

    my $type	= "";
    if (defined $config->{"type"}) {
	$type	= $config->{"type"};
    }

    my $what	= "user";
    if (defined $config->{"what"}) {
	$what	= $config->{"what"};
    }

    my @plugins_to_call	= @available_plugins;

    # Apply only for selected plugins; if not present, apply for all
    if (defined $config->{"plugins"} && ref ($config->{"plugins"}) eq "ARRAY") {
	@plugins_to_call	= @{$config->{"plugins"}};
    }

    foreach my $module (@plugins_to_call) {

	# check if plugin has this function defined
	if (!defined $plugins{$module}{$action}) {
	    y2debug ("function $action not defined for plugin $module");
	    next;
	}

	if ($action eq "InternalAttributes") {
	    $ret{$module}	= $plugins{$module}{$action};
	    next;
	}

	y2debug ("action to call on plugins: $action");

	if (defined $plugins{$module}{"Restriction"} 		&&
	    ref ($plugins{$module}{"Restriction"}) eq "HASH" 	&&
	    ($plugins{$module}{"Restriction"}{$what} || 0) eq 0) {

	    y2debug ("plugin '$module' not defined for $what");
	    next;
	}

	# check if plugin function is allowed for current user/group type
	if (defined $plugins{$module}{"Restriction"} 		&&
	    ref ($plugins{$module}{"Restriction"}) eq "HASH" 	&&
	    %{$plugins{$module}{"Restriction"}} 		&&
	    (defined $plugins{$module}{"Restriction"}{$type} || 0) eq 0) {

	    y2debug ("plugin '$module' not defined for entry type '$type'");
	    next;
	}
		
	my $func	= $module."::$action";
	$ret{$module}	= &$func ($module, $config, $data);
    }
    return \%ret;
}


1
# EOF
