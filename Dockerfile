# ============================
# 🧱 Stage 1: Build toolchain
# ============================
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV PREFIX=/opt/target
ENV OPENSSL_VERSION=3.3.0

RUN apt-get update && apt-get install -y \
  build-essential \
  cmake \
  ninja-build \
  git \
  curl \
  wget \
  autoconf \
  automake \
  libtool \
  pkg-config \
  mingw-w64 \
  perl \
  nasm \
  python3 \
  gettext \
  && rm -rf /var/lib/apt/lists/*

# 🧱 Build liboqs
WORKDIR /build/liboqs
RUN git clone --recursive https://github.com/open-quantum-safe/liboqs.git .
RUN mkdir build && cd build && \
  cmake -G Ninja .. \
    -DCMAKE_TOOLCHAIN_FILE=../cmake/toolchain-mingw64.cmake \
    -DCMAKE_INSTALL_PREFIX=${PREFIX} \
    -DCMAKE_BUILD_TYPE=Release && \
  ninja && ninja install

# 🔐 Build OpenSSL
WORKDIR /build/openssl
RUN git clone https://github.com/openssl/openssl.git .
RUN git checkout openssl-${OPENSSL_VERSION}
RUN ./Configure mingw64 no-shared --cross-compile-prefix=x86_64-w64-mingw32- --prefix=${PREFIX} \
    -I${PREFIX}/include -L${PREFIX}/lib && \
  make -j$(nproc) && make install_sw

# 🔐 Build oqs-provider
WORKDIR /build/oqs-provider
RUN git clone https://github.com/open-quantum-safe/oqs-provider.git .
RUN cmake -G Ninja . \
    -DCMAKE_TOOLCHAIN_FILE=cmake/toolchain-mingw64.cmake \
    -DCMAKE_INSTALL_PREFIX=${PREFIX} \
    -DOPENSSL_ROOT_DIR=${PREFIX} \
    -Dliboqs_DIR=${PREFIX}/lib/cmake/liboqs \
    -DCMAKE_BUILD_TYPE=Release && \
  ninja && ninja install

# 🚀 Build aria2
WORKDIR /build/aria2
RUN git clone https://github.com/aria2/aria2.git .
RUN autoreconf -i
RUN ./configure \
    --host=x86_64-w64-mingw32 \
    --with-openssl \
    --without-gnutls \
    --enable-static=yes \
    --enable-shared=no \
    --disable-websocket \
    --without-libxml2 \
    --without-libssh2 \
    --without-sqlite3 \
    --without-cares \
    CPPFLAGS="-I${PREFIX}/include" \
    LDFLAGS="-L${PREFIX}/lib" \
    PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"
RUN make -j$(nproc)

# ============================
# 🎯 Stage 2: Output binary
# ============================
FROM scratch AS output

COPY --from=builder /build/aria2/src/aria2c.exe /aria2c.exe
