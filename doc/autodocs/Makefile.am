#
# Makefile.am for yast2-config-users/doc/autodocs
#

docdir = @DOCDIR@
htmldir = $(docdir)/yast2-config-users/autodocs

html_DATA = *.html

EXTRA_DIST = $(html_DATA)

MAINTAINERCLEANFILES = $(html_DATA)

$(filter-out index.html, $(html_DATA)): index.html
index.html: $(srcdir)/../../src/*.ycp
	@YAST2DIR@/bin/ycpdoc -d. $(srcdir)/../../src/*.ycp
