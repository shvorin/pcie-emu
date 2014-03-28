# Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
# Academy of Science). See COPYING in top-level directory.

#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ(2.61)
AC_INIT([libemu],[1.0])
AC_CONFIG_SRCDIR([tlp-defs.h])
AM_INIT_AUTOMAKE
AC_CONFIG_HEADER([defines.h])

# Checks for programs.
AC_PROG_CC
AC_PROG_RANLIB

AM_PROG_CC_C_O

AC_SYS_LARGEFILE

# Checks for libraries.
dnl AS_IF([test "x$ac_cv_lib_argtable2_arg_parse" = xyes -a "x$ac_cv_header_argtable2_h" = xyes], ,
dnl     [AC_MSG_ERROR([package argtable2 is required])])

# Checks for header files.
AC_HEADER_STDC
AC_CHECK_HEADERS([stdint.h stdlib.h string.h unistd.h fcntl.h sys/socket.h])
AC_CHECK_HEADER([argtable2.h], , [AC_MSG_ERROR([package argtable2 is required])])

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

AC_CONFIG_FILES([Makefile])
AC_OUTPUT
