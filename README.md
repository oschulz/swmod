swmod - A Simple Software Module Management Tool
================================================

swmod is a simple tool to manage custom compiled software (in your home
directory or a central location). It handles software as "modules" - modules
can be loaded, and new software packages can be installed into a module.

Basically, swmod sets environment variables like `PATH` and `LD_LIBRARY_PATH`
and can automatically supply options like `--prefix` to configure scripts.

swmod is currently only tested with bash, but should work with other
`sh`-compatible shells. There are no plans to support `tcsh` or similar,
so far.


Installing swmod
----------------

Copy the shell scripts `hostspec` and `swmod.sh` from `src` into

    $HOME/.local/bin

and add the following to your `.bashrc` (resp. `.profile`):

    export PATH="$HOME/.local/bin:$PATH".
    . swmod.sh init

You may, of course, use any other directory in your `$PATH` instead of
`$HOME/.local/bin`.


Using swmod
-----------

### Building and installing software-packages

Fist, specify the installation target module, e.g.:

    # swmod setinst mysoftware@1.2.3

This is the module (here, module "mysoftware", version "1.2.3"), into which
you want to install your software. You can specify a new module, or add more
software packages to an existing module.

Module versions (like "1.2.3", "testing", "development", etc.) are optional,
but very useful. By default, the module will be created under the path
`$HOME/.local/sw/`.

The software package(s) you want to install into your module ("mysoftware", in
this example) may depend on other software to build and to run. You can
permanently add dependencies on other modules to the target module:

    # swmod adddeps some_dep@1.0.1 some_other_dep@1.2.0
    
This way, the correct versions  of your dependencies will be automatically
loaded when you load your module:

    # swmod load mysoftware@1.2.3

Now, configure, build and install your software. Using `swmod ./configure`
instead of just `.configure` will set the correct install prefix (`configure`
must support the usual options like `--prefix` for this to work).

    # swmod ./configure
    # make && make install && echo OK

Afterwards, you should find a directory structure like this (depending on your
system and the software package(s) you installed):

* `$HOME/.local/sw/mysoftware/linux-ubuntu-12.04-x86_64/1.2.3/bin`
* `$HOME/.local/sw/mysoftware/linux-ubuntu-12.04-x86_64/1.2.3/lib`
* ...

You can also use

    # swmod .../SOME_SRC_PATH/configure

for Autoconf/Automake out-of-tree builds.

Currently, swmod only supports Autoconf out of the box. If the software package
you are installing uses `scons`, `cmake` or another system, you will have to
pass the installation target directory to the build system manually.
`swmod setinst` exports an environment variable `SWMOD_INST_PREFIX` which you
can use for this purpose.


### Loading software modules

Just run

    # swmod load mysoftware

or

    # swmod load mysoftware@1.2.3

if you are using versions and want to load a specific one. Otherwise swmod will
try to guess which  version is the current one. For numerical versions, it is
legal to specify only a part of the version number:

    # swmod load mysoftware@1.2

Again, swmod will try to do the right thing.


Important: In shell scripts (like `.bashrc`) you have to use

    . swmod.sh load ...

instead of

    swmod load ...

since the `swmod` alias that is set up by `source swmod.sh init` does not work in
shell scripts.


### Module-specific init scripts

If your software module requires special initialization, environment variables,
etc., a create shell script named `swmodrc.sh` inside `$SWMOD_INST_PREFIX`.
`swmod load` will source this script - after loading the dependencies of the
module, but before modifying environment variables (`PATH`, ...) for the module
itself. Environment variables already modified by `swmodrc.sh` are skipped by
swmod afterwards, instead of changing them in the usual fashion.

The variable `SWMOD_INST_PREFIX` is available from within `swmodrc.sh`. Also,
the command `swmod_load` is available from within `swmodrc.sh`, to manually
load other modules.

For example, if the software in question already provides a script like
`bin/env.sh`, to set all paths and so on, just create an `swmodrc.sh`
containing

    . "$SWMOD_PREFIX/bin/env.sh"

inside the `$SWMOD_INST_PREFIX` directory.
