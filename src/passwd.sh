#!/bin/bash

passwd=/etc/passwd

# header
echo \
'/**
 * File:	include/users/passwd.ycp
 * Package:	Users configuration
 * Summary:	System users translations
 * Authors:	Michal Svec <msvec@suse.cz>
 *
 * $Id$
 */

{

textdomain "users";

global map SystemUsers = $[
'

# main()
cat $passwd| sed 's/#.*$//g' | grep -v '^$'| cut -d: -f1,5 |
    while IFS=: read user name; do
	[ "$user" == "+" ] && continue
	[ -z "$name" ] && echo "Empty name: $user" >&2 && exit 1
	echo "    /* User name for user: \"$user\" */"
	echo "    \"$user\" : _(\"$name\"),"
    done || exit 1

# footer
echo '
];

/* EOF */
}'
