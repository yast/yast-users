#
# Makefile.am for y2c_prnt/src
#

menudir = $(YAST2DIR)/menuentries
includedir = $(YAST2DIR)/include/users
modulesdir = $(YAST2DIR)/clients

include_DATA =			\
	io.ycp			\
	ui.ycp			\
	functions.ycp

modules_DATA = 				\
	users.ycp

menu_DATA = menuentry_users.ycp

EXTRA_DIST = \
	$(modules_DATA)			\
	$(menu_DATA)			\
	$(include_DATA)
