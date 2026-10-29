#!/bin/bash
# Stage 4: Assemble the bootable hybrid live ISO (BIOS + UEFI GRUB) with
# Debian live-build on a bookworm base, including the capyloon deb stack.
# Produces: iso/livebuild/capyloon-x86_64_<date>.iso
set -euo pipefail

ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
LB_DIR="$ROOT/iso/livebuild"
cd "$LB_DIR"

export DEBIAN_FRONTEND=noninteractive

echo "==== deb artifacts received ===="
ls -la "$ROOT/output/"

echo "==== install live-build toolchain ===="
sudo apt-get update -qq
sudo apt-get install -y -qq \
    live-build squashfs-tools xorriso \
    grub-pc-bin grub-efi-amd64-bin grub-efi-amd64-signed shim-signed \
    mtools dosfstools debootstrap e2fsprogs parted
dpkg -l live-build | tail -1

echo "==== place local debs ===="
mkdir -p config/packages.chroot
rm -f config/packages.chroot/*.deb
cp "$ROOT"/output/capyloon*.deb config/packages.chroot/
cp "$ROOT"/output/plymouth-theme-capyloon*.deb config/packages.chroot/
ls -la config/packages.chroot/

echo "==== clean previous builds ===="
sudo rm -rf chroot cache binary overlay .build local* .stage* build.log || true
rm -rf cache || true
rm -f binary*.iso || true

echo "==== lb config ===="
# Try GRUB on both BIOS and UEFI first; fall back to lb defaults.
sh auto/config --bootloaders "grub-pc grub-efi" || {
    echo "explicit bootloaders failed; retrying with lb defaults"
    sudo rm -rf chroot cache binary .build .stage*
    sh auto/config
}

echo "==== lb build (this takes ~20-40 min) ===="
sudo lb build 2>&1 | tee build.log || {
    echo "==== BUILD FAILED - tail of log ===="
    tail -100 build.log
    exit 1
}

echo "==== rename + checksum ===="
ISO_SRC=$(ls -1 *.iso 2>/dev/null | head -1)
[ -n "$ISO_SRC" ] || { echo "ERROR: no iso produced"; tail -100 build.log; exit 1; }
ISO_DST="capyloon-x86_64_$(date +%Y%m%d).iso"
mv "$ISO_SRC" "$ISO_DST"
sha256sum "$ISO_DST" > "$ISO_DST.sha256"
ls -la "$LB_DIR"/*.iso "$LB_DIR"/*.sha256
