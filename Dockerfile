FROM yastdevel/cpp:sle12-sp2
RUN zypper --gpg-auto-import-keys --non-interactive in --no-recommends \
  cracklib-devel \
  perl-Digest-SHA1 \
  yast2 \
  yast2-ldap \
  yast2-perl-bindings \
  yast2-security \
  yast2-testsuite
COPY . /usr/src/app

