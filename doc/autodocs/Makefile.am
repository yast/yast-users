#
# Makefile.am for y2c_users/doc/autodocs
#

docdir = @DOCDIR@
htmldir = $(docdir)/autodocs

html_DATA = index.html $(wildcard *.html)
MAINTAINERCLEANFILES = $(html_DATA)

index.html: $(srcdir)/../../src/*.ycp
	@YAST2DIR@/bin/ycpdoc -d. $(srcdir)/../../src/*.ycp

clean-local:
	$(RM) $(html_DATA)
