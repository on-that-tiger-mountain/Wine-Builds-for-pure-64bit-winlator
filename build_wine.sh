
#!/usr/bin/env bash

########################################################################
##
## A script for Wine compilation.
## By default it uses two Ubuntu bootstraps (x32 and x64), which it enters
## with bubblewrap (root rights are not required).
##
## This script requires: git, wget, autoconf, xz, bubblewrap
##
## You can change the environment variables below to your desired values.
##
########################################################################

# Prevent launching as root
if [ $EUID = 0 ] && [ -z "$ALLOW_ROOT" ]; then
        echo "Do not run this script as root!"
        echo
        echo "If you really need to run it as root and you know what you are doing,"
        echo "set the ALLOW_ROOT environment variable."

        exit 1
fi

# Wine version to compile.
# You can set it to "latest" to compile the latest available version.
# You can also set it to "git" to compile the latest git revision.
#
# This variable affects only vanilla and staging branches. Other branches
# use their own versions.
export WINE_VERSION="${WINE_VERSION:-latest}"

# Available branches: vanilla, staging, staging-tkg, proton, wayland
export WINE_BRANCH="${WINE_BRANCH:-staging}"

# Available proton branches: proton_3.7, proton_3.16, proton_4.2, proton_4.11
# proton_5.0, proton_5.13, experimental_5.13, proton_6.3, experimental_6.3
# proton_7.0, experimental_7.0, proton_8.0, experimental_8.0, experimental_9.0
# bleeding-edge
# Leave empty to use the default branch.
export PROTON_BRANCH="${PROTON_BRANCH:-proton_8.0}"

# Sometimes Wine and Staging versions don't match (for example, 5.15.2).
# Leave this empty to use Staging version that matches the Wine version.
export STAGING_VERSION="${STAGING_VERSION:-}"

# Specify custom arguments for the Staging's patchinstall.sh script.
# For example, if you want to disable ntdll-NtAlertThreadByThreadId
# patchset, but apply all other patches, then set this variable to
# "--all -W ntdll-NtAlertThreadByThreadId"
# Leave empty to apply all Staging patches
export STAGING_ARGS="${STAGING_ARGS:-}"

# Make 64-bit Wine builds with the new WoW64 mode (32-on-64)
export EXPERIMENTAL_WOW64="${EXPERIMENTAL_WOW64:-false}"

# Set this to a path to your Wine source code (for example, /home/username/wine-custom-src).
# This is useful if you already have the Wine source code somewhere on your
# storage and you want to compile it.
#
# You can also set this to a GitHub clone url instead of a local path.
#
# If you don't want to compile a custom Wine source code, then just leave this
# variable empty.
export CUSTOM_SRC_PATH=""

# Set to true to download and prepare the source code, but do not compile it.
# If this variable is set to true, root rights are not required.
export DO_NOT_COMPILE="false"

# Set to true to use ccache to speed up subsequent compilations.
# First compilation will be a little longer, but subsequent compilations
# will be significantly faster (especially if you use a fast storage like SSD).
#
# Note that ccache requires additional storage space.
# By default it has a 5 GB limit for its cache size.
#
# Make sure that ccache is installed before enabling this.
export USE_CCACHE="false"

export WINE_BUILD_OPTIONS="--without-ldap --without-oss --disable-winemenubuilder --disable-win16 --disable-tests"

# A temporary directory where the Wine source code will be stored.
# Do not set this variable to an existing non-empty directory!
# This directory is removed and recreated on each script run.
export BUILD_DIR="${HOME}"/build_wine

# Change these paths to where your Ubuntu bootstraps reside
export BOOTSTRAP_X64=/opt/chroots/bionic64_chroot
export BOOTSTRAP_X32=/opt/chroots/bionic32_chroot

export scriptdir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

export CC="gcc-9"
export CXX="g++-9"

export CROSSCC_X32="i686-w64-mingw32-gcc"
export CROSSCXX_X32="i686-w64-mingw32-g++"
export CROSSCC_X64="x86_64-w64-mingw32-gcc"
export CROSSCXX_X64="x86_64-w64-mingw32-g++"

export CFLAGS_X32="-march=i686 -msse2 -mfpmath=sse -O2 -ftree-vectorize"
export CFLAGS_X64="-march=x86-64 -msse3 -mfpmath=sse -O2 -ftree-vectorize"
export LDFLAGS="-Wl,-O1,--sort-common,--as-needed"

export CROSSCFLAGS_X32="${CFLAGS_X32}"
export CROSSCFLAGS_X64="${CFLAGS_X64}"
export CROSSLDFLAGS="${LDFLAGS}"

if [ "$USE_CCACHE" = "true" ]; then
        export CC="ccache ${CC}"
        export CXX="ccache ${CXX}"

        export i386_CC="ccache ${CROSSCC_X32}"
        export x86_64_CC="ccache ${CROSSCC_X64}"

        export CROSSCC_X32="ccache ${CROSSCC_X32}"
        export CROSSCXX_X32="ccache ${CROSSCXX_X32}"
        export CROSSCC_X64="ccache ${CROSSCC_X64}"
        export CROSSCXX_X64="ccache ${CROSSCXX_X64}"

        if [ -z "${XDG_CACHE_HOME}" ]; then
                export XDG_CACHE_HOME="${HOME}"/.cache
        fi

        mkdir -p "${XDG_CACHE_HOME}"/ccache
        mkdir -p "${HOME}"/.ccache
fi

build_with_bwrap () {
        if [ "${1}" = "32" ]; then
                BOOTSTRAP_PATH="${BOOTSTRAP_X32}"
        else
                BOOTSTRAP_PATH="${BOOTSTRAP_X64}"
        fi

        if [ "${1}" = "32" ] || [ "${1}" = "64" ]; then
                shift
        fi

    bwrap --ro-bind "${BOOTSTRAP_PATH}" / --dev /dev --ro-bind /sys /sys \
                  --proc /proc --tmpfs /tmp --tmpfs /home --tmpfs /run --tmpfs /var \
                  --tmpfs /mnt --tmpfs /media --bind "${BUILD_DIR}" "${BUILD_DIR}" \
                  --bind-try "${XDG_CACHE_HOME}"/ccache "${XDG_CACHE_HOME}"/ccache \
                  --bind-try "${HOME}"/.ccache "${HOME}"/.ccache \
                  --setenv PATH "/bin:/sbin:/usr/bin:/usr/sbin" \
                        "$@"
}

if ! command -v git 1>/dev/null; then
        echo "Please install git and run the script again"
        exit 1
fi

if ! command -v autoconf 1>/dev/null; then
        echo "Please install autoconf and run the script again"
        exit 1
fi

if ! command -v wget 1>/dev/null; then
        echo "Please install wget and run the script again"
        exit 1
fi

if ! command -v xz 1>/dev/null; then
        echo "Please install xz and run the script again"
        exit 1
fi

cd /opt
wget -q --show-progress "https://dl.winehq.org/wine/source/9.x/wine-9.7.tar.xz"

tar xf "wine-9.7.tar.xz"
mv "wine-9.7" wine97
rm -f wine-9.7.tar.xz

mkdir /opt/wine97/build

/opt/wine97/configure --enable-archs=i386,x86_64 --prefix=/opt/wine-9.7-exp-amd64
make -C /opt/wine97/build install

cp /opt/wine-9.7-exp-amd64/bin/wine-preloader /opt/wine-9.7-exp-amd64/bin/wine64-preloader

cp /opt/wine-9.7-exp-amd64/bin/wine /opt/wine-9.7-exp-amd64/bin/wine64

tar -Jcf /opt/wine-9.7-exp-amd64.tar.xz /opt/wine-9.7-exp-amd64

rm -rf /opt/wine97

echo
echo "Done"

