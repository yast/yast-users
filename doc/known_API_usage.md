Known API Usage
---------------

Goal of this document is too collect known cases of usage of Users API to be sure that that parts gets extra care.

## yast2-firstboot

The module just calls installation clients and do write itself. Difference can be different operation mode.

## yast2-ftp-server

The module needs to map user name to uid and home directory to store ftp files.

## yast2-installation

The module needs to set root password. Create user with password and name. It also has ability to load user database from given device.
It uses CWM widgets from yast2-users

## yast2-mail

The modules needs list of users. Including system, nis and ldap.

## yast2-samba-server

The module provides plugin for users from samba.

## yast2-s390

The module needs list of users and their shell. Also it enlist groups. It also creates users and groups. It needs to also detect if users are modified, to provide its modified status.

## yast2-sudo

The module needs local users from Passwd.

## list of files using users

- firstboot/src/lib/y2firstboot/clients/root.rb
- firstboot/src/lib/y2firstboot/clients/user.rb
- ftp-server/src/modules/FtpServer.rb
- installation/src/lib/installation/clients/inst_keyboard_root_password.rb
- installation/src/lib/installation/clients/inst_pre_install.rb
- installation/src/lib/installation/security_settings.rb
- mail/src/include/mail/widgets.rb
- s390/src/include/s390/iucvterminal-server/ui.rb
- s390/src/modules/IUCVTerminalServer.rb
- samba-server/src/clients/users_plugin_samba.rb
- samba-server/src/clients/users_plugin_samba_groups.rb
- sudo/src/modules/Sudo.rb
