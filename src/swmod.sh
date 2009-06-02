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

	source swmod.sh load "${SWMOD_INST_MODULE}" "${SWMOD_INST_VERSION}"

	
	## Clear variables and return ##
	
	SWMOD_COMMAND=
	
	return 0
fi



# == load subcommand ==================================================

if [ "${SWMOD_COMMAND}" == "load" ] ; then
	## Parse arguments ##

	SWMOD_MODULE=$1
	SWMOD_MODVER=$2

	if [ "${SWMOD_MODULE}" == "" ] ; then
		echo "Syntax: swmod load SWMOD_MODULE [MODULE_VERSION]"
		echo
		echo "You may specify either the full module path or just the" \
			 "module name, in which case swmod will look for the module in" \
			 "the directories specified by the SWMOD_PATH environment variable"
		return 1
	fi


	## Detect prefix ##

	SWMOD_PREFIX="${SWMOD_MODULE}/${HOSTSPEC}"

	if [ "${SWMOD_MODVER}" != "" ] ; then
		SWMOD_PREFIX="${SWMOD_PREFIX}/${SWMOD_MODVER}"
	fi
	if [ ! '(' -d "${SWMOD_PREFIX}/bin" ')' -a ! '(' -d "${SWMOD_PREFIX}/lib" ')' ]; then
		echo "Error: No suitable version of \"${SWMOD_MODULE}\", version \"${SWMOD_MODVER}\" for ${HOSTSPEC} found." 1>&2
		return 1
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
			 "the directories specified by the SWMOD_PATH environment variable"
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

