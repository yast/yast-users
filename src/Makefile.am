#
# Makefile.am for y2c_users/src
#

menudir = $(YAST2DIR)/menuentries
includedir = $(YAST2DIR)/include/users
clientsdir = $(YAST2DIR)/clients

include_DATA =			\
	io.ycp			\
	ui.ycp			\
	functions.ycp		\
	help.ycp

clients_DATA = 			\
	users.ycp
	#users_write.ycp

menu_DATA = menuentry_users.ycp	\
	menuentry_groups.ycp	\
	menuentry_add_user.ycp  \
	menuentry_add_group.ycp 

EXTRA_DIST = $(clients_DATA) $(menu_DATA) $(include_DATA)
