# Plugins System

*yast2-users* provides a plugins system. Any YaST module can supply its own users plugins in order to extend *yast2-users* with more users and groups features. For example, *yast-samba-server* offers plugins which allow to edit some LDAP attributes related to SAMBA users and groups.

## How Plugins Works

In *yast2-users*, the forms for creating or editing users and groups contain a *Plug-Ins* tab. Such a tab lists all the available plugins for the current user/group and there is a button for launching the selected plugin. Launching a plugin means to execute a new client indicated by the plugin. That client will show an UI with extra options to configure the current user or group.

![Plug-Ins Tab](img/ldap_add3.png)

## Technical Details

A *yast2-users* plugin is a module file deployed at *yast2dir/modules* directory and whose name begins with *UsersPlugin*. For example, *yast2-samba-server* provides *yast2dir/modules/UsersPluginSamba.pm* and *yast2dir/modules/UsersPluginSambaGroups.pm* plugins. In essence, *yast2-users* will search for all *UsersPlugin\** modules and will list them in the *Plug-Ins* tab.

A plugin module is expected to provide an *Interface* method. That method returns a list of method names that can be sent to the module. For example, a module usually exposes methods like *GUIClient*, *Name*, *Summary*, *Restriction*, *InternalAttributes*, etc. *yast2-users* uses these methods to get information from the plugins or to execute some actions. For example, the methods *Name* and *Summary* are used to get the name and description of the plugins, and that information is then used in the table containing the list of available plugins. The *GUIClient* method returns a client name. Such a client is executed when a method is launched in the *Plug-Ins* tab. The client usually shows a dialog with extra attributes for the user or group. The *Restrictions* method returns a hash with the restrictions for the plugin.

A plugin usually provides more methods like *Check*, *Add*, *AddBefore*, etc.

## List of Plugins

Currently there are only two YasT modules that implement plugins for *yast2-users*. As mentioned above, one is *yast2-samba-server*, and the other one is *yast2-users* itself. This is the complete list of current plugins:

* *yast-samba-server/src/modules/UsersPluginSamba.pm*
* *yast-samba-server/src/modules/UsersPluginSambaGroups.pm*
* *~~yast-users/src/modules/UsersPluginLDAPShadowAccount.pm~~* Dropped at https://github.com/yast/yast-users/pull/366
* *~~yast-users/src/modules/UsersPluginLDAPPasswordPolicy.pm~~* Dropped at https://github.com/yast/yast-users/pull/366
* *yast-users/src/modules/UsersPluginQuota.pm*
* *~~yast-users/src/modules/UsersPluginKerberos.pm~~* Dropped at https://github.com/yast/yast-users/pull/366
* *~~yast-users/src/modules/UsersPluginLDAPAll.pm~~* Dropped at https://github.com/yast/yast-users/pull/366

All these plugins are written in Perl code, but they should be perfectly loaded in Ruby code thanks to [*YCP::Import*](https://github.com/yast/yast-core/blob/master/libycp/src/include/ycp/Import.h). This would allow to rewrite some dialogs in Ruby code but still calling the existing plugins. Only note that plugins expect an user or group to be represented as a hash structure. Some glue code will be needed in order to convert an user/group object to a hash and the other way around.
