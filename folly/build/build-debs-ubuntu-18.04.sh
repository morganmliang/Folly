#!/bin/sh -x
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Note: this script was written on Ubuntu 18.04 and will need work in order to
# work on additional platforms. This is left as an exercise for the reader.

set -e

BUILD_DIR=${BUILD_DIR:-_build}
BOOST_VERSION=${BOOST_VERSION:-1.65.1}
LIBEVENT_VERSION=${LIBEVENT_VERSION:-2.0-5}
SSL_VERSION=${SSL_VERSION:-1.0.0}

VERSION_FILE_PATH=folly/VERSION
VERSION=${VERSION:-"$(sed 's/:/./' ${VERSION_FILE_PATH})"}
ITERATION=${ITERATION:-1}

DESTDIR=${DESTDIR:-$(mktemp -d)}
DEBUGDIR=${DEBUGDIR:-$DESTDIR/usr/lib/debug}
PKGDIR=${PKGDIR:-/tmp}

DESC="Folly is an open-source C++ library developed and used at Facebook
  as a foundation for our infrastructure."
URL=https://github.com/facebook/folly
LICENSE="Apache License v2.0"
MAINTAINER="Folly Eng"

command -v fpm || (echo "Please install fpm from https://github.com/jordansissel/fpm" && exit 1)
[ -d "$DESTDIR" ]

command -v cmake || (echo "Please install cmake." && exit 1)

# Make
rm -rf "${BUILD_DIR}"
mkdir "${BUILD_DIR}"
cd "${BUILD_DIR}"
cmake ..
make
make install DESTDIR="$DESTDIR"

# Move symbols to debug file
[ -d "$DEBUGDIR/usr/lib" ] || mkdir -p "$DEBUGDIR/usr/lib"
find "$DESTDIR/usr/lib" -maxdepth 1 -iname "lib*.so.*" -type f \
  -execdir objcopy --only-keep-debug {} "$DEBUGDIR/usr/lib/{}.debug" \; \
  -execdir strip --strip-debug --strip-unneeded {} \; \
  -execdir objcopy --add-gnu-debuglink "$DEBUGDIR/usr/lib/{}.debug" {} \;

# Build debs
fpm \
  -s dir -t deb \
  -n "libfolly$VERSION" \
  -v "$VERSION" --iteration "$ITERATION" \
  -p "$PKGDIR/NAME_VERSION-ITERATION_ARCH.deb" \
  -C "$DESTDIR" \
  --description "$DESC" \
  --vendor Facebook \
  --url "$URL" \
  --license "$LICENSE" \
  --maintainer "$MAINTAINER" \
  --category libs \
  --provides libfolly \
  --depends libc6 \
  --depends libstdc++6 \
  --depends libboost-context"$BOOST_VERSION" \
  --depends libboost-filesystem"$BOOST_VERSION" \
  --depends libboost-program-options"$BOOST_VERSION" \
  --depends libboost-regex"$BOOST_VERSION" \
  --depends libboost-system"$BOOST_VERSION" \
  --depends libboost-thread"$BOOST_VERSION" \
  --depends libdouble-conversion1 \
  --depends libevent-"$LIBEVENT_VERSION" \
  --depends libgflags2 \
  --depends libgoogle-glog0 \
  --depends libicu52 \
  --depends libjemalloc1 \
  --depends liblz4-1 \
  --depends liblzma5 \
  --depends libsnappy1 \
  --depends libssl"$SSL_VERSION" \
  --depends zlib1g \
  --exclude usr/lib/debug \
  --exclude usr/lib/*.a \
  --exclude usr/lib/*.la \
  usr/lib

fpm \
  -s dir -t deb \
  -n libfolly-dev \
  -v "$VERSION" --iteration "$ITERATION" \
  -p "$PKGDIR/NAME_VERSION-ITERATION_ARCH.deb" \
  -C "$DESTDIR" \
  --description "$DESC" \
  --vendor Facebook \
  --url "$URL" \
  --license "$LICENSE" \
  --maintainer "$MAINTAINER" \
  --category devel \
  --depends "libfolly$VERSION" \
  --exclude usr/lib/*.so* \
  usr/include \
  usr/lib/debug

echo "${DESTDIR}"

