#
# Makefile.am for .../agent-crack/doc/autodocs
#

htmldir = $(docdir)/autodocs

html_DATA = $(wildcard *.html *.png *.css *.js) @RPMNAME@.tag
CLEANFILES = $(html_DATA) doxygen.log doxygen.conf installdox

doxygen.css @RPMNAME@.tag: index.html

index.html: $(srcdir)/../../src/*.h
	@ybindir@/ydoxygen PROJECT_NAME=@RPMNAME@
