#! /usr/bin/perl -w
#
# Example of plugin module
#

package UsersPluginDummy;

use strict;

use ycp;
use YaST::YCP;

our %TYPEINFO;

BEGIN { $TYPEINFO{Interface} = ["function", ["list", "string"]];}
sub Interface {

    return ("Write", "Summary", "GUIClient");
}

BEGIN { $TYPEINFO{GUIClient} = ["function", "string"];}
sub GUIClient {

    return "users_plugin_dummy.ycp";
}

BEGIN { $TYPEINFO{Summary} = ["function", "string"];}
sub Summary {

    return "Dummy";
}

BEGIN { $TYPEINFO{Write} = ["function", "void"];}
sub Write {

    y2internal ("Write Dummy called");
    return;
}
1
# EOF
