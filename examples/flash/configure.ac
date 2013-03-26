# Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
# Academy of Science). See COPYING in top-level directory.

#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ(2.50)

AC_INIT(top, 1.0)
AC_CONFIG_SRCDIR([top.qsf])
AM_INIT_AUTOMAKE

# Check for emu library
AC_ARG_WITH([emu], 
            [AC_HELP_STRING([--with-emu=PATH], [a path to tlp emulator])], 
            [EMU_PATH=$withval], 
            [AC_MSG_ERROR([path to tlpemu MUST be set (use --with-emu=PATH option)])] 
           ) 

AC_SUBST(EMU_PATH) 

# Checks for programs.
AC_PROG_CC
AC_PROG_CXX
AC_PROG_RANLIB

# Checks for libraries.
AC_CHECK_LIB(argtable2, arg_parse, , [AC_MSG_ERROR([package argtable2 is required])])

# TODO: check if ghdl works
AC_SUBST(GHDL, ghdl)
AC_SUBST(GHDLFLAGS, "--ieee=synopsys -fexplicit")

AC_SUBST(QSF_FILE, top.qsf)

VHDL_COMMON_SOURCES=`cat $QSF_FILE | grep '^set_global_assignment -name VHDL_FILE .*/' | sed 's/set_global_assignment -name VHDL_FILE //g' | awk '//{printf "%s ",$0;next}{print}'`
AC_SUBST(VHDL_COMMON_SOURCES)

# TODO: should exclude PCIE and other quartus-specific vhdl source files...
AC_SUBST(VHDL_EMU_SOURCES, "$VHDL_COMMON_SOURCES ../../emu/emu_top.vhd ../../emu/clock_gen.vhd")

AC_SUBST(VHDL_QUARTUS_SOURCES, "$VHDL_COMMON_SOURCES")

dnl need to reassing VHDL_BASIC_SOURCES variable in a case of qsf-file altering
AC_SUBST([CONFIG_STATUS_DEPENDENCIES], ['$(top_srcdir)/$(QSF_FILE)'])


AC_CONFIG_FILES([Makefile])

AC_OUTPUT
