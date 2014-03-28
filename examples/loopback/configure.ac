# Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
# Academy of Science). See COPYING in top-level directory.

#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ(2.50)

AC_INIT(top, 1.0)
AC_CONFIG_SRCDIR([top.qsf])
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

AC_SUBST(QSF_FILE, top.qsf)

VHDL_COMMON_SOURCES=`cat $QSF_FILE | grep '^set_global_assignment -name VHDL_FILE ' | grep -v NOGHDL | sed 's/set_global_assignment -name VHDL_FILE //g' | sed 's/"//g' | awk '//{printf "%s ",$0;next}{print}'`
AC_SUBST(VHDL_COMMON_SOURCES)

# TODO: should exclude PCIE and other quartus-specific vhdl source files...
AC_SUBST(VHDL_EMU_SOURCES, "$VHDL_COMMON_SOURCES ../../hdllib/emu/emu_top256.vhd ../../hdllib/emu/clock_gen.vhd emu_conf.vhd")

AC_SUBST(VHDL_QUARTUS_SOURCES, "$VHDL_COMMON_SOURCES")

dnl need to reassing VHDL_BASIC_SOURCES variable in a case of qsf-file altering
AC_SUBST([CONFIG_STATUS_DEPENDENCIES], ['$(top_srcdir)/$(QSF_FILE)'])


AC_CONFIG_FILES([Makefile])

AC_OUTPUT
