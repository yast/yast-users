#! /usr/bin/perl -w
#
# Example of plugin module
#

package UsersPluginDummy;

use strict;

use ycp;
use YaST::YCP;

our %TYPEINFO;

 
##------------------------------------
##------------------- global imports

#YaST::YCP::Import ("SCR");
#YaST::YCP::Import ("UsersCache");

##------------------------------------

##------------------------------------
# Do a special action before writing user to LDAP
BEGIN { $TYPEINFO{WriteUserBefore} = ["function",
    "boolean",
    ["map", "string", "any"]];
}
sub WriteUserBefore {

    y2milestone ("plugin function to be done before writing user");
    return 1;
}

##------------------------------------
# Do a special action before writing group to LDAP
BEGIN { $TYPEINFO{WriteGroupBefore} = ["function",
    "boolean",
    ["map", "string", "any"]];
}
sub WriteGroupBefore {

    y2milestone ("plugin function to be done before writing group");
    return 1;
}

##------------------------------------
# Do a special action before writing user to LDAP
BEGIN { $TYPEINFO{WriteUser} = ["function",
    "boolean",
    ["map", "string", "any"]];
}
sub WriteUser {

    y2milestone ("plugin function to be done after writing user");
    return 1;
}

##------------------------------------
# Do a special action after writing group to LDAP
BEGIN { $TYPEINFO{WriteGroup} = ["function",
    "boolean",
    ["map", "string", "any"]];
}
sub WriteGroup {

    y2milestone ("plugin function to be done after writing group");
    return 1;
}


1
# EOF
