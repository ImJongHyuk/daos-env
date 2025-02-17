#!/bin/bash

set -e

# Check environment variables
if [[ -z "$DAOS_HOME" ]]; then
  echo "Error: DAOS_HOME is not set."
  echo "Please run: . ./daosenv <root_project_directory>"
  exit 1
fi

# Global variables
PROJECT_HOME=$DAOS_HOME
BUILD_DIR=$PROJECT_HOME/build
DAOS_RELEASE=2.6
REQUIRED_GO_VERSION="1.23.4"
FIO_DIR=/usr/src/fio
SPDK_REPO_URL="https://github.com/spdk/spdk.git"
SPDK_DIR=$BUILD_DIR/spdk
DAOS_REPO_URL="https://github.com/daos-stack/daos.git"
DAOS_REPO_DIR=$BUILD_DIR/daos
DAOS_INSTALL_DIR="$BUILD_DIR/daos/install"
FORCE_INSTALL=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --force)
      FORCE_INSTALL=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Utility functions
version_ge() {
  [ "$(printf '%s\n' "$@" | sort -V | head -n 1)" = "$2" ]
}

is_go_installed() {
  if ! command -v go &> /dev/null; then
    return 1
  fi
  current_version=$(go version | awk '{print $3}' | sed 's/go//')
  version_ge "$current_version" "$REQUIRED_GO_VERSION"
}

is_fio_installed() {
  if ! command -v fio &> /dev/null; then
    return 1
  fi
  # Check if FIO is installed in /usr/local/bin
  if [ ! -f "/usr/local/bin/fio" ]; then
    return 1
  fi
  return 0
}

is_spdk_installed() {
  if [ ! -d "/usr/local/spdk" ]; then
    return 1
  fi
  # Check SPDK library
  if [ ! -f "/usr/local/spdk/lib/libspdk.so" ]; then
    return 1
  fi
  return 0
}

is_daos_installed() {
  if [ ! -d "$DAOS_INSTALL_DIR" ]; then
    return 1
  fi
  # Check DAOS binary
  if [ ! -f "$DAOS_INSTALL_DIR/bin/daos_server" ]; then
    return 1
  fi
  return 0
}

install_go() {
  if ! $FORCE_INSTALL && is_go_installed; then
    echo "Go $REQUIRED_GO_VERSION or higher is already installed. Skipping..."
    return 0
  fi

  echo "Installing Go $REQUIRED_GO_VERSION..."
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

build_and_install_spdk() {
  if ! $FORCE_INSTALL && is_spdk_installed; then
    echo "SPDK is already installed. Skipping..."
    return 0
  fi

  echo "Building and installing SPDK..."
  set -e
  make -j$(nproc)
  make install
  echo "SPDK build and install completed."
}

run_spdk_setup() {
  echo "Running SPDK setup script..."
  /usr/share/spdk/scripts/setup.sh || echo "SPDK setup encountered an error."
  echo "SPDK setup script completed."
}

# Start main script
cd $PROJECT_HOME
mkdir -p $BUILD_DIR

# Check system architecture
arch=$(uname -i)

# Install dependencies
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

# Install Go
install_go

# Install FIO
if ! $FORCE_INSTALL && is_fio_installed; then
  echo "FIO is already installed. Skipping..."
else
  echo "Installing FIO..."
  if [ ! -d "$FIO_DIR" ]; then
    echo "Cloning FIO repository into $FIO_DIR..."
    git clone https://github.com/axboe/fio.git "$FIO_DIR"
  fi
  cd $FIO_DIR
  make -j$(nproc)
  make install
  cd $PROJECT_HOME
fi

# Install SPDK
if ! $FORCE_INSTALL && is_spdk_installed; then
  echo "SPDK is already installed. Skipping..."
else
  if [ ! -d "$SPDK_DIR" ]; then
    echo "Cloning SPDK repository..."
    git clone "$SPDK_REPO_URL" "$SPDK_DIR"
  fi
  cd $SPDK_DIR
  git submodule update --init --recursive
  ./scripts/pkgdep.sh
  ./configure --with-rdma --with-fio --prefix=/usr/local/spdk
  build_and_install_spdk
  mkdir -p /usr/share/spdk/scripts
  cp -r scripts/* /usr/share/spdk/scripts
  run_spdk_setup
  cd $PROJECT_HOME
fi

# Install DAOS
if ! $FORCE_INSTALL && is_daos_installed; then
  echo "DAOS is already installed. Skipping..."
else
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
fi

echo "Script execution completed successfully."
