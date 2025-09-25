FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV HOST=x86_64-w64-mingw32

# 安装构建工具和依赖
RUN apt update && apt install -y \
    autoconf automake libtool make g++ git \
    mingw-w64 cmake perl python3 \
    pkg-config zlib1g-dev libxml2-dev libcppunit-dev \
    libssl-dev ca-certificates curl unzip ninja-build

# 升级 CMake（Ubuntu 默认版本过旧）
RUN curl -LO https://github.com/Kitware/CMake/releases/download/v3.27.7/cmake-3.27.7-linux-x86_64.sh && \
    chmod +x cmake-3.27.7-linux-x86_64.sh && \
    ./cmake-3.27.7-linux-x86_64.sh --skip-license --prefix=/usr/local

# 设置交叉编译环境变量
ENV CC=${HOST}-gcc
ENV CXX=${HOST}-g++
ENV AR=${HOST}-ar
ENV RANLIB=${HOST}-ranlib
ENV STRIP=${HOST}-strip

WORKDIR /build

# 编译 liboqs（使用官方工具链）
RUN git clone https://github.com/open-quantum-safe/liboqs.git && \
    cd liboqs && \
    mkdir build && cd build && \
    cmake -GNinja \
          -DCMAKE_TOOLCHAIN_FILE=../.CMake/toolchain_windows-amd64.cmake \
          -DOQS_DIST_BUILD=ON \
          -DBUILD_SHARED_LIBS=OFF \
          -DCMAKE_INSTALL_PREFIX=/usr/${HOST} .. && \
    ninja && ninja install

# 编译 OpenSSL 3（静态链接 liboqs）
RUN git clone --branch master https://github.com/openssl/openssl.git && \
    cd openssl && \
    ./Configure mingw64 no-shared --cross-compile-prefix=${HOST}- \
        --with-liboqs=/usr/${HOST} \
        --prefix=/usr/${HOST} && \
    make -j$(nproc) && make install_sw

# 编译 oqs-provider（链接 OpenSSL 和 liboqs）
RUN git clone --branch main https://github.com/open-quantum-safe/oqs-provider.git && \
    cd oqs-provider && \
    cmake -GNinja \
          -DOQS_PROVIDER_OPENSSL_DIR=/usr/${HOST} \
          -DOQS_PROVIDER_LIBOQS_DIR=/usr/${HOST} \
          -DCMAKE_TOOLCHAIN_FILE=../liboqs/.CMake/toolchain_windows-amd64.cmake \
          -DCMAKE_INSTALL_PREFIX=/usr/${HOST} . && \
    ninja && ninja install

# 编译 aria2（使用 OpenSSL + oqs-provider）
RUN git clone https://github.com/aria2/aria2.git && \
    cd aria2 && \
    autoreconf -i && \
    ./configure \
      --host=${HOST} \
      --build=$(gcc -dumpmachine) \
      --with-openssl=/usr/${HOST} \
      --without-gnutls \
      --disable-nls \
      --enable-static \
      --disable-shared \
      --prefix=/aria2-win && \
    make -j$(nproc) && make install

# 输出构建结果
CMD ["bash"]
