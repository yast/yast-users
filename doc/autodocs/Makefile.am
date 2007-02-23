# Makefile.am for YCP module .../doc/autodocs

htmldir = @docdir@/autodocs

index.html: $(srcdir)/../../src/*.ycp $(srcdir)/../../src/*.pm
	$(ybindir)/ycpdoc -d. $(srcdir)/../../src/*.ycp
	for i in `find $(srcdir)/../../src/YaPI/ -name "*.pm"` ; do \
          RET=`grep =head1 $$i` ; \
          if [ $$? -eq 0 ] ; then \
            NAME=`grep -m 1 '^package' $$i | sed 's/package //' | sed 's/;//'` ; \
            NAME2=`echo $$NAME | sed 's/::/-/'` ; \
            /usr/bin/pod2html --title $$NAME $$i > ./$$NAME2.html ; \
          fi ; \
        done
	rm -f *.tmp

html_DATA = index.html $(wildcard *.html)
CLEANFILES = $(html_DATA)
