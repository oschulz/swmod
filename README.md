swmod - A Simple Software Module Management Tool
================================================

swmod is a simple tool to manage custom compiled software (in your home
directory or a central location). It handles software as "modules" - modules
can be loaded, and new software packages can be installed into a module.

Basically, swmod sets environment variables like `PATH` and `LD_LIBRARY_PATH`
and can automatically supply options like `--prefix` to configure scripts.

swmod is currently only works with bash, though it may in the future also
support other `sh`-compatible shells. There are no plans to support `tcsh` or
similar, so far.


Installing swmod
----------------

Copy the shell script `swmod.sh` from `bin` into (e.g.)

    $HOME/.local/bin

and add the following to your `.bashrc` (resp. `.profile`):

    export PATH="$HOME/.local/bin:$PATH"
    . swmod.sh init

You may, of course, use any other directory in your `$PATH` instead of
`$HOME/.local/bin`.


Using swmod
-----------

### Software Module Structure

Any directory structure of the form

    MODULE_NAME/`swmod hostspec`/MODULE_VERSION

that looks like a binary software installation (there's a `bin` or `lib`
directory or an `swmod.deps` file, etc.) can be used as an swmod software
module.

The output of the `swmod hostspec` command (part of swmod) is a system
specific string, e.g. "linux-ubuntu-12.04-x86_64", to support heterogeneous
computing environments. You can override it with the environment variable
`$SWMOD_HOSTSPEC`.

swmod looks for modules in all directories listed in the (colon-separated)
path `$SWMOD_MODPATH`. `$SWMOD_MODPATH` defaults to `$HOME/.local/sw/`.

So a typical user-installed module might look like this:

    $HOME/.local/sw/my-software/linux-ubuntu-12.04-x86_64/4.2

Of course, a module may comprise several individual software packages with the
same installation prefix.


### Loading Software Modules

Just run

    # swmod load mysoftware

or

    # swmod load mysoftware@1.2.3

if you want to load a specific one. Otherwise swmod will try to guess which
version is the current one. For numerical versions, it is legal to specify
only a part of the version number:

    # swmod load mysoftware@1.2

Again, swmod will try to do the right thing.


Important: In shell scripts (like `.bashrc`) you have to use

    . swmod.sh load ...

instead of

    swmod load ...

since the `swmod` alias that is set up by `source swmod.sh init` does not work
in shell scripts.


### Creating Software Modules

swmod compatible software module can be created simply by manually installing
(or copying) software packages into a prefix directory with a path of a
certain structure (see above). However, swmod also provides several tools
to assist with the installation of software packages into a module.

Fist, specify the installation target module and it's version, e.g.:

    # swmod target mysoftware@1.2.3

This is the module (here, module "mysoftware", version "1.2.3"), into which
you want to install your software. You can specify a new module, or add more
software packages to an existing module.

By default, the module will be created under the path `$HOME/.local/sw/`. You
can override the default installation base path with the environment variable
`$SWMOD_INST_BASE`.

To make things more comfortable, you can use `swmod target -l`, e.g.

    # swmod target -l mysoftware@1.2.3

as a shortcut for the frequently used combination

    # swmod target mysoftware@1.2.3
    # swmod load mysoftware@1.2.3

The software package(s) you want to install into your module ("mysoftware", in
this example) may depend on other software to build and to run. You can
permanently add dependencies on other modules to the target module using
`swmod add-deps`:

    # swmod add-deps some_dep@1.0.1 some_other_dep@1.2.0

This way, the correct versions  of your dependencies will be automatically
loaded when you load your module:

    # swmod load mysoftware@1.2.3

Use the `-l` option to immediately load the added dependencies, e.g.

    # swmod add-deps -l some_dep@1.0.1 some_other_dep@1.2.0

This comes in handy when adding dependencies to an already loaded module.

You may also add the special dependency `!clflags`. If added to a module, the
include and library directories in the module will be added with `-I` and `-L`
options to the environment variables `SWMOD_CPPFLAGS` and `SWMOD_LDFLAGS`.
`swmod configure` and similar try to pass these through to the build system of
packages to be configured or installed. Usually, this is not necessary as
modern software uses mechanisms like `...-config` or `pkg-config ...` to get
the necessary compiler and linker options for their dependencies. Where such
a mechanism is not provided, adding the special dependency `!clflags` can
help.

Now build and install the desired software package(s) into the module. swmod
has direct support for the following build systems:

* GNU Autotools (and compatible "configure" scripts)
* CMake
* Phyton setup.py

#### Installing GNU Autotools Projects

If the software package you want to install uses GNU Autoconf (and possibly
Automake) or provides a compatible "configure" script, run `swmod ./configure`
instead of `./configure`. `configure` must support the usual options like
`--prefix` for this to work. Then run `make` and `make install` as usual:

    # swmod ./configure
    # make && make install && echo OK

Afterwards, you should find a directory structure like this (depending on your
system and the software package(s) you installed):

* `$HOME/.local/sw/mysoftware/linux-ubuntu-14.04-x86_64/1.2.3/bin`
* `$HOME/.local/sw/mysoftware/linux-ubuntu-14.04-x86_64/1.2.3/lib`
* ...

You can also use

    # swmod path/to/project/dir/configure

for Autoconf/Automake out-of-tree builds (if supported by the project).

#### Installing CMake Projects

For CMake projects, use `swmod cmake` instead of `cmake`, then run `make` and
`make install` as usual:

    # cd my/build/dir
    # swmod cmake path/to/project/dir
    # make && make install && echo OK

#### Installing Python Projects with setup.py

To build and install Python projects based on "setup.py", use

    # swmod setup.py

swmod will run `python setup.py` with the correct `--prefix` option (and
also create the "site-packages" directory first, if necessary).


#### Installing Python Packages from PyPI

To download and install Python packages via `pip`, use

    # swmod pip install ...

This is equivalent to

    PYTHONUSERBASE="${SWMOD_INST_PREFIX}" pip install --user ...


#### Installing Projects Using Other Build Systems

If the software package you are installing uses SCons or another build system,
you have to pass the installation target directory to the build system
manually. `swmod target` exports an environment variable `SWMOD_INST_PREFIX`
that may come in handy.


### Module-Specific Init Scripts

If your software module requires special initialization, environment
variables, etc., a create shell script named `swmodrc.sh` inside
`$SWMOD_INST_PREFIX`. `swmod load` will source this script - after loading the
dependencies of the module, but before modifying environment variables
(`PATH`, ...) for the module itself. Environment variables already modified by
`swmodrc.sh` are skipped by swmod afterwards, instead of changing them in the
usual fashion.

The variable `SWMOD_INST_PREFIX` is available from within `swmodrc.sh`. Also,
the command `swmod_load` is available from within `swmodrc.sh`, to manually
load other modules.

For example, if the software in question already provides a script like
`bin/env.sh`, to set all paths and so on, just create a file `swmodrc.sh`
containing

    . "$SWMOD_PREFIX/bin/env.sh"

inside the `$SWMOD_INST_PREFIX` directory.
