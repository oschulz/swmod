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
			SWMOD_PREFIX="$1/${HOSTSPEC}"; return
		else
			local v
			for v in default production prod; do
				if [ '(' -d "$1/${HOSTSPEC}/$v/bin" ')' -o '(' -d "$1/${HOSTSPEC}/$v/lib" ')' -o '(' -d "$1/${HOSTSPEC}/$v/include" ')' ] ; then
					echo "Assuming module version \"$v\"" 1>&2
					SWMOD_MODVER="${v}"
					SWMOD_PREFIX="$1/${HOSTSPEC}/$v"; return
				fi
			done
			if [ "${SWMOD_PREFIX}" == "" ] ; then
				local spcand
				while read spcand; do
					local v=`basename "${spcand}"`
					if [ '(' -d "$1/${HOSTSPEC}/$v/bin" ')' -o '(' -d "$1/${HOSTSPEC}/$v/lib" ')' -o '(' -d "$1/${HOSTSPEC}/$v/include" ')' ] ; then
						echo "Assuming module version \"$v\"" 1>&2
						SWMOD_MODVER="${v}"
						SWMOD_PREFIX="$1/${HOSTSPEC}/$v"; return
					fi
				done < <( ls "$1/${HOSTSPEC}" 2> /dev/null | sort -r -n )
			fi
			if [ "${SWMOD_PREFIX}" == "" ] ; then
				# echo "DEBUG: No versions found for module." 1>&2
				# echo "DEBUG: Warning: Assuming module to be unversioned." 1>&2
				SWMOD_PREFIX="$1/${HOSTSPEC}"; return
			fi
		fi
	else
		# echo "DEBUG: looking for module version \"${2}\"" 1>&2
		if [ -d "$1/${HOSTSPEC}/$2" ] ; then
			# echo "DEBUG: Exact match." 1>&2
			SWMOD_PREFIX="$1/${HOSTSPEC}/$2"
			return
		else
			while read spcand; do
				local v=`basename "${spcand}"`
				case $v in
				"$SWMOD_MODVER"*)
					# echo "DEBUG: Substring match." 1>&2
					SWMOD_MODVER="${v}"
					SWMOD_PREFIX="$1/${HOSTSPEC}/${v}"
				esac
			done < <( ls "$1/${HOSTSPEC}" 2> /dev/null |sort -r -n )
		fi
	fi
}


swmod_getprefix() {
	# Arguments: module[@version]

	SWMOD_MODULE=`echo "${1}@" | cut -d '@' -f 1`
	SWMOD_MODVER=`echo "${1}@" | cut -d '@' -f 2`
	SWMOD_PREFIX=

	# echo "DEBUG: Searching for module \"${SWMOD_MODULE}\", version \"${SWMOD_MODVER}\"." 1>&2


	if [ -d "${SWMOD_MODULE}" ] ; then
		# echo "DEBUG: Full path to module specified." 1>&2
		swmod_findversion_indir "$SWMOD_MODULE" "$SWMOD_MODVER"
		if [ "${SWMOD_PREFIX}" != "" ] ; then return; fi
	fi

	if [ "${SWMOD_PREFIX}" == "" ] ; then
		# echo "DEBUG: Searching for module." 1>&2

		while read -d ':' dir; do
			if [ -d "${dir}" ]; then
				# echo "DEBUG: Checking module dir \"${dir}\"" 1>&2
				if [ -d "${dir}/${SWMOD_MODULE}" ]; then
					swmod_findversion_indir "${dir}/${SWMOD_MODULE}" "$SWMOD_MODVER"
					if [ "${SWMOD_PREFIX}" != "" ] ; then
						return;
					fi
				fi
			fi
		done < <( echo "${SWMOD_MODPATH}:" )
	fi
}


# == init subcommand ==================================================

if [ "${SWMOD_COMMAND}" == "init" ] ; then
	## Set aliases ##

	alias swmod='source swmod.sh'

	
	## Determine default install location ##

	if [ "${SWMOD_INST_MODULE}" == "" ] ; then
		if [ -d "${HOME}/.local/hspec" ] ; then
			# Legacy ~/.local/hspec support.
			export SWMOD_INST_MODULE="${HOME}/.local/hspec"
			export SWMOD_INST_VERSION=
		else
			# New standard module ~/.local/swmod/default
			export SWMOD_INST_MODULE="${HOME}/.local/sw/default"
			export SWMOD_INST_VERSION=
		fi
	fi

	
	## Determine create default install directories ##

	source swmod.sh setinst "${SWMOD_INST_MODULE}" "${SWMOD_INST_VERSION}"

	mkdir -p "${SWMOD_INST_PREFIX}/bin"
	mkdir -p "${SWMOD_INST_PREFIX}/lib"

	source swmod.sh load "${SWMOD_INST_MODULE}" "${SWMOD_INST_VERSION}" 2> /dev/null

	
	## Clear variables and return ##
	
	SWMOD_COMMAND=
	
	return 0
fi



# == load subcommand ==================================================

if [ "${SWMOD_COMMAND}" == "load" ] ; then
	## Parse arguments ##

	SWMOD_MODSPEC=$1

	if [ "${SWMOD_MODSPEC}" == "" ] ; then
		echo "Syntax: swmod load MODULE[@VERSION]"
		echo
		echo "You may specify either the full module path or just the" \
			 "module name, in which case swmod will look for the module in" \
			 "the directories specified by the SWMOD_MODPATH environment variable"
		return 1
	fi


	## Detect prefix ##

	swmod_getprefix "${SWMOD_MODSPEC}"

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
	fi

	
	## Clear variables and return ##
	
	SWMOD_PREFIX=
	SWMOD_MODULE=
	SWMOD_MODVER=
	
	return 0
fi



# == setinst subcommand ==================================================

if [ "${SWMOD_COMMAND}" == "setinst" ] ; then
	## Parse arguments ##

	SWMOD_MODULE=$1
	SWMOD_MODVER=$2

	if [ "${SWMOD_MODULE}" == "" ] ; then
		echo "Syntax: swmod setinst SWMOD_MODULE [MODULE_VERSION]"
		echo
		echo "You may specify either the full module path or just the" \
			 "module name, in which case swmod will look for the module in" \
			 "the directories specified by the SWMOD_MODPATH environment variable"
		return 1
	fi

	export SWMOD_INST_MODULE="${SWMOD_MODULE}"
	export SWMOD_INST_VERSION="${SWMOD_MODVER}"

	if [ "${SWMOD_INST_MODULE}" != "" ] ; then
		export SWMOD_INST_PREFIX="${SWMOD_INST_MODULE}/${HOSTSPEC}"
		if [ "${SWMOD_INST_VERSION}" != "" ] ; then
			export SWMOD_INST_PREFIX="${SWMOD_INST_PREFIX}/${SWMOD_INST_VERSION}"
		fi
	fi

	
	## Clear variables and return ##
	
	SWMOD_MODULE=
	SWMOD_MODVER=
	
	return 0
fi



# == configure subcommand =============================================

if [ X`basename "${SWMOD_COMMAND}"` == X"configure" ] ; then
	CONFIGURE="${SWMOD_COMMAND}"
	shift 1

	if [ "${CONFIGURE}" == "configure" ] ; then
		CONFIGURE="./configure"
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


	## Clear variables and return ##

	CONFIGURE=
	
	return 0
fi


# == unknown command ==================================================

echo -e >&2 "\nError: Unknown command \"${SWMOD_COMMAND}\"."
return 1

