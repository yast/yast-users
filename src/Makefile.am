#
# Makefile.am for y2c_users/src
#

menudir = $(YAST2DIR)/menuentries
includedir = $(YAST2DIR)/include/users
clientsdir = $(YAST2DIR)/clients

include_DATA =			\
	io.ycp			\
	ui.ycp			\
	help.ycp

clients_DATA = 			\
	users.ycp
#	users_write.ycp

menu_DATA = menuentry_users.y2cc	\
	menuentry_groups.y2cc	\
	menuentry_add_user.y2cc  \
	menuentry_add_group.y2cc 

EXTRA_DIST = $(clients_DATA) $(menu_DATA) $(include_DATA)
