#!/bin/bash -ue
#
# This script will try to set up an environment with several of Facebook's
# open source components.
#
# Everything will be done relative to FBCODE_PREFIX, which must be set in
# the environment before this script is run.

FBCODE_PREFIX=${FBCODE_PREFIX-}
export FBCODE_PREFIX

log() {
    echo "[$0]: $*" >&2
}

die() {
    log "$*"
    exit 1
}

ensure_root() {
    if [ "$(id -u)" != "0" ]; then
        die This script must be run as root
    fi
}

setup_system_libraries() {
    apt-get update && apt-get install -y \
        autoconf \
        autoconf-archive \
        build-essential \
        g++ \
        cmake \
        zlib1g-dev \
        libzstd-dev \
        libboost-all-dev \
        libgoogle-glog-dev \
        libdouble-conversion-dev \
        libssl-dev \
        libsodium-dev \
        libbison-dev \
        flex \
        libgflags-dev \
        libevent-dev \
        git \
        gperf \
        wget \
        unzip \

}

sanity_check() {
    if ! grep -q "bionic" /etc/apt/sources.list; then
        die This script is expected to only run on Ubuntu 18.04 instances
    fi
}

get_install_order() {
    tsort << 'EOF'
folly wangle
folly fizz
fizz wangle
wangle thrift
wangle proxygen
proxygen thrift
mstch thrift
rsocket thrift
EOF
}

find_latest_tag() {
    local tag_file="${FBCODE_PREFIX}/build/first_tag";
    if [ ! -f "$tag_file" ]; then
        mkdir -p $(dirname "$tag_file")
        git tag -l "v$(date +%Y.%m)*" | tail -n 1 | tee $tag_file
    else
        cat "$tag_file"
    fi
}

assert_has_commit() {
    local dir=$1
    local commit=$2
    pushd $dir >/dev/null
    if !git merge-base --is-ancestor "$commit" HEAD; then
        die "Expected to have commit $commit in $dir"
    fi
    popd >/dev/null
}

CMAKE_ARGS="-DCMAKE_PREFIX_PATH=${FBCODE_PREFIX} -DCMAKE_INSTALL_PREFIX=${FBCODE_PREFIX} -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_POSITION_INDEPENDENT_CODE=On"
LDFLAGS="-Wl,-rpath=$FBCODE_PREFIX/lib ${LDFLAGS-}"
PKG_CONFIG_PATH="${FBCODE_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH-}"

export LDFLAGS
export PKG_CONFIG_PATH

install_folly() {
    [ -e "$FBCODE_PREFIX/build/folly/Makefile" ] && return
    git clone https://github.com/facebook/folly "$FBCODE_PREFIX/src/folly"
    cd "$FBCODE_PREFIX/src/folly"
    git reset --hard $(find_latest_tag)
    mkdir -p "$FBCODE_PREFIX/build/folly" && cd "$FBCODE_PREFIX/build/folly"
    cmake $CMAKE_ARGS "$FBCODE_PREFIX/src/folly"
    make -j $(nproc)
    make install
}

install_wangle() {
    log "Installing wangle"
    [ -e "$FBCODE_PREFIX/build/wangle/Makefile" ] && return
    git clone https://github.com/facebook/wangle.git "$FBCODE_PREFIX/src/wangle"
    cd "$FBCODE_PREFIX/src/wangle"
    git reset --hard $(find_latest_tag)
    mkdir -p "$FBCODE_PREFIX/build/wangle" && cd "$FBCODE_PREFIX/build/wangle"
    cmake $CMAKE_ARGS "$FBCODE_PREFIX/src/wangle/wangle"
    make -j $(nproc)
    make install
}

install_mstch() {
    [ -e "$FBCODE_PREFIX/build/mstch/Makefile" ] && return
    git clone https://github.com/no1msd/mstch.git "$FBCODE_PREFIX/src/mstch"
    mkdir -p "$FBCODE_PREFIX/build/mstch" && cd "$FBCODE_PREFIX/build/mstch"
    cmake $CMAKE_ARGS "$FBCODE_PREFIX/src/mstch"
    make -j $(nproc)
    make install
}

install_fizz() {
    [ -e "$FBCODE_PREFIX/build/fizz/Makefile" ] && return
    git clone https://github.com/facebookincubator/fizz "$FBCODE_PREFIX/src/fizz"
    cd "$FBCODE_PREFIX/src/fizz"
    git reset --hard $(find_latest_tag)
    mkdir -p "$FBCODE_PREFIX/build/fizz" && cd "$FBCODE_PREFIX/build/fizz"
    cmake $CMAKE_ARGS "$FBCODE_PREFIX/src/fizz/fizz"
    make -j $(nproc)
    make install
}

install_thrift() {
    [ -e "$FBCODE_PREFIX/build/thrift/Makefile" ] && return

    # For now, use my fork of fbthrift which has perf build support
    if [ ! -d "$FBCODE_PREFIX/src/thrift" ] ; then
        git clone -b perf_build https://github.com/mingtaoy/fbthrift.git "$FBCODE_PREFIX/src/thrift"
    fi

    cd "$FBCODE_PREFIX/src/thrift"
    mkdir -p "$FBCODE_PREFIX/build/thrift" && cd "$FBCODE_PREFIX/build/thrift"
    cmake $CMAKE_ARGS "$FBCODE_PREFIX/src/thrift"
    make -j $(nproc)
    make install
}

install_proxygen() {
    [ -e "$FBCODE_PREFIX/src/proxygen/proxygen/configure" ] && return
    if [ ! -d "$FBCODE_PREFIX/src/proxygen" ]; then
        git clone https://github.com/facebook/proxygen.git "$FBCODE_PREFIX/src/proxygen"
        assert_has_commit "$FBCODE_PREFIX/src/proxygen" 49727c7f7358b8eaa99cf2c1d910eea7cfb579d0
    fi

    cd "$FBCODE_PREFIX/src/proxygen/proxygen"
    autoreconf -ivf

    # Proxygen's autoconf script doesn't properly handle finding folly...
    # so need to specify this manually.
    env \
        CPPFLAGS="-I${FBCODE_PREFIX}/include" \
        LDFLAGS="-L${FBCODE_PREFIX}/lib" \
        ./configure --prefix=${FBCODE_PREFIX}
    make -j $(nproc)
    make install
}


install_rsocket() {
    [ -e "$FBCODE_PREFIX/lib/cmake/rsocket"] && return
    if [ ! -d "$FBCODE_PREFIX/src/rsocket" ] ; then
        git clone https://github.com/rsocket/rsocket-cpp.git "$FBCODE_PREFIX/src/rsocket"
        assert_has_commit "$FBCODE_PREFIX/src/rsocket" 752a99fecde36047299bb3f82f11abb6373206bc
    fi

    if [ ! -d "$FBCODE_PREFIX/build/rsocket" ]; then
        mkdir -p "$FBCODE_PREFIX/build/rsocket"
        cd "$FBCODE_PREFIX/build/rsocket"
        cmake $CMAKE_ARGS -DBUILD_TESTS=No -DBUILD_BENCHMARKS=No -DBUILD_EXAMPLES=no "$FBCODE_PREFIX/src/rsocket/"
        make -j $(nproc)
        make install
    fi
}

setup_fb_components() {
    set -x
    local order=$(get_install_order)
    for item in $order; do
        (
            set -ue
            "install_$item"
        )
    done
    set +x
}

if [ -z "$FBCODE_PREFIX" ]; then
    die "FBCODE_PREFIX is not set. Refusing to run".
fi

mkdir -p "$FBCODE_PREFIX/src" "$FBCODE_PREFIX/build"

ensure_root
sanity_check
setup_system_libraries
setup_fb_components

