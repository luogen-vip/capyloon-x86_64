#!/bin/bash
# Stage 3: Build the official-format capyloon deb via nutria's jackady builder,
# using artifacts produced by stage 1 & 2 (served over localhost http).
# Produces:
#   output/capyloon_<ver>_amd64.deb  (the full Capyloon desktop stack)
#   output/plymouth-theme-capyloon_<ver>_all.deb (official boot logo theme)
set -euo pipefail

ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
mkdir -p "$ROOT/output" "$ROOT/work"
cd "$ROOT/work"

echo "==== artifacts received ===="
ls -la artifacts/ 2>/dev/null || { echo "ERROR: no artifacts dir"; exit 1; }

# Sanity check all four required files
for f in \
    b2g-123.0.en-US.linux-x86_64.tar.bz2 \
    api-daemon-x86_64-unknown-linux-gnu.tar.xz \
    b2ghald-x86_64-unknown-linux-gnu.tar.xz \
    ipfsd-x86_64-unknown-linux-gnu.tar.xz ; do
    [ -f "artifacts/$f" ] || { echo "ERROR: missing artifact $f"; exit 1; }
done

echo "==== serve artifacts over local http ===="
(cd artifacts && setsid python3 -m http.server 8000 >/dev/null 2>&1 &) || true
sleep 2
curl -sI http://127.0.0.1:8000/ | head -1

echo "==== clone nutria ===="
if [ ! -d nutria ]; then
    git clone --depth 1 https://github.com/capyloon/nutria.git
fi
cd nutria

echo "==== apply desktop (x86_64) integration patch ===="
if [ -f "$ROOT/patches/nutria-start-sh-desktop.patch" ]; then
    git apply "$ROOT/patches/nutria-start-sh-desktop.patch" \
        || git apply --3way "$ROOT/patches/nutria-start-sh-desktop.patch" \
        || { echo "ERROR: could not apply nutria patch"; exit 1; }
    echo "patch applied"
fi

echo "==== write prebuilts override ===="
cat > prebuilts-ci.json <<'EOF'
{
  "x86_64-unknown-linux-gnu": {
    "b2g": "http://127.0.0.1:8000/b2g-123.0.en-US.linux-x86_64.tar.bz2",
    "api-daemon": "http://127.0.0.1:8000/api-daemon-x86_64-unknown-linux-gnu.tar.xz",
    "b2ghald": "http://127.0.0.1:8000/b2ghald-x86_64-unknown-linux-gnu.tar.xz",
    "ipfsd": "http://127.0.0.1:8000/ipfsd-x86_64-unknown-linux-gnu.tar.xz"
  }
}
EOF
export NUTRIA_PREBUILTS_JSON="$PWD/prebuilts-ci.json"

echo "==== jackady: update prebuilts ===="
./jackady update-prebuilts --target x86_64-unknown-linux-gnu

echo "==== jackady: clean ===="
./jackady clean

echo "==== jackady: build deb (device=desktop) ===="
./jackady deb --device desktop

echo "==== collect deb ===="
ls -la builder/output/debian/
cp -v builder/output/debian/capyloon*.deb "$ROOT/output/" || {
    echo "ERROR: deb not found"; find builder/output -name "*.deb"; exit 1; }

echo "==== build official plymouth theme deb ===="
cd "$ROOT/work"
if [ ! -d plymouth-theme-capyloon ]; then
    git clone --depth 1 https://github.com/capyloon/plymouth-theme-capyloon.git
fi
cd plymouth-theme-capyloon
rm -f build.sh README.md .gitignore
rm -rf .github
dpkg-deb -Zxz --build . "$ROOT/output/plymouth-theme-capyloon_1.3_all.deb"

ls -la "$ROOT/output"
