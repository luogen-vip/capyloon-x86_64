#!/bin/bash
# Stage 2: Build the Rust daemons for x86_64 Linux.
# Produces (artifact layouts must match nutria builder expectations):
#   output/api-daemon-x86_64-unknown-linux-gnu.tar.xz  (prebuilts/<target>/{api-daemon,appscmd})
#   output/b2ghald-x86_64-unknown-linux-gnu.tar.xz     (prebuilts/<target>/{b2ghald,b2ghalctl})
#   output/ipfsd-x86_64-unknown-linux-gnu.tar.xz       (prebuilts/<target>/ipfsd)
set -euo pipefail

ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
TARGET="x86_64-unknown-linux-gnu"
mkdir -p "$ROOT/output"
cd "$ROOT"

rustc --version
cargo --version

# Old dependency trees (e.g. time 0.3.x in api-daemon/iroh Cargo.lock) fail to
# compile with the latest rustc. Pin era-appropriate toolchains per repo.
rustup toolchain install 1.70.0 --profile minimal 2>&1 | tail -1 || true

############################
# api-daemon
############################
echo "==== api-daemon ===="
if [ ! -d api-daemon ]; then
    git clone --depth 1 https://github.com/capyloon/api-daemon.git
fi
cd api-daemon
mkdir -p "prebuilts/$TARGET"

# Replicates upstream daily.sh build steps.
cargo +1.70.0 build --release --target="$TARGET" -p sqlx-macros || echo "sqlx-macros build skipped/failed (non-fatal)"
(cd daemon && cargo +1.70.0 build --release --target="$TARGET")
cp "target/$TARGET/release/api-daemon" "prebuilts/$TARGET/"
(cd services/apps/appscmd && cargo +1.70.0 build --release --target="$TARGET")
cp "target/$TARGET/release/appscmd" "prebuilts/$TARGET/"

tar cJf "$ROOT/output/api-daemon-$TARGET.tar.xz" prebuilts
cd ..

############################
# b2ghald (hardware abstraction daemon)
############################
echo "==== b2ghald ===="
if [ ! -d b2ghald ]; then
    git clone --depth 1 https://github.com/capyloon/b2ghald.git
fi
cd b2ghald
mkdir -p "prebuilts/$TARGET"
# The daemon uses nix::sys::stat + clap which are feature-gated: upstream
# builds with the 'cmdline' feature (clap + nix/fs).
cargo build --release --features cmdline
cp target/release/b2ghald target/release/b2ghalctl "prebuilts/$TARGET/"
tar cJf "$ROOT/output/b2ghald-$TARGET.tar.xz" prebuilts
cd ..

############################
# ipfsd (iroh fork binary, shipped under the ipfsd name)
############################
echo "==== ipfsd ===="
if [ ! -d iroh ]; then
    git clone --depth 1 https://github.com/capyloon/iroh.git
fi
cd iroh
mkdir -p "prebuilts/$TARGET"
cargo +1.70.0 build --release --features cli
cp target/release/iroh "prebuilts/$TARGET/ipfsd"
tar cJf "$ROOT/output/ipfsd-$TARGET.tar.xz" prebuilts
cd ..

ls -la "$ROOT/output"
