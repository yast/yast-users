# Known API Usage

Goal of this document is to collect the _known usage_[1] of the Users API to be sure that these parts
get extra care.

## yast2-firewall

During installation, the proposal decides if SSH service should be enabled or not according to the
value of root password.

 * https://github.com/yast/yast-firewall/blob/b9e50c740a4a3007b8e2cc8a40141680b24bf7d7/src/lib/y2firewall/proposal_settings.rb#L162-L169

## yast2-firstboot

The module just calls installation clients and do write itself. Difference can be different
operation mode.

* https://github.com/yast/yast-firstboot/blob/master/src/lib/y2firstboot/clients/user.rb
* https://github.com/yast/yast-firstboot/blob/master/src/lib/y2firstboot/clients/root.rb

## yast2-ftp-server

The module needs to map user name to uid and home directory to store ftp files.

* https://github.com/yast/yast-ftp-server/blob/834787ead6ce1a337151ae0ff4a691b76fedeb3f/src/modules/FtpServer.rb#L340-L366

## yast2-installation

This module could interact with Yast::Users in several ways:

* Setting the root password (dead client?)

  - https://github.com/yast/yast-installation/blob/master/src/lib/installation/clients/inst_keyboard_root_password.rb

    Note that the client is using CWM widgets from yast2-users

* Creating a user with password and name (??)

* Loading the users database from given device.

  - https://github.com/yast/yast-installation/blob/b6bd0c84ea575ca89e34724b4a873ac1be68e8a1/src/lib/installation/clients/inst_pre_install.rb#L45-L48

* Identically to `yast2-firewall`, asking for the root password to determine whether only public key
  is being used.

  - https://github.com/yast/yast-installation/blob/b6bd0c84ea575ca89e34724b4a873ac1be68e8a1/src/lib/installation/security_settings.rb#L188-L195

## yast2-mail

The modules needs list of users. Including system, nis and ldap.

* https://github.com/yast/yast-mail/blob/b504d682b707828581060a7597464a6fb59fcece/src/include/mail/widgets.rb#L333

## yast2-s390

It makes almost all kind of operations with users and groups.

* Queries for local and/or system users - https://github.com/yast/yast-s390/blob/117337b69f87cbfd8bb311598aaed4405426869e/src/modules/IUCVTerminalServer.rb#L93-L110
* Adds users - https://github.com/yast/yast-s390/blob/117337b69f87cbfd8bb311598aaed4405426869e/src/modules/IUCVTerminalServer.rb#L196
* Deletes users - https://github.com/yast/yast-s390/blob/117337b69f87cbfd8bb311598aaed4405426869e/src/modules/IUCVTerminalServer.rb#L137
* Detects if users are modified
  - https://github.com/yast/yast-s390/blob/117337b69f87cbfd8bb311598aaed4405426869e/src/modules/IUCVTerminalServer.rb#L586
  - https://github.com/yast/yast-s390/blob/117337b69f87cbfd8bb311598aaed4405426869e/src/include/s390/iucvterminal-server/ui.rb#L1562
* Queries for groups - https://github.com/yast/yast-s390/blob/117337b69f87cbfd8bb311598aaed4405426869e/src/modules/IUCVTerminalServer.rb#L115-L129
* Updates users and groups - https://github.com/yast/yast-s390/blob/117337b69f87cbfd8bb311598aaed4405426869e/src/include/s390/iucvterminal-server/ui.rb#L761
* Write changes - https://github.com/yast/yast-s390/blob/117337b69f87cbfd8bb311598aaed4405426869e/src/modules/IUCVTerminalServer.rb#L590

## yast2-samba-server

Apart from providing plugins for users and groups from samba, this module can add and edit users and
groups.

- https://github.com/yast/yast-samba-server/blob/a64492fb21c5587d1a9073813100b1992208b1c4/src/clients/users_plugin_samba.rb#L300-L308
- https://github.com/yast/yast-samba-server/blob/a64492fb21c5587d1a9073813100b1992208b1c4/src/clients/users_plugin_samba_groups.rb#L148-L152

## yast2-sudo

The module needs to read local users from Passwd.

- https://github.com/yast/yast-sudo/blob/ecbd3a932a37cd54f804c1e88f89dbb6e6ee1d02/src/modules/Sudo.rb#L260

---

[1] For guessing where Yast::Users is being used, below `grep` has been executed in an updated copy
of YaST repos


```bash
➜ grep -Erl "Yast.import \"User.*\"|Yast::User.*" ./ | cut -d'/' -f2 | sort | uniq

firewall
firstboot
ftp-server
installation
mail
metapackage-handler
s390
samba-server
sudo
users
ycp-ui-bindings
```

Same result using

> grep -Erl --include \*.rb "Yast.import \"User.*\"|Yast::User.*|Users\." ./ | cut -d'/' -f2 | sort | uniq
