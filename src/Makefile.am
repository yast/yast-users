# Sources for users

module_DATA = \
  modules/SSHAuthorizedKeys.rb \
  modules/UsersUI.rb \
  modules/UsersRoutines.pm \
  modules/UsersPluginQuota.pm \
  modules/Users.pm \
  modules/UsersPlugins.pm \
  modules/UsersPluginLDAPShadowAccount.pm \
  modules/UsersLDAP.pm \
  modules/UsersSimple.pm \
  modules/UsersCache.pm \
  modules/UsersPluginLDAPAll.pm \
  modules/UsersPluginLDAPPasswordPolicy.pm \
  modules/UsersPluginKerberos.pm \
  modules/UsersPasswd.pm

module1dir = @moduledir@/YaPI
module1_DATA = \
  modules/YaPI/ADMINISTRATOR.pm \
  modules/YaPI/USERS.pm

client_DATA = \
  clients/users_auto.rb \
  clients/users_proposal.rb \
  clients/users_encryption_proposal.rb \
  clients/users_finish.rb \
  clients/groups.rb \
  clients/users_plugin_quota.rb \
  clients/users_plugin_ldap_all.rb \
  clients/users_plugin_ldap_shadowaccount.rb \
  clients/users_plugin_ldap_passwordpolicy.rb \
  clients/users.rb \
  clients/inst_root_first.rb \
  clients/inst_user_first.rb \
  clients/users_encryption_method.rb

ylibclientdir = @ylibdir@/users/clients
ylibclient_DATA = \
  lib/users/clients/auto.rb \
  lib/users/clients/users_finish.rb

yncludedir = @yncludedir@/users
ynclude_DATA = \
  include/users/widgets.rb \
  include/users/wizards.rb \
  include/users/ldap_dialogs.rb \
  include/users/dialogs.rb \
  include/users/complex.rb \
  include/users/routines.rb \
  include/users/cmdline.rb \
  include/users/helps.rb

ylibdialogdir = @ylibdir@/users/dialogs
ylibdialog_DATA = \
  lib/users/dialogs/inst_root_first.rb \
  lib/users/dialogs/inst_user_first.rb \
  lib/users/dialogs/users_to_import.rb \
  lib/users/dialogs/encryption_method.rb

ywidgetdir = @ylibdir@/users/widgets
ywidget_DATA = \
	lib/users/widgets/inst_root_first.rb \
	lib/users/widgets/public_key_selector.rb

ylibdir = @ylibdir@
ylib_DATA = \
  lib/y2users.rb

ylib_usersdir = @ylibdir@/users
ylib_users_DATA = \
  lib/users/ca_password_validator.rb \
  lib/users/local_password.rb \
  lib/users/encryption_method.rb \
  lib/users/leaf_blk_device.rb \
  lib/users/proposal.rb \
  lib/users/ssh_public_key.rb \
  lib/users/encryption_proposal.rb \
  lib/users/ssh_authorized_keys_file.rb \
  lib/users/ssh_authorized_keyring.rb \
  lib/users/users_database.rb \
  lib/users/widgets.rb

ylib_y2usersdir = @ylibdir@/y2users
ylib_y2users_DATA = \
  lib/y2users/config_manager.rb \
  lib/y2users/config_merger.rb \
  lib/y2users/config.rb \
  lib/y2users/login_config.rb \
  lib/y2users/group.rb \
  lib/y2users/help_texts.rb \
  lib/y2users/collision_checker.rb \
  lib/y2users/password_helper.rb \
  lib/y2users/linux.rb \
  lib/y2users/password.rb \
  lib/y2users/password_validator.rb \
  lib/y2users/shadow_date.rb \
  lib/y2users/user.rb \
  lib/y2users/username.rb \
  lib/y2users/useradd_config.rb \
  lib/y2users/user_validator.rb \
  lib/y2users/validation_config.rb \
  lib/y2users/config_element.rb \
  lib/y2users/config_element_collection.rb \
  lib/y2users/users_collection.rb \
  lib/y2users/groups_collection.rb \
  lib/y2users/read_result.rb

ylib_y2users_clientsdir = @ylibdir@/y2users/clients
ylib_y2users_clients_DATA = \
  lib/y2users/clients/inst_user_first.rb \
  lib/y2users/clients/inst_root_first.rb

ylib_y2users_linuxdir = @ylibdir@/y2users/linux
ylib_y2users_linux_DATA = \
  lib/y2users/linux/useradd_config_reader.rb \
  lib/y2users/linux/useradd_config_writer.rb \
  lib/y2users/linux/login_config_writer.rb \
  lib/y2users/linux/users_writer.rb \
  lib/y2users/linux/groups_writer.rb \
  lib/y2users/linux/base_reader.rb \
  lib/y2users/linux/local_reader.rb \
  lib/y2users/linux/reader.rb \
  lib/y2users/linux/writer.rb

ylib_y2users_parsersdir = @ylibdir@/y2users/parsers
ylib_y2users_parsers_DATA = \
  lib/y2users/parsers/group.rb \
  lib/y2users/parsers/passwd.rb \
  lib/y2users/parsers/shadow.rb

ylib_y2users_autoinstdir = @ylibdir@/y2users/autoinst
ylib_y2users_autoinst_DATA = \
  lib/y2users/autoinst/config_merger.rb \
  lib/y2users/autoinst/reader.rb

ylib_y2users_autoinst_profiledir = @ylibdir@/y2users/autoinst_profile
ylib_y2users_autoinst_profile_DATA = \
  lib/y2users/autoinst_profile/group_section.rb \
  lib/y2users/autoinst_profile/groups_section.rb \
  lib/y2users/autoinst_profile/login_settings_section.rb \
  lib/y2users/autoinst_profile/password_settings_section.rb \
  lib/y2users/autoinst_profile/user_defaults_section.rb \
  lib/y2users/autoinst_profile/user_section.rb \
  lib/y2users/autoinst_profile/users_section.rb

scrconf_DATA = \
  scrconf/etc_default_useradd.scr \
  scrconf/nis.scr

agent_SCRIPTS = \
  servers_non_y2/ag_nis

schemafilesdir = $(schemadir)/autoyast/rnc
schemafiles_DATA = \
  autoyast-rnc/users.rnc

desktop_DATA = \
  desktop/org.opensuse.yast.Users.desktop

scalabledir = @icondir@/hicolor/scalable/apps
scalable_DATA = \
  icons/hicolor/scalable/apps/yast-users.svg \
  icons/hicolor/scalable/apps/yast-users-system.svg

EXTRA_DIST = $(module_DATA) $(module1_DATA) $(client_DATA) $(ynclude_DATA) $(ylibdialog_DATA) $(ylib_DATA) $(ylib_users_DATA) $(ylib_y2users_DATA) $(ylib_y2users_clients_DATA) $(ylib_y2users_linux_DATA) $(ylib_y2users_parsers) $(ylib_y2users_autoinst_DATA) $(ylib_y2users_autoinst_profile_DATA) $(scrconf_DATA) $(agent_SCRIPTS) $(schemafiles_DATA) $(desktop_DATA) $(ylibclient_DATA) $(scalable_DATA)

include $(top_srcdir)/Makefile.am.common
