# Build environment for SWRT/asuswrt Blue Cave (Lantiq GRX350).
# The bundled Lantiq toolchain is x86 Linux, so this image must be linux/amd64.
FROM --platform=linux/amd64 ubuntu:18.04

ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8
RUN dpkg --add-architecture i386 && apt-get update && apt-get install -y --no-install-recommends \
      build-essential g++ gcc-multilib g++-multilib libncurses5 libncurses5-dev m4 bison gawk flex \
      gengetopt git zlib1g-dev autoconf autopoint gettext libtool shtool autogen automake \
      mtd-utils intltool sharutils docbook-xsl docbook-xsl-ns texinfo dos2unix xsltproc \
      u-boot-tools device-tree-compiler python python3 gperf liblzo2-dev uuid-dev \
      lzma lzma-dev liblzma-dev binutils-dev patch cmake libglib2.0-dev gtk-doc-tools \
      pkg-config bc cpio rsync wget unzip file bzip2 xz-utils ca-certificates sudo vim-tiny \
      libc6-i386 lib32stdc++6 lib32z1 libc6-dev-i386 libelf1:i386 libncurses5:i386 \
      zlib1g:i386 libstdc++6:i386 \
  && rm -rf /var/lib/apt/lists/*

# asuswrt build scripts assume /bin/sh is bash
RUN ln -sf bash /bin/sh

RUN useradd -m -s /bin/bash builder && echo 'builder ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/builder
USER builder
WORKDIR /home/builder
# build scripts call git (version stamping); give it a generic identity
RUN git config --global user.name builder && git config --global user.email builder@localhost \
 && git config --global --add safe.directory '*'
