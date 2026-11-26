#!/usr/bin/env bash
# Build Blue Cave firmware inside Docker.
# Source lives in a Docker volume (case-sensitive ext4) because the kernel tree
# has paths that differ only by case, which breaks on macOS APFS.
#
# usage: scripts/build.sh [image|clone|build|shell]   (default: all three)
set -euo pipefail
cd "$(dirname "$0")/.."

IMAGE=bluecave-build
VOL=bluecave-src
REPO=${REPO:-https://github.com/mbshin/bluecave-asuswrt.git}
BRANCH=${BRANCH:-master}
OUT=$PWD/out

run() { docker run --rm --platform linux/amd64 -v "$VOL":/home/builder/src -v "$OUT":/out "$@"; }

image() { docker build --platform linux/amd64 -t "$IMAGE" docker/; }

clone() {
  docker volume create "$VOL" >/dev/null
  run --user root "$IMAGE" chown builder:builder /home/builder/src
  run "$IMAGE" bash -c "
    set -e; cd src
    if [ -d .git ]; then git fetch origin && git checkout $BRANCH && git pull --ff-only;
    else git clone --branch $BRANCH $REPO . ; fi
    git log --oneline -1"
}

build() {
  mkdir -p "$OUT"
  if docker ps --format '{{.Names}}' | grep -qx bluecave-builder; then
    echo "a build is already running (container bluecave-builder); refusing to start another" >&2; exit 1; fi
  run --name bluecave-builder "$IMAGE" bash -c "
    set -e; cd src/release/src-lantiq
    make bluecave 2>&1 | tee /out/build.log
    cp -v image/*.trx /out/ 2>/dev/null || find . -name '*.trx' -newer Makefile -exec cp -v {} /out/ \;"
}

shell() { docker run --rm -it --platform linux/amd64 -v "$VOL":/home/builder/src -v "$OUT":/out "$IMAGE" bash; }

case "${1:-all}" in
  image) image ;; clone) clone ;; build) build ;; shell) shell ;;
  all) image; clone; build ;;
  *) echo "usage: $0 [image|clone|build|shell|all]"; exit 1 ;;
esac
