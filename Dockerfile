FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV HOST=x86_64-w64-mingw32

# 安装构建工具和依赖
RUN apt update && apt install -y \
    autoconf automake libtool make g++ git \
    mingw-w64 cmake perl python3 \
    pkg-config zlib1g-dev libxml2-dev libcppunit-dev \
    ca-certificates curl unzip

# 设置交叉编译环境变量
ENV CC=${HOST}-gcc
ENV CXX=${HOST}-g++
ENV AR=${HOST}-ar
ENV RANLIB=${HOST}-ranlib
ENV STRIP=${HOST}-strip

WORKDIR /build

# 下载并编译 OQS-OpenSSL（支持 X25519+ML-KEM768）
RUN git clone --branch OQS-1.1.1 https://github.com/open-quantum-safe/openssl.git oqs-openssl && \
    cd oqs-openssl && \
    ./Configure mingw64 no-shared --cross-compile-prefix=${HOST}- --prefix=/usr/${HOST} && \
    make -j$(nproc) && make install_sw

# 下载并编译 aria2
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
