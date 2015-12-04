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
  clients/users_finish.rb \
  clients/groups.rb \
  clients/inst_user.rb \
  clients/inst_auth.rb \
  clients/users_plugin_quota.rb \
  clients/users_plugin_ldap_all.rb \
  clients/users_plugin_ldap_shadowaccount.rb \
  clients/users_plugin_ldap_passwordpolicy.rb \
  clients/users.rb \
  clients/inst_root_first.rb \
  clients/inst_root.rb \
  clients/inst_user_first.rb

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

ylibclientdir = "${yast2dir}/lib/installation/clients"
ylibclient_DATA = \
  lib/users/clients/inst_root_first.rb \
  lib/users/clients/inst_user_first.rb

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

EXTRA_DIST = $(module_DATA) $(module1_DATA) $(client_DATA) $(ynclude_DATA) $(scrconf_DATA) $(agent_SCRIPTS) $(schemafiles_DATA) $(desktop_DATA)

include $(top_srcdir)/Makefile.am.common
