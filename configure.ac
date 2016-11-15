# Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
# Academy of Science). See COPYING in top-level directory.

#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ(2.50)

AC_INIT(topleve, 1.0)
AC_CONFIG_SRCDIR([Makefile.am]) # FIXME
AM_INIT_AUTOMAKE
AC_CONFIG_HEADER([defines.h])

AC_SUBST(EMU_PATH, ['$(top_srcdir)/emu-server'])

# Checks for programs.
AC_PROG_CC
AC_PROG_RANLIB

AM_PROG_CC_C_O

AC_SYS_LARGEFILE

# Checks for libraries.
AC_HEADER_STDC
AC_CHECK_HEADERS([stdint.h stdlib.h string.h unistd.h fcntl.h sys/socket.h])
AC_CHECK_LIB(argtable2, arg_parse, , [AC_MSG_ERROR([package argtable2 is required])])

# Checks for typedefs, structures, and compiler characteristics.
AC_HEADER_STDBOOL
AC_C_CONST
AC_TYPE_PID_T
AC_TYPE_SIZE_T
AC_TYPE_SSIZE_T
AC_TYPE_OFF_T
AC_TYPE_UINT32_T
AC_TYPE_UINT64_T
AC_C_VOLATILE

# Checks for library functions.
AC_FUNC_ERROR_AT_LINE
AC_FUNC_MALLOC
AC_FUNC_MMAP
AC_CHECK_FUNCS([memset munmap socket])

# TODO: check if ghdl works
AC_SUBST(GHDL, ghdl)
AC_SUBST(GHDLFLAGS, "--ieee=synopsys -fexplicit")

AC_CONFIG_FILES(Makefile emu-server/Makefile examples/loopback/Makefile)

AC_OUTPUT
