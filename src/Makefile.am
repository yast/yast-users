#
# Makefile.am for y2c_users/src
#

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
	users_write.ycp	\
	inst_root.ycp	\
	inst_user.ycp   \
    auth.ycp

config_DATA =			\
	users.y2cc		\
	groups.y2cc	

ybin_SCRIPTS =  \
    build_passwd_structures.pl  \
    build_nis_structures.pl     \
    build_ldap_structures.pl    \
    build_additional_users.pl

ydata_DATA = accounts.ycp

noinst_DATA = passwd.sh

passwd.ycp: passwd.sh /etc/passwd
	./passwd.sh > passwd.ycp

EXTRA_DIST = $(client_DATA) $(config_DATA) $(ynclude_DATA) $(module_DATA) $(ydata_DATA) $(noinst_DATA) $(ybin_SCRIPTS)
