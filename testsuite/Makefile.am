#
# Makefile.am for .../testsuite
#

AUTOMAKE_OPTIONS = dejagnu
EXTRA_DIST = $(wildcard tests/*.out) $(wildcard tests/*.err) $(wildcard tests/*.ycp) $(wildcard tests/*.yh) run/runtest.sh

testsuite_prepare = @ydatadir@/testsuite/Makefile.testsuite

# explicitly list files we want for the ycp tests
# don't mess with: run/runtest.sh Makefile.am
all-local: $(testsuite_prepare)
	make -f $(testsuite_prepare) RPMNAME=$(RPMNAME) srcdir=$(srcdir) \
	        dirs \
		config/default.exp config/unix.exp config/unknown.exp \
		$(RPMNAME).test/testsuite.exp \
		.cvsignore

clean-local: $(testsuite_prepare)
	make -f $(testsuite_prepare) RPMNAME=$(RPMNAME) srcdir=$(srcdir) clean

check-local: $(testsuite_prepare)
	make -f $(testsuite_prepare) RPMNAME=$(RPMNAME) srcdir=$(srcdir) check

# EOF
