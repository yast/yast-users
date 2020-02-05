# YaST - The Users Management Module #

[![Travis Build](https://travis-ci.org/yast/yast-users.svg?branch=master)](https://travis-ci.org/yast/yast-users)
[![Jenkins Build](http://img.shields.io/jenkins/s/https/ci.opensuse.org/yast-users-master.svg)](https://ci.opensuse.org/view/Yast/job/yast-users-master/)

This program allows a system administrator to configure and manage local and remote users.

## Install

To install this on the latest openSUSE or SLE, use zypper:

```
$ sudo zypper install yast2-users
```

# Developement

To prepare your environment you need to install a number of packages:

```
ruby_version=$(ruby -e "puts RbConfig::CONFIG['ruby_version']")
zypper install -C "rubygem(ruby:$ruby_version:yast-rake)"
zypper install -C "rubygem(ruby:$ruby_version:rspec)"
zypper install git yast2-devtools yast2-testsuite yast
```

You can then run the module with:

```
rake run
```

# Tests

```
rake test:unit
```

# Logs

If you are running as a non-root user, the logs are located in:

```
~/.y2log
```

If you are running as root, these logs are in:

```
/var/log/YaST2/y2log
```

For more detailed logging, you are able to execute YaST with debugging environment variables:

```
Y2DEBUG=1 rake run
```

# Build

You can build the package with:

```
rake osc:build
```

