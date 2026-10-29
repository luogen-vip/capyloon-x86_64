#!/bin/bash
# Stage 1: Build Gecko (b2g) for x86_64 Linux from capyloon/gecko-b2g source.
# Produces: output/b2g-123.0.en-US.linux-x86_64.tar.bz2
set -euo pipefail

ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
mkdir -p "$ROOT/output"
cd "$ROOT"

echo "==== disk before build ===="
df -h / || true

echo "==== clone gecko-b2g (capyloon branch, shallow) ===="
if [ ! -d gecko ]; then
    git clone --depth 1 --branch capyloon https://github.com/capyloon/gecko-b2g.git gecko
fi
cd gecko

echo "==== install system build prerequisites ===="
sudo apt-get update -qq
sudo apt-get install -y -qq \
    build-essential curl git python3 python3-pip python3-dev \
    libgtk-3-dev libdbus-glib-1-dev libxt-dev libasound2-dev libpulse-dev \
    unzip xz-utils bzip2 uuid-dev m4 file wget clang lld llvm \
    libx11-dev libx11-xcb-dev libxcb1-dev libxcb-shm0-dev libxext-dev \
    libxrandr-dev libxcomposite-dev libxcursor-dev libxdamage-dev \
    libxfixes-dev libxi-dev libdrm-dev libegl1-mesa-dev libgles2-mesa-dev \
    libwayland-dev libwayland-egl-backend-dev yasm nasm

echo "==== toolchains (manual, bypasses broken b2g bootstrap) ===="
# gecko-b2g's 'mach bootstrap' has a bug in its b2g application branch
# (ensure_android() missing os_arch), so we set up toolchains manually.
# Gecko 123 era requires: rust ~1.76, cbindgen >= 0.26, clang >= 10, node >= 12.
# NOTE: rust 1.99 (2026) breaks gecko 123 configure ("Don't know how to
# translate x86_64-pc-linux-gnu for rustc"), hence the pinned version.
rustup toolchain install 1.76.0 --profile minimal 2>&1 | tail -1
export RUSTUP_TOOLCHAIN=1.76.0
rustc --version
if ! command -v cbindgen >/dev/null 2>&1; then
    cargo +1.76.0 install cbindgen --version 0.26.0 2>&1 | tail -2
fi
cbindgen --version || true

echo "==== write CI mozconfig (based on upstream mozconfig-b2g-optdesktop) ===="
cat > mozconfig-ci <<'EOF'
. $topsrcdir/mozconfig-capyloon-env

ac_add_options --enable-application=b2g
ac_add_options --with-app-basename=b2g

ac_add_options --disable-profiling
ac_add_options --enable-forkserver
ac_add_options --disable-tests
ac_add_options --disable-updater

# Disable telemetry
ac_add_options MOZ_TELEMETRY_REPORTING=

# Pretend to be an official build to be in a release configuration.
export MOZILLA_OFFICIAL=1

# Gecko sandboxing is disabled upstream for b2g; keep it that way.
ac_add_options --disable-sandbox

mk_add_options AUTOCLOBBER=1

# Set the api-daemon port
ac_add_options --with-api-daemon-port=8081

# Disable WASM libraries sandboxing (upstream does the same).
ac_add_options --without-wasm-sandboxed-libraries

export MOZ_REQUIRE_SIGNING=

# ---- CI specific tuning ----
# Skip LTO: halves build time and memory pressure on 4-core runners.
export MOZ_DISABLE_LTO=1
# Skip debug symbols: saves several GB of objdir/disk.
ac_add_options --disable-debug-symbols
# Explicit release optimization.
ac_add_options --enable-optimize
# Linker
ac_add_options --enable-linker=lld
EOF

export MOZCONFIG="$PWD/mozconfig-ci"
export MACH_USE_SYSTEM_PYTHON=1

echo "==== build ===="
./mach build

echo "==== package ===="
./mach package

echo "==== collect artifact ===="
TARBALL=$(ls -1 obj-*/dist/b2g-*.en-US.linux-x86_64.tar.bz2 2>/dev/null | head -1 || true)
if [ -z "$TARBALL" ]; then
    TARBALL=$(find obj-*/dist -maxdepth 1 -name "b2g*.tar.bz2" | head -1)
fi
if [ -z "$TARBALL" ]; then
    echo "ERROR: no b2g package tarball found in dist/"
    ls obj-*/dist/ || true
    exit 1
fi
cp -v "$TARBALL" "$ROOT/output/b2g-123.0.en-US.linux-x86_64.tar.bz2"
ls -la "$ROOT/output"

echo "==== disk after build ===="
df -h / || true
