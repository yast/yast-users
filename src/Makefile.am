#
# Makefile.am for users/src
# $Id$
#

YCPCFLAGS = -I .

yncludedir = @yncludedir@/users

module_DATA =		\
    Users.pm		\
    UsersCache.pm

ynclude_DATA =		\
    complex.ycp		\
    dialogs.ycp		\
    helps.ycp		\
    wizards.ycp		\
    widgets.ycp		\
    routines.ycp
#    passwd.ycp      	\
#    nis_routines.ycp	\
#    ldap_routines.ycp

client_DATA = 		\
    users.ycp		\
    groups.ycp
#    users_auto.ycp	\
#    inst_root.ycp	\
#    inst_user.ycp   	\
#    inst_auth.ycp	\

#config_DATA =		\
#    users.y2cc		\
#    groups.y2cc

desktop_DATA =		\
    users.desktop	\
    groups.desktop

EXTRA_DIST = $(client_DATA) $(ynclude_DATA) $(module_DATA) $(desktop_DATA)

users:
	ln -sf . users

ycpchook = users

include $(top_srcdir)/Makefile.am.common
