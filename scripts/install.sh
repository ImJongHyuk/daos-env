#!/bin/bash

set -e

PROJECT_HOME=$(dirname $(realpath $0))/..
BUILD_DIR=$PROJECT_HOME/build
cd $PROJECT_HOME
mkdir -p $BUILD_DIR

arch=$(uname -i)
DAOS_RELEASE=2.6

echo "Updating package list and installing dependencies..."
sudo apt-get update
sudo apt-get install -y \
  autoconf \
  build-essential \
  clang \
  clang-format \
  cmake \
  curl \
  git \
  kmod \
  libaio-dev \
  libboost-dev \
  libcapstone-dev \
  libcmocka-dev \
  libcunit1-dev \
  libdaxctl-dev \
  libfuse3-dev \
  libhwloc-dev \
  libibverbs-dev \
  libiscsi-dev \
  libjson-c-dev \
  liblz4-dev \
  libndctl-dev \
  libnuma-dev \
  libopenmpi-dev \
  libpci-dev \
  libprotobuf-c-dev \
  librdmacm-dev \
  libssl-dev \
  libtool-bin \
  libunwind-dev \
  libyaml-dev \
  locales \
  maven \
  numactl \
  openjdk-8-jdk \
  patchelf \
  pciutils \
  pkg-config \
  python3-dev \
  python3-venv \
  uuid-dev \
  valgrind \
  yasm \
  scons

if [ "$arch" = x86_64 ]; then
  sudo apt-get install -y libipmctl-dev
fi

REQUIRED_GO_VERSION="1.23.4"

version_ge() {
  [ "$(printf '%s\n' "$@" | sort -V | head -n 1)" = "$2" ]
}

install_go() {
  mkdir -p "$BUILD_DIR/go-src" && cd "$BUILD_DIR/go-src"
  GO_TAR="go${REQUIRED_GO_VERSION}.linux-amd64.tar.gz"
  GO_DOWNLOAD_URL="https://go.dev/dl/$GO_TAR"
  
  wget "$GO_DOWNLOAD_URL"
  if [ ! -f "$GO_TAR" ]; then
    echo "Failed to download Go. Exiting."
    exit 1
  fi

  sudo tar -C /usr/local -xzf "$GO_TAR"
  cd "$PROJECT_HOME"
  
  if [ -e /usr/bin/go ] && [ ! -L /usr/bin/go ]; then
    sudo rm -rf /usr/bin/go
  fi
  sudo ln -sf /usr/local/go/bin/go /usr/bin/go
  echo "Go $REQUIRED_GO_VERSION installed successfully."
}

if command -v go &> /dev/null; then
  current_version=$(go version | awk '{print $3}' | sed 's/go//')
  if version_ge "$current_version" "$REQUIRED_GO_VERSION"; then
    echo "Go version $current_version is already installed. Skipping Go installation."
  else
    install_go
  fi
else
  install_go
fi

FIO_DIR=/usr/src/fio
if [ ! -d "$FIO_DIR" ]; then
  echo "Cloning FIO repository into $FIO_DIR..."
  git clone https://github.com/axboe/fio.git "$FIO_DIR"
fi
cd $FIO_DIR
make -j$(nproc)
make install
cd $PROJECT_HOME

SPDK_REPO_URL="https://github.com/spdk/spdk.git"
SPDK_DIR=$BUILD_DIR/spdk

if [ ! -d "$SPDK_DIR" ]; then
  echo "Cloning SPDK repository..."
  git clone "$SPDK_REPO_URL" "$SPDK_DIR"
fi
cd $SPDK_DIR
git submodule update --init --recursive
./scripts/pkgdep.sh
./configure --with-rdma --with-fio --prefix=/usr/local/spdk

build_and_install_spdk() {
  set -e
  make -j$(nproc)
  make install
  echo "SPDK build and install completed."
}

build_and_install_spdk || echo "SPDK installation failed, continuing..."

mkdir -p /usr/share/spdk/scripts
cp -r scripts/* /usr/share/spdk/scripts
run_spdk_setup() {
  echo "Running SPDK setup script..."
  /usr/share/spdk/scripts/setup.sh || echo "SPDK setup encountered an error."
  echo "SPDK setup script completed."
}

run_spdk_setup

cd $PROJECT_HOME

DAOS_REPO_URL="https://github.com/daos-stack/daos.git"
DAOS_REPO_DIR=$BUILD_DIR/daos

if [ ! -d "$DAOS_REPO_DIR" ]; then
  echo "Cloning DAOS repository..."
  git clone "$DAOS_REPO_URL" "$DAOS_REPO_DIR"
fi
cd $DAOS_REPO_DIR
git checkout release/${DAOS_RELEASE}
git submodule update --init --recursive
python3 -m pip --no-cache-dir install -r requirements-build.txt -r requirements-utest.txt

scons --build-deps=yes install
cd $PROJECT_HOME

echo "Script execution completed successfully."
