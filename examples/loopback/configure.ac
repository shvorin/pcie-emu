# Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
# Academy of Science). See COPYING in top-level directory.

#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ(2.50)

AC_INIT(top, 1.0)
AC_CONFIG_SRCDIR([Makefile.am]) # FIXME
AM_INIT_AUTOMAKE

AC_SUBST(EMU_PATH, ['$(top_srcdir)/../../emu-server'])

# Checks for programs.
AC_PROG_CC
AC_PROG_RANLIB

# Checks for libraries.
AC_CHECK_LIB(argtable2, arg_parse, , [AC_MSG_ERROR([package argtable2 is required])])

# TODO: check if ghdl works
AC_SUBST(GHDL, ghdl)
AC_SUBST(GHDLFLAGS, "--ieee=synopsys -fexplicit")

AC_CONFIG_FILES([Makefile])

AC_OUTPUT
