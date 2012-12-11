# Copyright (C) 2009-2012 Oliver Schulz <oliver.schulz@tu-dortmund.de>
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

swmod_findversion_indir() {
	# Arguments: module_dir, module_version
	# echo "DEBUG: Searching for version \"$2\" in directory \"$1\"" 1>&2
	if [ ! -d "${1}" ] ; then
		echo "Internal error: Directory does not exist." 1>&2; return
	fi

	if [ "${2}" == "" ] ; then # no version specified
		# echo "DEBUG: No version specified." 1>&2
		if [ '(' -d "$1/${HOSTSPEC}/bin" ')' -o '(' -d "$1/${HOSTSPEC}/lib" ')' -o '(' -d "$1/${HOSTSPEC}/include" ')' ] ; then
			# echo "DEBUG: module seems to be unversioned." 1>&2
			local SWMOD_PREFIX="$1/${HOSTSPEC}"
			echo "${SWMOD_PREFIX}"
			return
		else
			local v
			for v in default production prod; do
				if [ '(' -d "$1/${HOSTSPEC}/$v/bin" ')' -o '(' -d "$1/${HOSTSPEC}/$v/lib" ')' -o '(' -d "$1/${HOSTSPEC}/$v/include" ')' ] ; then
					echo "Assuming module version \"$v\"" 1>&2
					local SWMOD_PREFIX="$1/${HOSTSPEC}/$v"
					echo "${SWMOD_PREFIX}"
					return
				fi
			done
			if [ "${SWMOD_PREFIX}" == "" ] ; then
				local spcand
				while read spcand; do
					local v=`basename "${spcand}"`
					if [ '(' -d "$1/${HOSTSPEC}/$v/bin" ')' -o '(' -d "$1/${HOSTSPEC}/$v/lib" ')' -o '(' -d "$1/${HOSTSPEC}/$v/include" ')' ] ; then
						echo "Assuming module version \"$v\"" 1>&2
						local SWMOD_PREFIX="$1/${HOSTSPEC}/$v"
						echo "${SWMOD_PREFIX}"
						return
					fi
				done < <( ls "$1/${HOSTSPEC}" 2> /dev/null | sort -r -n )
			fi
			if [ "${SWMOD_PREFIX}" == "" ] ; then
				# echo "DEBUG: No versions found for module." 1>&2
				# echo "DEBUG: Warning: Assuming module to be unversioned." 1>&2
				local SWMOD_PREFIX="$1/${HOSTSPEC}"
				echo "${SWMOD_PREFIX}"
				return
			fi
		fi
	else
		local SWMOD_SPECVER="$2"
		# echo "DEBUG: looking for module version \"${SWMOD_SPECVER}\"" 1>&2
		if [ -d "$1/${HOSTSPEC}/$2" ] ; then
			# echo "DEBUG: Exact match." 1>&2
			local SWMOD_PREFIX="$1/${HOSTSPEC}/${SWMOD_SPECVER}"
			echo "${SWMOD_PREFIX}"
			return
		else
			while read spcand; do
				local v=`basename "${spcand}"`
				case $v in
				"$SWMOD_SPECVER"*)
					# echo "DEBUG: Substring match." 1>&2
					local SWMOD_PREFIX="$1/${HOSTSPEC}/${v}"
					echo "${SWMOD_PREFIX}"
					return
				esac
			done < <( ls "$1/${HOSTSPEC}" 2> /dev/null |sort -r -n )
		fi
	fi
}


swmod_getprefix() {
	# Arguments: module[@version]

	local SWMOD_MODULE=`echo "${1}@" | cut -d '@' -f 1`
	local SWMOD_MODVER=`echo "${1}@" | cut -d '@' -f 2`
	local SWMOD_PREFIX=

	# echo "DEBUG: Searching for module \"${SWMOD_MODULE}\", version \"${SWMOD_MODVER}\"." 1>&2


	if [ -d "${SWMOD_MODULE}" ] ; then
		# echo "DEBUG: Full path to module specified." 1>&2
		local SWMOD_PREFIX=`swmod_findversion_indir "$SWMOD_MODULE" "$SWMOD_MODVER"`
		if [ "${SWMOD_PREFIX}" != "" ] ; then return; fi
	fi

	if [ "${SWMOD_PREFIX}" == "" ] ; then
		# echo "DEBUG: Searching for module." 1>&2

		while read -d ':' dir; do
			if [ -d "${dir}" ]; then
				# echo "DEBUG: Checking module dir \"${dir}\"" 1>&2
				if [ -d "${dir}/${SWMOD_MODULE}" ]; then
					local SWMOD_PREFIX=`swmod_findversion_indir "${dir}/${SWMOD_MODULE}" "$SWMOD_MODVER"`
					if [ "${SWMOD_PREFIX}" != "" ] ; then
						echo "${SWMOD_PREFIX}"
						return;
					fi
				fi
			fi
		done < <( echo "${SWMOD_MODPATH}:" )
	fi
}


# == init subcommand ==================================================

swmod_init() {
	## Set aliases ##

	alias swmod='source swmod.sh'

	
	## Determine default install location ##

	if [ "${SWMOD_INST_MODULE}" == "" ] ; then
		# New standard module ~/.local/swmod/default
		export SWMOD_INST_BASE="${HOME}/.local/sw"
		export SWMOD_INST_MODULE="default"
		export SWMOD_INST_VERSION=
	fi

	
	## Determine create default install directories ##

	swmod_setinst "${SWMOD_INST_BASE}/${SWMOD_INST_MODULE}@${SWMOD_INST_VERSION}"

	# Do not fail if SWMOD_INST_PREFIX does not exist and can't be created.
	if (mkdir -p "${SWMOD_INST_PREFIX}/bin"); then true; fi
	if (mkdir -p "${SWMOD_INST_PREFIX}/lib"); then true; fi
	
	# Load default inst-module
	if swmod_load "${SWMOD_INST_BASE}/${SWMOD_INST_MODULE}@${SWMOD_INST_VERSION}" 2> /dev/null; then true; fi

	
	## Clear variables and return ##
}



# == load subcommand ==================================================

swmod_load() {
	## Parse arguments ##

	local SWMOD_MODSPEC=$1

	if [ "${SWMOD_MODSPEC}" == "" ] ; then
		echo "Syntax: swmod load MODULE[@VERSION]"
		echo
		echo "You may specify either the full module path or just the" \
			 "module name, in which case swmod will look for the module in" \
			 "the directories specified by the SWMOD_MODPATH environment variable"
		return 1
	fi


	## Detect prefix ##

	local SWMOD_PREFIX=`swmod_getprefix "${SWMOD_MODSPEC}"`

	if [ "${SWMOD_PREFIX}" == "" ] ; then
		echo "Error: No suitable instance for module specification \"${SWMOD_MODSPEC}\" found." 1>&2
		return 1
	else
		echo "Loading module \"${SWMOD_PREFIX}\"" 1>&2
	fi


	## Set standards paths and variables ##

	export PATH="${SWMOD_PREFIX}/bin:$PATH"

	if [ "`echo ${HOSTSPEC} | cut -d '-' -f 1`" == "osx" ] ; then
		export DYLD_LIBRARY_PATH="${SWMOD_PREFIX}/lib:$DYLD_LIBRARY_PATH"
	else
		export LD_LIBRARY_PATH="${SWMOD_PREFIX}/lib:$LD_LIBRARY_PATH"
	fi

	export MANPATH="`manpath 2> /dev/null`:${SWMOD_PREFIX}/man"

	if (pkg-config --version &> /dev/null); then
		# pkg-config available
		export PKG_CONFIG_PATH="${SWMOD_PREFIX}/lib/pkgconfig:$PKG_CONFIG_PATH"
	fi

	
	## Check for python packages
	local SWMOD_PYTHON_V=`python -V 2>&1 | grep -o '[0-9]\+\.[0-9]\+'`
	if [ -d "${SWMOD_PREFIX}/lib/python${SWMOD_PYTHON_V}/site-packages" ] ; then
		export PYTHONPATH="${SWMOD_PREFIX}/lib/python${SWMOD_PYTHON_V}/site-packages:${PYTHONPATH}"
	fi


	## Set SWMOD compiler and linker search paths ##

	export SWMOD_CPPFLAGS="-I${SWMOD_PREFIX}/include $SWMOD_CPPFLAGS"
	export SWMOD_LDFLAGS="-L${SWMOD_PREFIX}/lib $SWMOD_LDFLAGS"


	## Application specific settings ##

	if [ -x "${SWMOD_PREFIX}/bin/root-config" ] ; then
		# The ROOT-System itself does not use the ROOTSYS variable anymore
		# since version 5.20. However, the build systems of many software
		# packages linking against ROOT still depend on it to locate the ROOT
		# installation (instead of just using root-config).
		echo "Detected CERN ROOT System, setting ROOTSYS." 1>&2
		export ROOTSYS="${SWMOD_PREFIX}"
		export PYTHONPATH="${ROOTSYS}/lib:${PYTHONPATH}"
	fi
}



# == setinst subcommand ==================================================

swmod_setinst() {
	## Parse arguments ##

	local SWMOD_MODULE=`echo "${1}@" | cut -d '@' -f 1`
	local SWMOD_MODVER=`echo "${1}@" | cut -d '@' -f 2`

	if [ "${SWMOD_MODULE}" == "" ] ; then
		echo "Syntax: swmod setinst [BASE_PATH/]MODULE_NAME[@MODULE_VERSION]"
		echo
		echo "You may specify either the full module path or just the" \
			 "module name, in which case swmod will look for the module in" \
			 "the directories specified by the SWMOD_MODPATH environment variable"
		return 1
	fi
	
	
	if [ "${SWMOD_MODULE}" != `basename "${SWMOD_MODULE}"` ] ; then
	    # If SWMOD_MODULE specified as absolute path, set new SWMOD_INST_BASE
		export SWMOD_INST_BASE=`dirname "${SWMOD_MODULE}"`
		local SWMOD_MODULE=`basename "${SWMOD_MODULE}"`
	fi

	# For backwards compatibility (specification of version as second parameter)
	if [ "${SWMOD_MODVER}" == "" ] ; then local SWMOD_MODVER="$2"; fi

	export SWMOD_INST_MODULE="${SWMOD_MODULE}"
	export SWMOD_INST_VERSION="${SWMOD_MODVER}"

	if [ "${SWMOD_INST_MODULE}" != "" ] ; then
		export SWMOD_INST_PREFIX="${SWMOD_INST_BASE}/${SWMOD_INST_MODULE}/${HOSTSPEC}"
		if [ "${SWMOD_INST_VERSION}" != "" ] ; then
			export SWMOD_INST_PREFIX="${SWMOD_INST_PREFIX}/${SWMOD_INST_VERSION}"
		fi
	fi
}


# == configure subcommand =============================================

swmod_configure() {
	local CONFIGURE="$1"
	shift 1

	if [ "${CONFIGURE}" == "configure" ] ; then
		local CONFIGURE="./configure"
	fi

	if [ ! -x "${CONFIGURE}" ] ; then
		echo "Error: ${CONFIGURE} does not exist or is not executable." 1>&2
	fi


	if [ "${SWMOD_INST_PREFIX}" == "" ] ; then
		echo "Error: SWMOD_INST_PREFIX not set, can't determine installation prefix." 1>&2
		return 1
	fi


	CPPFLAGS="$CPPFLAGS ${SWMOD_CPPFLAGS}" \
		LDFLAGS="$LDFLAGS ${SWMOD_LDFLAGS}" \
		"${CONFIGURE}" --prefix="${SWMOD_INST_PREFIX}" "$@"
}


# == main =============================================================

# Check if we're running in a bash

if ! (ps $$ | grep -q bash) ; then
	echo "Error: swmod only works in a bash environment for now - sorry." 1>&2
	return 1
fi


# Check HOSTSPEC

if [ "${HOSTSPEC}" == "" ] ; then
	export HOSTSPEC="`hostspec`"
	if [ "${HOSTSPEC}" == "" ] ; then
		echo "Error: Could not determine host specification." 1>&2
		return 1
	fi
fi


# Get subcommand

SWMOD_COMMAND="$1"
shift 1

if [ "${SWMOD_COMMAND}" == "" ] ; then
echo >&2 "Usage: ${0} COMMAND OPTIONS"
cat >&2 <<EOF
Software module handling

COMMANDS:
  init                        Set aliases, variables and create directories.
  load                        Load a module.
  setinst                     Set target module for software package installation.
  configure                   Run a configure script with suitable options
							  to install a software package into a module.
							  You may specify the full path of the script instead,
							  e.g. ./configure or some-path/configure.
EOF
return 1
fi

if [ "${SWMOD_COMMAND}" == "init" ] ; then swmod_init "$@"
elif [ "${SWMOD_COMMAND}" == "load" ] ; then swmod_load "$@"
elif [ "${SWMOD_COMMAND}" == "setinst" ] ; then swmod_setinst "$@"
elif [ X`basename "${SWMOD_COMMAND}"` == X"configure" ] ; then swmod_configure "${SWMOD_COMMAND}" "$@"
else
	echo -e >&2 "\nError: Unknown command \"${SWMOD_COMMAND}\"."
	return 1
fi


# Clear variables

SWMOD_COMMAND=
