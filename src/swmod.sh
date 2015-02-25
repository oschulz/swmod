# Copyright (C) 2009-2015 Oliver Schulz <oliver.schulz@tu-dortmund.de>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.


# == functions ========================================================

swmod_is_valid_prefix() {
	# Arguments: prefix

	\local DIR="$1"

	(swmod_get_modversion "${DIR}" &>/dev/null) && return

	\test '(' -d "${DIR}/bin" ')' \
		-o '(' -d "${DIR}/lib" ')' -o '(' -d "${DIR}/lib64" ')' \
		-o '(' -d "${DIR}/include" ')' \
		-o '(' -f "${DIR}/swmod.deps" ')' -o '(' -f "${DIR}/swmodrc.sh" ')'
}


swmod_version_match() {
	# Arguments: full_version partial_version_to_match

	\local a="$1"
	\local b="$2"
	case "$a" in
	"$b")
		# \echo "DEBUG: Full version match." 1>&2
		return ;;
	"$b"*)
		# \echo "DEBUG: Version substring match." 1>&2
		return ;;
	esac
	return 1
}


swmod_get_modversion() {
	# Arguments: prefix

	\local prefix="$1"
	\local modver="$1"
	\local pp1=`\dirname "$prefix"`
	\local pp2=`\dirname "$pp1"`
	\local a=`\basename "$prefix"`
	\local b=`\basename "$pp1"`
	\local c=`\basename "$pp2"`

	if [ "$a" = "$SWMOD_HOSTSPEC" ] ; then
		return 1
	elif [ "$b" = "$SWMOD_HOSTSPEC" ] ; then
		\echo "${c}@${a}"
		return
	else
		return 1
	fi
}


swmod_is_loaded() {
	# Arguments: prefix

	# Some environments, like the shell started by a "screen" command, do not
	# inherit special environment variables like LD_LIBRARY_PATH, but do
	# inhert others like SWMOD_LOADED_PREFIXES. In such an inconsitent state,
	# clear SWMOD_LOADED_PREFIXES:
	if [ -z "${LD_LIBRARY_PATH}" ] ; then
		\unset SWMOD_LOADED_PREFIXES
	fi

	\local prefix="$1"
	\local module=`\swmod_get_modversion "${prefix}" | \cut -d '@' -f 1` || return 1
	while \read -d ':' loadedPrefix; do
		\local loadedModule=`\swmod_get_modversion "${loadedPrefix}" | \cut -d '@' -f 1 || \echo ""`
		if [ "$loadedModule" = "$module" ] ; then
			\test "$prefix" = "$loadedPrefix" && return 0 || return 1
		fi
	done <<-@SUBST@
		$( \echo "${SWMOD_LOADED_PREFIXES}:" )
	@SUBST@
	return 1
}


swmod_findversion_indir() {
	# Arguments: module_dir module_version

	\local BASE_DIR="$1"
	\local SEARCH_VER="$2"

	# \echo "DEBUG: Searching for version \"${SEARCH_VER}\" in directory \"${BASE_DIR}\"" 1>&2
	if [ ! -d "${BASE_DIR}" ] ; then
		\echo "Internal error: Directory does not exist." 1>&2; return
	fi

	if \test "${SEARCH_VER}" = "" ; then # no version specified
		\local v
		for v in default production prod; do
			\local CAND_PREFIX="${BASE_DIR}/${SWMOD_HOSTSPEC}/${v}"
			if (test -d "${CAND_PREFIX}") && (\swmod_is_valid_prefix "${CAND_PREFIX}") ; then
				\echo "Assuming module version \"${v}\"" 1>&2
				\local SWMOD_PREFIX="${CAND_PREFIX}"
				\echo "${SWMOD_PREFIX}"
				return
			fi
		done
		if \test "${SWMOD_PREFIX}" = "" ; then
			\local spcand
			while \read spcand; do
				\local v=`\basename "${spcand}"`
				\local CAND_PREFIX="${BASE_DIR}/${SWMOD_HOSTSPEC}/${v}"
				if \swmod_is_valid_prefix "${CAND_PREFIX}" ; then
					\echo "Assuming module version \"${v}\"" 1>&2
					\local SWMOD_PREFIX="${CAND_PREFIX}"
					\echo "${SWMOD_PREFIX}"
					return
				fi
			done <<-@SUBST@
				$( \ls "${BASE_DIR}/${SWMOD_HOSTSPEC}" 2> /dev/null | sort -r -n )
			@SUBST@
		fi
	else
		\local SWMOD_SPECVER="${SEARCH_VER}"
		# \echo "DEBUG: looking for module version \"${SWMOD_SPECVER}\"" 1>&2
		if \test -d "${BASE_DIR}/${SWMOD_HOSTSPEC}/${SEARCH_VER}" ; then
			# \echo "DEBUG: Exact match." 1>&2
			\local SWMOD_PREFIX="${BASE_DIR}/${SWMOD_HOSTSPEC}/${SWMOD_SPECVER}"
			\echo "${SWMOD_PREFIX}"
			return
		else
			while \read spcand; do
				\local v=`\basename "${spcand}"`
				if \swmod_version_match "${v}" "$SWMOD_SPECVER" ; then
					\local SWMOD_PREFIX="${BASE_DIR}/${SWMOD_HOSTSPEC}/${v}"
					\echo "${SWMOD_PREFIX}"
					return
				fi
			done <<-@SUBST@
				$( \ls "${BASE_DIR}/${SWMOD_HOSTSPEC}" 2> /dev/null |sort -r -n )
			@SUBST@
		fi
	fi
}


swmod_getprefix() {
	# Arguments: module[@version]

	\local SWMOD_MODULE=`\echo "${1}@" | \cut -d '@' -f 1`
	\local SWMOD_MODVER=`\echo "${1}@" | \cut -d '@' -f 2`
	\local SWMOD_PREFIX=

	# \echo "DEBUG: Searching for module \"${SWMOD_MODULE}\", version \"${SWMOD_MODVER}\"." 1>&2


	if [ -d "${SWMOD_MODULE}" ] ; then
		# \echo "DEBUG: Full path to module specified." 1>&2
		\local SWMOD_PREFIX=`\swmod_findversion_indir "$SWMOD_MODULE" "$SWMOD_MODVER"`
		if \test "${SWMOD_PREFIX}" != "" ; then
			\echo "${SWMOD_PREFIX}"
			return;
		fi
	fi

	if \test "${SWMOD_PREFIX}" = "" ; then
		# \echo "DEBUG: Searching for module." 1>&2

		while \read -d ':' dir; do
			if [ -d "${dir}" ]; then
				# \echo "DEBUG: Checking module dir \"${dir}\"" 1>&2
				if [ -d "${dir}/${SWMOD_MODULE}" ]; then
					\local SWMOD_PREFIX=`\swmod_findversion_indir "${dir}/${SWMOD_MODULE}" "$SWMOD_MODVER"`
					if \test "${SWMOD_PREFIX}" != "" ; then
						\echo "${SWMOD_PREFIX}"
						return;
					fi
				fi
			fi
		done <<-@SUBST@
			$( \echo "${SWMOD_MODPATH}:" )
		@SUBST@
	fi
}


swmod_require_inst_prefix() {
	if \test "x${SWMOD_INST_PREFIX}" = "x" ; then
		\echo "ERROR: No install target module set (see \"swmod setinst\")." 1>&2
		return 1
	fi
}


# == init subcommand ==================================================

swmod_init() {
	## Set swmod alias ##

	\alias swmod='source swmod.sh'
}



# == hostspec subcommand ==============================================

# Generates a generic host-type specification string
#
# Examples:
# linux-debian-4.0-x86_64
# linux-ubuntu-8.04-i686
# linux-slc-4.6-x86_64
# linux-suse-10.0-i686
# sunos-5.8-sun4u


swmod_hostspec() {
	if [ "${SWMOD_HOSTSPEC}" != "" ] ; then
		\echo "${SWMOD_HOSTSPEC}"
		return 0
	elif [ -f /etc/hostspec ] ; then
		\cat /etc/hostspec | \grep -v '^#' | \grep -o '[^[:space:]]\+' | \head -n 1
		return 0;
	fi

	\local UNAME_KERNEL=`\uname -s`

	if [ "${UNAME_KERNEL}" = 'Linux' ] ; then
		\local OS="linux"

		\local DIST=`\lsb_release -s -i`
		if [ "${DIST}" = "Debian" ] ; then
			\local DIST='debian'
		elif [ "${DIST}" = "Ubuntu" ] ; then
			\local DIST='ubuntu'
		elif [ "${DIST}" = "SUSE LINUX" ] ; then
			\local DIST='suse'
		elif [ "${DIST}" = "Gentoo" ] ; then
			\local DIST='gentoo'
		elif [ "${DIST}" = "FedoraCore" ] ; then
			\local DIST='fedora'
		elif [ "${DIST}" = "RedHatEnterpriseAS" ] ; then
			\local DIST='rhel'
		elif [ "${DIST}" = "RedHatEnterpriseES" ] ; then
			\local DIST='rhel'
		elif [ "${DIST}" = "RedHatEnterpriseWS" ] ; then
			\local DIST='rhel'
		elif [ "${DIST}" = "CentOS" ] ; then
			\local DIST='centos'
		elif [ "${DIST}" = "Scientific Linux" ] ; then
			\local DIST='scientific'
		elif [ "${DIST}" = "ScientificSL" ] ; then
			\local DIST='scientific'
		elif [ "${DIST}" = "Scientific Linux CERN" ] ; then
			\local DIST='slc'
		elif [ "${DIST}" = "ScientificCERNSLC" ] ; then
			\local DIST='slc'
		fi

		# Remove non-alnum chars from DIST and convert to lowercase:
		\local DIST=`\echo "${DIST}" | \sed 's/[^[:alnum:]]//g' | \tr "[:upper:]" "[:lower:]"`

		\local REL=`\lsb_release -s -r`
		\local CPU=`\uname -m`

		\echo "${OS}-${DIST}-${REL}-${CPU}"
	elif [ "${UNAME_KERNEL}" = 'SunOS' ] ; then
		\local OS="sunos"
		\local REL=`\uname -r`
		\local CPU=`\uname -m`
		\echo "${OS}-${REL}-${CPU}"
	elif [ "${UNAME_KERNEL}" = 'Darwin' ] ; then
		\local OS="osx"
		\local REL=`\sw_vers -productVersion`
		\local CPU=`\uname -m`
		\echo "${OS}-${REL}-${CPU}"
	else
		\echo unknown
		return 1
	fi
}



# == load subcommand ==================================================

swmod_load_usage() {
echo >&2 "Usage: swmod load MODULE[@VERSION]"
cat >&2 <<EOF

You may specify either the full module path or just the module name, in which
case swmod will look for the module in the directories specified by the
SWMOD_MODPATH environment variable
EOF
} # swmod_load_usage()


swmod_load() {
	## Parse arguments ##

	\local SWMOD_MODSPEC=$1

	if \test "${SWMOD_MODSPEC}" = "" ; then
		\swmod_load_usage
		return 1
	fi


	## Detect prefix ##

	if swmod_is_valid_prefix "${SWMOD_MODSPEC}" ; then
		\local SWMOD_PREFIX="${SWMOD_MODSPEC}"
	else
		\local SWMOD_PREFIX=`\swmod_getprefix "${SWMOD_MODSPEC}"`
	fi

	if \test "${SWMOD_PREFIX}" = "" ; then
		\echo "Error: No suitable instance for module specification \"${SWMOD_MODSPEC}\" found." 1>&2
		return 1
	fi

	if \swmod_is_loaded "${SWMOD_PREFIX}" ; then
		\echo "Skipping module \"${SWMOD_PREFIX}\", already loaded" 1>&2
		return
	else
		\echo "Loading module \"${SWMOD_PREFIX}\"" 1>&2
	fi

	\local SETCLFLAGS="no"
	if [ -f "${SWMOD_PREFIX}/swmod.deps" ] ; then
		for dep in `\cat "${SWMOD_PREFIX}/swmod.deps"`; do
			if \test "${dep}" = "!clflags"; then
				\local SETCLFLAGS="yes"
			else
				\echo "Resolving dependency ${dep}" 1>&2
				\swmod_load "${dep}"
			fi
		done
	fi


	## Current environment variables ##

	\local SWMOD_PREV_PATH="$PATH"
	\local SWMOD_PREV_LD_LIBRARY_PATH="$LD_LIBRARY_PATH"
	\local SWMOD_PREV_DYLD_LIBRARY_PATH="$DYLD_LIBRARY_PATH"
	\local SWMOD_PREV_MANPATH="$MANPATH"
	\local SWMOD_PREV_PKG_CONFIG_PATH="$PKG_CONFIG_PATH"
	\local SWMOD_PREV_PYTHONPATH="$PYTHONPATH"
	\local SWMOD_PREV_ROOTSYS="$ROOTSYS"


	## Module-specific init script ##

	if [ -f "${SWMOD_PREFIX}/swmodrc.sh" ] ; then
		\echo "Sourcing \"${SWMOD_PREFIX}/swmodrc.sh\"." 1>&2
		. "${SWMOD_PREFIX}/swmodrc.sh"
	fi
	

	## Set standards paths and variables ##

	if \test "$PATH" = "$SWMOD_PREV_PATH" ; then
		\export PATH="${SWMOD_PREFIX}/bin:$PATH"
	else
		\echo "PATH already modified by module init script, skipping." 1>&2
	fi

	if \test -d "${SWMOD_PREFIX}/lib64" ; then
		\local LIBDIR="${SWMOD_PREFIX}/lib64"
	else
		\local LIBDIR="${SWMOD_PREFIX}/lib"
	fi

	if \test "`\echo ${SWMOD_HOSTSPEC} | \cut -d '-' -f 1`" = "osx" ; then
		if \test "$DYLD_LIBRARY_PATH" = "$SWMOD_PREV_DYLD_LIBRARY_PATH" ; then
			\export DYLD_LIBRARY_PATH="${LIBDIR}:$DYLD_LIBRARY_PATH"
		else
			\echo "DYLD_LIBRARY_PATH already modified by module init script, skipping." 1>&2
		fi
	else
		if \test "$LD_LIBRARY_PATH" = "$SWMOD_PREV_LD_LIBRARY_PATH" ; then
			\export LD_LIBRARY_PATH="${LIBDIR}:$LD_LIBRARY_PATH"
		else
			\echo "LD_LIBRARY_PATH already modified by module init script, skipping." 1>&2
		fi
	fi

	if \test "$MANPATH" = "$SWMOD_PREV_MANPATH" ; then
		if \test -d "${SWMOD_PREFIX}/man" ; then
			\export MANPATH="${SWMOD_PREFIX}/man:`\manpath 2> /dev/null`"
		else
			\export MANPATH="${SWMOD_PREFIX}/share/man:`\manpath 2> /dev/null`"
		fi
	else
		\echo "MANPATH already modified by module init script, skipping." 1>&2
	fi

	if (\pkg-config --version &> /dev/null); then
		if \test "$PKG_CONFIG_PATH" = "$SWMOD_PREV_PKG_CONFIG_PATH" ; then
			# pkg-config available
			\export PKG_CONFIG_PATH="${LIBDIR}/pkgconfig:$PKG_CONFIG_PATH"
		else
			\echo "MANPATH already modified by module init script, skipping." 1>&2
		fi
	fi

	
	## Check for python packages

	if \test "$PYTHONPATH" = "$SWMOD_PREV_PYTHONPATH" ; then
		\local SWMOD_PYTHON_V=`\python -V 2>&1 | \grep -o '[0-9]\+\.[0-9]\+'`
		if [ -d "${LIBDIR}/python${SWMOD_PYTHON_V}/site-packages" ] ; then
			\export PYTHONPATH="${LIBDIR}/python${SWMOD_PYTHON_V}/site-packages:${PYTHONPATH}"
		fi
	else
		\echo "PYTHONPATH already modified by module init script, skipping." 1>&2
	fi


	## Optionally add module to compiler and linker search path ##
	if \test "${SETCLFLAGS}" = "yes"; then
		\export SWMOD_CPPFLAGS="-I${SWMOD_PREFIX}/include $SWMOD_CPPFLAGS"
		\export SWMOD_LDFLAGS="-L${LIBDIR} $SWMOD_LDFLAGS"
	fi

	\export SWMOD_LOADED_PREFIXES="${SWMOD_PREFIX}:${SWMOD_LOADED_PREFIXES}"
}



# == setinst subcommand ==================================================


swmod_setinst_usage() {
echo >&2 "Usage: swmod setinst [BASE_PATH/]MODULE_NAME@MODULE_VERSION"
cat >&2 <<EOF

Set target module for software package installation.

Options:
  -?                Show help
  -l                Load target module (initialize if necessary)

You may specify either the full module path or just the module name, in which
case swmod will look for the module in the directories specified by the
SWMOD_MODPATH environment variable.
EOF
} # swmod_setinst_usage()


swmod_setinst() {
	## Parse arguments ##

	\local OPTIND=1
	while getopts ?il opt
	do
		case "$opt" in
			\?)	\swmod_setinst_usage; return 1 ;;
			i) \local init_module="yes" ;;
			l) \local load_module="yes" ;;
		esac
	done
	\shift `expr $OPTIND - 1`

	\local SWMOD_MODSPEC="${1}"
	\local SWMOD_MODULE=`\echo "${SWMOD_MODSPEC}@" | \cut -d '@' -f 1`
	\local SWMOD_MODVER=`\echo "${SWMOD_MODSPEC}@" | \cut -d '@' -f 2`

	if \test "${SWMOD_MODULE}" = "" ; then \swmod_setinst_usage; return 1;	fi

	if \test -z "$SWMOD_MODVER" ; then
		\echo "Error: Target module version must be specified." 1>&2; return
		return 1
	fi
	
	if \test x"${SWMOD_MODULE}" != x`\basename "${SWMOD_MODULE}"` ; then
	    # If SWMOD_MODULE specified as absolute path, set new SWMOD_INST_BASE
		\export SWMOD_INST_BASE=`\dirname "${SWMOD_MODULE}"`
		\local SWMOD_MODULE=`\basename "${SWMOD_MODULE}"`
	fi

	# For backwards compatibility (specification of version as second parameter)
	if \test "${SWMOD_MODVER}" = "" ; then \local SWMOD_MODVER="$2"; fi

	\export SWMOD_INST_MODULE="${SWMOD_MODULE}"
	\export SWMOD_INST_VERSION="${SWMOD_MODVER}"

	if \test "${SWMOD_INST_MODULE}" != "" ; then
		\export SWMOD_INST_PREFIX="${SWMOD_INST_BASE}/${SWMOD_INST_MODULE}/${SWMOD_HOSTSPEC}"
		if \test "${SWMOD_INST_VERSION}" != "" ; then
			\export SWMOD_INST_PREFIX="${SWMOD_INST_PREFIX}/${SWMOD_INST_VERSION}"
		fi
		\echo "Set install prefix to \"${SWMOD_INST_PREFIX}\""
		\true
	else
		\false
	fi

	if [ "${init_module}" = "yes" ] ; then
		\echo "Note: The \"setmod setinst\" option \"-i\" is deprecated and has no function anymore." 1>&2
	fi

	if [ "${load_module}" = "yes" ] ; then
		\local SWMOD_PREFIX=`\swmod_getprefix "${SWMOD_MODSPEC}"`

		if \test "${SWMOD_PREFIX}" = "" ; then
			\swmod_add_deps none
			\local SWMOD_PREFIX=`\swmod_getprefix "${SWMOD_MODSPEC}"`

			if \test "${SWMOD_PREFIX}" = "" ; then
				\echo "Error: \"swmod load\" cannot find the install target module \"${SWMOD_MODSPEC}\", check SWMOD_MODPATH variable." 1>&2
				return 1
			fi
		fi

		if \test "${SWMOD_PREFIX}" != "${SWMOD_INST_PREFIX}" ; then
			\echo "Error: \"swmod load\" would load \"${SWMOD_PREFIX}\" instead of \"${SWMOD_INST_PREFIX}\", check SWMOD_INST_BASE and SWMOD_MODPATH variables." 1>&2
			return 1
		fi

		\swmod_load "${SWMOD_MODSPEC}"
	fi
}


# == add-deps subcommand ============================================

swmod_add_deps_usage() {
echo >&2 "Usage: swmod add-deps MODULE[@VERSION] ..."
cat >&2 <<EOF

Add dependencies to current target module.

Options:
  -?                Show help
  -l                Load added dependencies immediately in current session

This adds the specified modules as dependencies to the current swmod install
target (set by "swmod setinst").

Use "swmod add-deps none" to create an empty swmod.deps file.
EOF
} # swmod_add_deps_usage()


swmod_add_deps() {
	## Parse arguments ##

	\local OPTIND=1
	while getopts ?il opt
	do
		case "$opt" in
			\?)	\swmod_add_deps_usage; return 1 ;;
			l) \local load_deps="yes" ;;
		esac
	done
	\shift `expr $OPTIND - 1`

	\swmod_require_inst_prefix || return 1

	if \test "${1}" = "" ; then
		\swmod_add_deps_usage
		return 1
	fi
	
	\mkdir -p "${SWMOD_INST_PREFIX}"

	for dep in "$@"; do
		if \test "${dep}" = "none" ; then
			if [ ! -f "${SWMOD_INST_PREFIX}/swmod.deps" ]; then
				\echo "Creating empty ${SWMOD_INST_PREFIX}/swmod.deps" 1>&2
				\touch "${SWMOD_INST_PREFIX}/swmod.deps"
			fi
			return
		else
			\local newdep="yes";
			if [ -f "${SWMOD_INST_PREFIX}/swmod.deps" ] ; then
				for d in `\cat "${SWMOD_INST_PREFIX}/swmod.deps"`; do
					if \test "${d}" = "${dep}"; then
						\local newdep="no"
					fi
				done
			fi

			if [ "${newdep}" = "yes" ] ; then
				\echo "Adding ${dep} to ${SWMOD_INST_PREFIX}/swmod.deps" 1>&2
				\echo "${dep}" >> "${SWMOD_INST_PREFIX}/swmod.deps"
			else
				\echo "Dependency ${dep} is already part of ${SWMOD_INST_PREFIX}/swmod.deps" 1>&2
			fi

			if [ "${load_deps}" = "yes" ] ; then
				\swmod_load "${dep}"
			fi
		fi
	done
}


# For backwards-compatibility:

swmod_adddeps() {
\cat >&2 <<EOF
WARNING: "swmod adddeps" is deprecated and may be removed in a future version
of swmod. Use "swmod add-deps" instead.
EOF

	\swmod_add_deps "$@"
}


# == get-deps subcommand ============================================

swmod_get_deps() {
	\swmod_require_inst_prefix || return 1

	if [ -f "${SWMOD_INST_PREFIX}/swmod.deps" ] ; then
		for d in `\cat "${SWMOD_INST_PREFIX}/swmod.deps"`; do
			\echo "${d}"
		done
	fi
}


# == configure subcommand =============================================

swmod_configure() {
	\swmod_require_inst_prefix || return 1

	\local CONFIGURE="$1"
	\shift 1

	if \test "${CONFIGURE}" = "configure" ; then
		\local CONFIGURE="./configure"
	fi

	if \test "${CONFIGURE}" = "./configure" ; then
		if \test ! -f "configure" ; then
			if \test -f "autogen.sh" ; then
				\echo "INFO: No \"configure\" file here, running autogen.sh" 1>&2
				./autogen.sh || \rm -f configure
			elif \test -f "configure.in" -o -f "configure.ac" ; then
				\echo "INFO: No \"configure\" file here, running autoreconf" 1>&2
				\autoreconf || \rm -f configure
			fi
			if \test ! -f "configure" ; then
				\echo "ERROR: Unable to generate \"configure\" file here" 1>&2
				return 1
			fi
		fi
	fi

	if [ ! -x "${CONFIGURE}" ] ; then
		\echo "Error: ${CONFIGURE} does not exist or is not executable." 1>&2
	fi


	if \test "${SWMOD_INST_PREFIX}" = "" ; then
		\echo "Error: SWMOD_INST_PREFIX not set, can't determine installation prefix." 1>&2
		return 1
	fi


	CPPFLAGS="$CPPFLAGS ${SWMOD_CPPFLAGS}" \
		LDFLAGS="$LDFLAGS ${SWMOD_LDFLAGS}" \
		"${CONFIGURE}" --prefix="${SWMOD_INST_PREFIX}" "$@"
}


# == install subcommand =============================================

swmod_install() {
	\local NCORES=`\grep -c '^processor' /proc/cpuinfo 2>/dev/null || \sysctl -n hw.ncpu 2>/dev/null || \echo 4`

	if \test -x "autogen.sh" -o -x "configure" -o -f "configure.in" -o -f "configure.ac"; then
		\echo "INFO: Autoconf / configure based build system detected" 1>&2

		if \test -f "Makefile.am"; then
			\local NPROCS="${NCORES}"
			\echo "INFO: Automake detected, will run parallel build with ${NCORES} threads." 1>&2
		else
			\local NPROCS=1
			\echo "INFO: No automake detected, parallel build may not be safe, using single-core build." 1>&2
		fi

		if [ -f "configure.in" -a "configure" -nt "configure.in" -o -f "configure.ac" -a "configure" -nt "configure.ac" ] ; then
			\echo "INFO: Keeping existing \"configure\"" 1>&2
		else
			\echo "Running maintainer-clean" 1>&2
			(\make maintainer-clean || \true)
		fi

		(if [ "Makefile" -nt "configure" ] ; then
			\echo "INFO: Using existing Makefile" 1>&2
		else
			\echo "Running distclean" 1>&2
			(\make distclean || \make clean || \true) && \swmod_configure ./configure "$@"
		fi) && (
			\make "-j${NPROCS}" &&
			\make install &&
			\echo "Installation successful."
		)
	else
		\echo "ERROR: Can't find (supported) build system current directory." 1>&2
	fi
}


# == instpkg subcommand =============================================

swmod_instpkg() {
	\local PKGSRC="$1"
	\shift 1

	if \test -z "${PKGSRC}"; then
		\echo "Syntax: swmod instpkg SOURCE [CONFIGURE_OPTION] ..."
		\echo ""
		\echo "Uses rsync internally to copy sources to $TMPDIR, PKGSRC may be any rsync-compatible"
		\echo "source specification (\local or remote)."
		return 1
	fi

	BUILDDIR=`\mktemp -d -t "$(whoami)-build-XXXXXX"`
	\echo "Build directory: \"${BUILDDIR}\""

	rsync -rlpt "${PKGSRC}/" "${BUILDDIR}/"

	(
		cd "${BUILDDIR}" \
		&& (\make maintainer-clean || \make distclean || \make clean || \true) \
		&& \swmod_install "$@"
	) && (
		\echo "Installation successful."
		\rm -rf "${BUILDDIR}"
		return 0
	) || (
		\echo "ERROR: Installation failed, build directory: \"${BUILDDIR}\"" 1>&2
		return 1
	)
}


# == main =============================================================

# Check if we're running in a bash

if ! (\ps $$ | \grep -q 'sh\|bash') ; then
	\echo "Error: swmod only works in an sh or bash environment for now - sorry." 1>&2
	return 1
fi


# Check SWMOD_HOSTSPEC

# For backward compatibility:
if \test -z "${SWMOD_HOSTSPEC}" -a -n "${HOSTSPEC}" ; then
	export SWMOD_HOSTSPEC="${HOSTSPEC}"
fi

if \test -z "${SWMOD_HOSTSPEC}"; then
	\export SWMOD_HOSTSPEC="`\swmod_hostspec`"
	if \test "${SWMOD_HOSTSPEC}" = "" ; then
		\echo "Error: Could not determine host specification." 1>&2
		return 1
	fi
fi


# Set SWMOD_MODPATH and SWMOD_INST_BASE, if not already set

\export SWMOD_MODPATH="${SWMOD_MODPATH:-${HOME}/.local/sw}"
\export SWMOD_INST_BASE="${SWMOD_INST_BASE:-${HOME}/.local/sw}"


# Get subcommand

SWMOD_COMMAND="$1"
\shift 1

if \test "${SWMOD_COMMAND}" = "" ; then
\echo >&2 "Usage: swmod COMMAND OPTIONS"
\cat >&2 <<EOF

swmod is a simple software module management tool.

Note: "swmod" is a shell alias. In scripts, use ". swmod.sh", instead.

COMMANDS
--------

  init                Set aliases, variables and create directories.

  hostspec            Show host specification string (value of SWMOD_HOSTSPEC
                      variable, automatically sets it if empty).

  load                Load a module.

  setinst             Set target module for software package installation.

  add-deps            Add dependencies to current install target module.

  get-deps            List dependencies of current install target module.

  configure           Run a configure script with suitable options to install
                      a software package into a module. You may specify the
                      full path of the script instead of "configure", e.g.
                      "./configure" or "some-path/configure". If a \local
                      configure file ("configure" or "./configure") is
                      specified but doesn't exist, swmod will try to generate
                      it by running "autogen.sh" (if present) or autoreconf.

  install             Run all necessary steps to build and install the
                      software package in the current directory. Arguments are
                      passed on to "configure".

  instpkg             Similar to install, but installs a software package from
                      a given location and performs the build in $TMPDIR.

ENVIRONMENT VARIABLES
---------------------

  SWMOD_HOSTSPEC      The host specification string, describing the system and
                      OS type, e.g. "linux-ubuntu-12.04-x86_64". If not set,
                      swmod will generate a host specification string and set
                      SWMOD_HOSTSPEC accordingly.

  SWMOD_MODPATH       Module search path. Colon-separated list of directories,
                      searched by "swmod load" and similar.

  SWMOD_INST_BASE     Base directory for new modules. "swmod setinst" will
                      create new modules here.

  SWMOD_INST_PREFIX   Current install target module prefix (set by
                      "swmod setinst").

  SWMOD_INST_MODULE   Current install target module name (set by
                      "swmod setinst").

  SWMOD_INST_VERSION  Current install target module version (set by
                      "swmod setinst").
EOF
return 1
fi

if \test "${SWMOD_COMMAND}" = "init" ; then \swmod_init "$@"
elif \test "${SWMOD_COMMAND}" = "hostspec" ; then \swmod_hostspec "$@"
elif \test "${SWMOD_COMMAND}" = "load" ; then \swmod_load "$@"
elif \test "${SWMOD_COMMAND}" = "setinst" ; then \swmod_setinst "$@"
elif \test "${SWMOD_COMMAND}" = "add-deps" ; then \swmod_add_deps "$@"
elif \test "${SWMOD_COMMAND}" = "adddeps" ; then \swmod_adddeps "$@"
elif \test "${SWMOD_COMMAND}" = "get-deps" ; then \swmod_get_deps "$@"
elif \test x`\basename "${SWMOD_COMMAND}"` = x"configure" ; then \swmod_configure "${SWMOD_COMMAND}" "$@"
elif \test "${SWMOD_COMMAND}" = "install" ; then \swmod_install "$@"
elif \test "${SWMOD_COMMAND}" = "instpkg" ; then \swmod_instpkg "$@"
else
	\echo -e >&2 "\nError: Unknown command \"${SWMOD_COMMAND}\"."
	return 1
fi

# Save swmod command return code
RC="$?"

# Clear variables
SWMOD_COMMAND=

# Emit swmod command return code
return "$RC"
