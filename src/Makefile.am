#
# Makefile.am for y2c_users/src
#

yncludedir = @yncludedir@/users

module_DATA =			\
	Users.ycp		\
	UserDefs.ycp		\
	UserSettings.ycp	\
	UserWriteStack.ycp	\
	UserAddDefs.ycp		\
	User.ycp		\
	Accounts.ycp

ynclude_DATA =			\
	ui.ycp			\
	help.ycp		\
	passwd.ycp

client_DATA = 			\
	users.ycp		\
	users_auto.ycp		\
	users_write.ycp		\
	inst_root.ycp		\
	inst_user.ycp

config_DATA =			\
	users.y2cc		\
	groups.y2cc		\
	add_user.y2cc		\
	add_group.y2cc

ydata_DATA = accounts.ycp

noinst_DATA = passwd.sh

passwd.ycp: passwd.sh /etc/passwd
	./passwd.sh > passwd.ycp

EXTRA_DIST = $(client_DATA) $(config_DATA) $(ynclude_DATA) $(module_DATA) $(ydata_DATA) $(noinst_DATA)
