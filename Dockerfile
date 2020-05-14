FROM registry.opensuse.org/yast/head/containers/yast-cpp:latest
RUN zypper --non-interactive in --force-resolution --no-recommends \
  cracklib-devel \
  perl-Digest-SHA1 \
  perl-X500-DN \
  yast2 \
  yast2-ldap \
  yast2-perl-bindings \
  yast2-security \
  yast2-testsuite
COPY . /usr/src/app
