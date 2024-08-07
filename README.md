# YaST - The Users Management Module #

[![Workflow Status](https://github.com/yast/yast-users/workflows/CI/badge.svg?branch=master)](
https://github.com/yast/yast-users/actions?query=branch%3Amaster)
[![OBS](https://github.com/yast/yast-users/actions/workflows/submit.yml/badge.svg)](https://github.com/yast/yast-users/actions/workflows/submit.yml)

This module allows to use YaST to manage local and LDAP users and groups. It also makes possible to
configure some aspects of the system related to user management and authentication. For a partial
description of what this module can do, check [the use-cases document](doc/use-cases.md). For an
overview on how all the authentication-related YaST modules fit together, check
[doc/auth-modules.md](doc/auth-modules.md).

Many components of the module were written in the Perl programming language a long time ago.
Although those components still work, they follow approaches that are not longer considered to be
appropriate. For example, they manage important files like `/etc/passwd` or home directories on
their own, instead of delegating those tasks to the tools included in the operating system like
those contained in the `shadow` package. The functionality and internal structure of those legacy
components is described at [doc/users.html](doc/users.html). Although that document is outdated in
some areas, it's still useful to understand how the module works in general and to have some extra
overview about the use-cases it covers (in addition to those described in the document mentioned
above).

The module is currently being rewritten in Ruby in an attempt to make it more maintainable and
better integrated with other components of the system. This is still a work in progress and both the
old Perl components and the new Ruby ones (grouped on the namespace `Y2Users`) are usually involved
in every operation. Apart from the mentioned documents, the `doc` directory contains several files
describing how both the old Perl and the new Ruby components work and the correspondences between
them.
