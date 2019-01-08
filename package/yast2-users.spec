#
# spec file for package yast2-users
#
# Copyright (c) 2014 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           yast2-users
Version:        4.1.5
Release:        0

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}-%{version}.tar.bz2

BuildRequires:  cracklib-devel
BuildRequires:  doxygen
BuildRequires:  gcc-c++
BuildRequires:  libtool
BuildRequires:  perl-Digest-SHA1
BuildRequires:  perl-XML-Writer
BuildRequires:  update-desktop-files
# UI::Widgets
BuildRequires:  yast2 >= 3.2.8
BuildRequires:  yast2-core-devel
BuildRequires:  yast2-devtools >= 3.1.10
BuildRequires:  yast2-perl-bindings
BuildRequires:  yast2-security
BuildRequires:  yast2-testsuite
BuildRequires:  rubygem(%rb_default_ruby_abi:rspec)

Requires:       cracklib
Requires:       perl-Digest-SHA1
Requires:       perl-X500-DN
Requires:       perl-gettext
Requires:       yast2-country
Requires:       yast2-pam
Requires:       yast2-security
Obsoletes:      yast2-users-devel-doc
Conflicts:      autoyast2 < 3.1.92
# older storage uses removed deprecated method, see https://github.com/yast/yast-storage/pull/187
Conflicts:      yast2-storage < 3.1.75

# y2usernote, y2useritem
Requires:       yast2-perl-bindings >= 2.18.0

# this forces using yast2-ldap with correct LDAP object names (fate#303596)
Requires:       yast2-ldap >= 3.1.2

# ProductFeatures::GetBooleanFeatureWithFallback
Requires:       yast2 >= 4.1.35
# cryptsha256, cryptsha516
Requires:       yast2-core >= 2.21.0

Requires:       yast2-ruby-bindings >= 1.0.0

Summary:        YaST2 - User and Group Configuration
License:        GPL-2.0-only
Group:          System/YaST

%description
This package provides GUI for maintenance of linux users and groups.

%prep
%setup -n %{name}-%{version}

%build
%yast_build

%install
# make testsuite/modules/Ldap.rb visible
export Y2BASE_Y2DIR=`pwd`/testsuite
%yast_install

%files
%defattr(-,root,root)
%dir %{yast_yncludedir}/users
%dir %{yast_moduledir}/YaPI
%{yast_clientdir}/*.rb
%{yast_desktopdir}/*.desktop
%{yast_moduledir}/*.pm
%{yast_moduledir}/SSHAuthorizedKeys.rb
%{yast_moduledir}/UsersUI.rb
%{yast_moduledir}/YaPI/*.pm
%{yast_yncludedir}/users/*
%{yast_libdir}/users
%{yast_schemadir}/autoyast/rnc/users.rnc
#agents:
%{yast_scrconfdir}/*.scr
%{yast_agentdir}/ag_nis
%{yast_agentdir}/ag_uid
%{yast_plugindir}/libpy2ag_crack.so.*
%{yast_plugindir}/libpy2ag_crack.so
%{yast_plugindir}/libpy2ag_crack.la
%{yast_icondir}
%dir %{yast_docdir}
%license %{yast_docdir}/COPYING
%doc %{yast_docdir}/users.html

%changelog
