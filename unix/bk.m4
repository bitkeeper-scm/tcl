#----------------------------------------------------------------------
# SC_PATH_BK --
#
#		Find BK and enable encryption if found. Tcl must be in a BK source tree
#		if this option is set.
#
# Arguments:
#		none
#
# Results:
#
#		Adds the following arguments to configure:
#				--with-bk=...
#
# Defines the following vars:
#		BK_DIR	Full path to the src directory in the BK repository
#----------------------------------------------------------------------

AC_DEFUN(SC_PATH_BK, [
	if test x"${no_bk}" = x ; then
		# reset no_bk in case something fails
		no_bk=true
		AC_ARG_WITH(bk, [  --with-bk              directory containing BK source], with_bksource=${withval})
		AC_MSG_CHECKING([for BK source tree])
		if test x"${with_bksource}" != x ; then
			if test -f "${with_bksource}/src/tclkey.h" ; then
				ac_cv_c_bksource=`(cd ${with_bksource}/src ; pwd)`
			else
				AC_MSG_ERROR([${with_bksource}/src directory does not contain tclkey.h])
			fi
		fi
		
		# Now check for it in the parent directory
		if test x"${ac_cv_c_bksource}" = x ; then
			if test -f "../../../../tclkey.h" ; then
				ac_cv_c_bksource=`(cd ../../../.. ; pwd)`
			fi
		fi
		
		if test x"${ac_cv_c_bksource}" = x ; then
			BK_DIR=""
			BK_HDRS="BK_HDRS = "
			BK_SRCS="BK_SRCS = "
			BK_OBJS="BK_OBJS = "
			BK_LIBS="BK_LIBS = "
			BK_INCLUDES=""
			AC_SUBST(BK_DIR)
			AC_SUBST(BK_HDRS)
			AC_SUBST(BK_SRCS)
			AC_SUBST(BK_OBJS)
			AC_SUBST(BK_INCLUDES)
			AC_SUBST(BK_LIBS)
			AC_MSG_WARN(Can't find BK source tree encryption disabled)
		else
			no_bk=
			BK_DIR=${ac_cv_c_bksource}
			BK_HDRS=""
			BK_SRCS=""
			BK_OBJS=""
			BK_LIBS=""
			BK_INCLUDES="-I$BK_DIR -I${BK_DIR}/tomcrypt -I${BK_DIR}/tomcrypt/src/headers"
			AC_DEFINE(BK)
			AC_SUBST(BK_DIR)
			AC_SUBST(BK_HDRS)
			AC_SUBST(BK_SRCS)
			AC_SUBST(BK_OBJS)
			AC_SUBST(BK_INCLUDES)
			AC_SUBST(BK_LIBS)
			AC_MSG_RESULT(found $BK_DIR)
		fi
	fi
])