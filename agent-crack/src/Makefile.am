#
# Makefile.am for .../agent-crack/src
#

AM_CXXFLAGS = -DY2LOG=\"agent-crack\" -Wall

plugin_LTLIBRARIES = libpy2ag_crack.la
noinst_LTLIBRARIES = liby2ag_crack.la

liby2ag_crack_la_SOURCES =				\
	CrackAgent.cc					\
	CrackAgent.h
liby2ag_crack_la_LDFLAGS = -version-info 2:0
liby2ag_crack_la_LIBADD = -lcrack -L$(libdir)

libpy2ag_crack_la_SOURCES =				\
        $(liby2ag_crack_la_SOURCES)			\
        Y2CCCrackAgent.cc         #Y2CCCrackAgent.h
libpy2ag_crack_la_LDFLAGS = -version-info 2:0
libpy2ag_crack_la_LIBADD = -lcrack -L$(libdir)

INCLUDES = -I$(includedir)
