#
# Makefile.am for y2c_users/src
#

yncludedir = @yncludedir@/users

module_DATA =			\
	Users.ycp		\
	UserDefs.ycp		\
	UserSettings.ycp	\
	UserWriteStack.ycp	\
	UserAddDefs.ycp

ynclude_DATA =			\
	ui.ycp			\
	help.ycp

client_DATA = 			\
	users.ycp		\
	users_auto.ycp		\
	users_write.ycp

config_DATA = users.y2cc	\
	groups.y2cc	\
	add_user.y2cc	\
	add_group.y2cc

EXTRA_DIST = $(client_DATA) $(config_DATA) $(ynclude_DATA) $(module_DATA)
