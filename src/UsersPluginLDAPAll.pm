#! /usr/bin/perl -w
#
# Example of plugin module
# This is the API part of UsersPluginLDAPAll plugin - configuration of
# all user/group LDAP attributes
#

package UsersPluginLDAPAll;

use strict;

use ycp;
use YaST::YCP;

our %TYPEINFO;

# return names of provided functions
BEGIN { $TYPEINFO{Interface} = ["function", ["list", "string"]];}
sub Interface {

    return ("WriteBefore", "Write", "Summary", "GUIClient");
}

# return name of YCP client defining GUI
BEGIN { $TYPEINFO{GUIClient} = ["function", "string"];}
sub GUIClient {

    return "users_plugin_ldap_all";
}

# summary (description TODO longer)
BEGIN { $TYPEINFO{Summary} = ["function", "string"];}
sub Summary {

    return _("All attributes of LDAP entry");
}

# what should be done before user is finally written to LDAP
BEGIN { $TYPEINFO{WriteBefore} = ["function", "void", "any"];}
sub WriteBefore {

    y2internal ("WriteBefore LDAPAll called");
    return;
}

# what should be done after user is finally written to LDAP
BEGIN { $TYPEINFO{Write} = ["function", "void", "any"];}
sub Write {

    y2internal ("Write LDAPAll called");
    return;
}
1
# EOF
