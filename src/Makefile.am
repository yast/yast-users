#
# Makefile.am for users/src
# $Id$
#

SUBDIRS = scripts

yncludedir = @yncludedir@/users

module_DATA =			\
	Users.ycp		\
	UsersCache.ycp

ynclude_DATA =		\
	complex.ycp		\
    dialogs.ycp     \
	helps.ycp		\
	passwd.ycp      \
    wizards.ycp     \
    routines.ycp    \
    nis_routines.ycp\
    ldap_routines.ycp

client_DATA = 		\
	users.ycp		\
	users_auto.ycp	\
	inst_root.ycp	\
	inst_user.ycp   \
	inst_auth.ycp	\
    expert_login.ycp

config_DATA =			\
	users.y2cc		\
	groups.y2cc

#ydata_DATA = accounts.ycp# FIXME: not used any more

#noinst_DATA = passwd.sh# FIXME: not used any more

#passwd.ycp: passwd.sh /etc/passwd
#	./passwd.sh > passwd.ycp

EXTRA_DIST = $(client_DATA) $(config_DATA) $(ynclude_DATA) $(module_DATA)
#$(ydata_DATA) $(noinst_DATA)
