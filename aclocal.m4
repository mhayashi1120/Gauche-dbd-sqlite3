# generated automatically by aclocal 1.8.3 -*- Autoconf -*-

# Copyright (C) 1996, 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004
# Free Software Foundation, Inc.
# This file is free software; the Free Software Foundation
# gives unlimited permission to copy and/or distribute it,
# with or without modifications, as long as this notice is preserved.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY, to the extent permitted by law; without
# even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE.

dnl AC_GAUCHE_INIT_EXT
dnl   Sets some parameters about installed Gauche package. 
dnl
dnl    GAUCHE_CONFIG   - Name of gauche-config script
dnl    GAUCHE_TOP      - [OBSOLETED] Directory prefix where Gauche is
dnl                      installed, or empty if this is an individual
dnl                      extension.
dnl    GAUCHE_INC      - '-I' macros required to compile extensions.
dnl    GAUCHE_LIB      - '-L' macros required to link extensions.
dnl    GOSH            - Path of gosh executable
dnl    GAUCHE_VERSION  - The version of Gauche.
AC_DEFUN([AC_GAUCHE_INIT_EXT],
         [
AC_PATH_PROG([GOSH], gosh)
AC_PATH_PROG([GAUCHE_CONFIG], gauche-config)
AC_PATH_PROG([GAUCHE_PACKAGE], gauche-package)
AC_PATH_PROG([GAUCHE_INSTALL], gauche-install)
GAUCHE_TOP=
GAUCHE_INC="`gauche-config -I`"
GAUCHE_LIB="`gauche-config -L`"
AC_SUBST(GAUCHE_TOP)
AC_SUBST(GAUCHE_INC)
AC_SUBST(GAUCHE_LIB)
GAUCHE_VERSION=`$GAUCHE_CONFIG -V`
AC_SUBST(GAUCHE_VERSION)
AC_DEFINE_UNQUOTED(GAUCHE_VERSION, "$GAUCHE_VERSION", [Gauche version string])


AC_ARG_WITH(sqlite3,
	AC_HELP_STRING([--with-sqlite3=PATH],[path to sqlite3 prefix]),
	[
		SQLITE_PREFIX="$withval"
		SQLITE_INC="-I$SQLITE_PREFIX/include"
		SQLITE_LIB="-L$SQLITE_PREFIX/lib -lsqlite3"
		],
	[
			SQLITE_INC="-I`pkg-config --variable=includedir sqlite3`"
			SQLITE_LIB="-L`pkg-config --variable=libdir sqlite3` -lsqlite3"
	])

AC_MSG_RESULT([using $SQLITE_INC for sqlite3-includes])
AC_MSG_RESULT([using $SQLITE_LIB for sqlite3-libs])





])


dnl AC_GAUCHE_INSTALL_TYPE(TYPE)
dnl   Sets the default value of INSTALL_TYPE macro.  TYPE must be either
dnl   sys or site.
AC_DEFUN([AC_GAUCHE_INSTALL_TYPE],
         [
: ${INSTALL_TYPE=$1}
if test "X$INSTALL_TYPE" != "Xsys" -a "X$INSTALL_TYPE" != "Xsite"; then
  AC_MSG_ERROR([INSTALL_TYPE must be either 'sys' or 'site'])
fi
AC_SUBST(INSTALL_TYPE)
])

dnl AC_GAUCHE_CC
dnl   Gets compiler parameters which Gauche has been compiled with.
AC_DEFUN([AC_GAUCHE_CC],
         [
CC="`$GAUCHE_CONFIG --cc`"
AC_SUBST(CC)
# adds default CFLAGS if it has not been set.
ac_gauche_CFLAGS=${CFLAGS+set}
if test -z "$ac_gauche_CFLAGS"; then
  CFLAGS="`$GAUCHE_CONFIG --default-cflags`"
fi
# adds default OBJEXT if it has not been set.
ac_gauche_OBJEXT=${OBJEXT+set}
if test -z "$ac_gauche_OBJEXT"; then
  OBJEXT="`$GAUCHE_CONFIG --object-suffix`"
fi
ac_gauche_EXEEXT=${EXEEXT+set}
if test -z "$ac_gauche_EXEEXT"; then
  EXEEXT="`$GAUCHE_CONFIG --executable-suffix`"
fi
ac_gauche_SOEXT=${SOEXT+set}
if test -z "$ac_gauche_SOEXT"; then
  SOEXT="`$GAUCHE_CONFIG --so-suffix`"
fi
ac_gauche_DYLIBEXT=${DYLIBEXT+set}
if test -z "$ac_gauche_DYLIBEXT"; then
  DYLIBEXT="`$GAUCHE_CONFIG --dylib-suffix`"
fi
AC_SUBST(OBJEXT)
AC_SUBST(EXEEXT)
AC_SUBST(SOEXT)
AC_SUBST(DYLIBEXT)
])

dnl AC_GAUCHE_FLAGS
dnl   Sets CFLAGS, CPPFLAGS and LDFLAGS appropriate for furthre testing.
dnl   This should come before any testings that require those flags to be set.
AC_DEFUN([AC_GAUCHE_FLAGS],
         [
CFLAGS="$CFLAGS $GAUCHE_INC $SQLITE_INC $SQLITE_FLAGS"
AC_SUBST(CFLAGS)
CPPFLAGS="$CPPFLAGS $GAUCHE_INC"       # some test requires this
LDFLAGS="$LDFLAGS `$GAUCHE_CONFIG --local-libdir`"
AC_GAUCHE_OPTFLAGS
])

dnl AC_GAUCHE_OPTFLAGS
dnl   Sets OPTFLAGS with some optimization flags using heuristics.
dnl   If you use AC_GAUCHE_FLAGS, this test is included.
dnl   The main configure and gc's configure also use this.
AC_DEFUN([AC_GAUCHE_OPTFLAGS],
         [
case "$target" in
  i686-*) I686OPT="-DUSE_I686_PREFETCH";;
esac
if test "$CC" = "gcc"; then
  case "$target" in
    *mingw*) ;;
    *)       GCCOPT="-fomit-frame-pointer";;
  esac
  case "$target" in
   i586-*) GCCOPT="$GCCOPT -march=i586";;
   i686-*) GCCOPT="$GCCOPT -march=i686";;
  esac
fi
OPTFLAGS="$GCCOPT $I686OPT"
AC_SUBST(OPTFLAGS)
])

dnl AC_GAUCHE_FIX_LIBS
dnl   Sets LDFLAGS and LIBS to generate shared library.
dnl   This has to come after all the tests that require linking, or those test
dnl   will fail because they can't generate stand-alone executable.
AC_DEFUN([AC_GAUCHE_FIX_LIBS],
         [
LDFLAGS="$LDFLAGS `$GAUCHE_CONFIG --so-ldflags`"
LIBS="$GAUCHE_LIB $SQLITE_LIB `$GAUCHE_CONFIG -l` $LIBS"
AC_SUBST(LDFLAGS)
])

dnl AC_GAUCHE_EXT_FIXUP(FILE [, MODULE])
dnl   [OBSOLETED: Use gauche-config --fixup-extension instead]
dnl   Sets the shell command to generate 'FILE_head.c' and 'FILE_tail.c',
dnl   needed by some platforms for GC.  MODULE must be the extension
dnl   module's name, and has to match the name given to the SCM_INIT_EXTENSION
dnl   macro in the extension initialization code.   If MODULE is omitted
dnl   FILE is used as the module's name.
AC_DEFUN([AC_GAUCHE_EXT_FIXUP],
         [AC_CONFIG_COMMANDS("$1_head_n_tail",
                             [
if test "X$2" = X; then 
  ac_gauche_ext_fixup_name=`echo $1 | tr -c "\012A-Za-z0-9" "_"`
else
  ac_gauche_ext_fixup_name="$2"
fi
AC_MSG_NOTICE(generating $1_head.c and $1_tail.c);
echo "void *Scm__datastart_$ac_gauche_ext_fixup_name = (void*)&Scm__datastart_$ac_gauche_ext_fixup_name;" > $1_head.c
echo "void *Scm__bssstart_$ac_gauche_ext_fixup_name;" >> $1_head.c
echo "void *Scm__dataend_$ac_gauche_ext_fixup_name = (void*)&Scm__dataend_$ac_gauche_ext_fixup_name;" > $1_tail.c
echo "void *Scm__bssend_$ac_gauche_ext_fixup_name;" >> $1_tail.c
])])

dnl AC_GAUCHE_PATH
dnl   Set Gauche package installed path.
dnl
AC_DEFUN([AC_GAUCHE_SET_PATH],
         [
GAUCHE_PKGINCDIR=`$GAUCHE_CONFIG --pkgincdir`
GAUCHE_PKGLIBDIR=`$GAUCHE_CONFIG --pkglibdir`
GAUCHE_PKGARCHDIR=`$GAUCHE_CONFIG --pkgarchdir`
AC_SUBST(GAUCHE_PKGINCDIR)
AC_SUBST(GAUCHE_PKGLIBDIR)
AC_SUBST(GAUCHE_PKGARCHDIR)
])

dnl AC_GAUCHE_MAKE_GPD
dnl   Creates a Gauche package description file.
dnl
AC_DEFUN([AC_GAUCHE_MAKE_GPD],
         [
GAUCHE_PACKAGE_CONFIGURE_ARGS="`echo ""$ac_configure_args"" | sed 's/[\\""\`\$]/\\\&/g'`"
AC_MSG_NOTICE([creating ${PACKAGE_NAME}.gpd])
$GAUCHE_PACKAGE make-gpd "$PACKAGE_NAME" \
  -version "$PACKAGE_VERSION" \
  -configure "./configure $GAUCHE_PACKAGE_CONFIGURE_ARGS"
])

