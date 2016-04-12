# Sources for users

module_DATA = \
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

ylibdir = @ylibdir@/users
ylib_DATA = \
  lib/users/ca_password_validator.rb \
  lib/users/local_password.rb \
  lib/users/encryption_method.rb \
  lib/users/proposal.rb \
  lib/users/encryption_proposal.rb

scrconf_DATA = \
  scrconf/uid.scr \
  scrconf/etc_default_useradd.scr \
  scrconf/nis.scr

agent_SCRIPTS = \
  servers_non_y2/ag_nis \
  servers_non_y2/ag_uid

schemafilesdir = $(schemadir)/autoyast/rnc
schemafiles_DATA = \
  autoyast-rnc/users.rnc

desktop_DATA = \
  desktop/users.desktop

EXTRA_DIST = $(module_DATA) $(module1_DATA) $(client_DATA) $(ynclude_DATA) $(ylibdialog_DATA) $(ylib_DATA) $(scrconf_DATA) $(agent_SCRIPTS) $(schemafiles_DATA) $(desktop_DATA) $(ylibclient_DATA)

include $(top_srcdir)/Makefile.am.common
