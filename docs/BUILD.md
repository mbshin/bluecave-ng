# Building the Firmware

## Requirements

- Docker (Docker Desktop on macOS). Tested on an Apple Silicon Mac with Docker 29.9.3.
- About 15 GB of free disk for the source volume plus build output.
- GitHub access to <https://github.com/mbshin/bluecave-asuswrt>.

## Layout

```
bluecave/
├── docker/Dockerfile      Ubuntu 18.04 linux/amd64 build image (i386 libs included)
├── scripts/build.sh       image | clone | build | shell | all
├── src/                   macOS clone of the fork, for reading and editing only (gitignored)
├── out/                   build.log and *.trx output (gitignored)
└── docs/
```

## Quick start

```sh
scripts/build.sh image   # build the Docker image "bluecave-build"
scripts/build.sh clone   # clone the fork into Docker volume "bluecave-src"
scripts/build.sh build   # make bluecave → out/*.trx, log in out/build.log
scripts/build.sh shell   # interactive shell in the build container
```

Environment overrides: `REPO=<git url>`, `BRANCH=<branch>` (default `master`).

### Build image details

- Base `ubuntu:18.04`, `--platform linux/amd64`, i386 multiarch libs (`libc6-i386`, `lib32stdc++6`, `libelf1:i386`, and so on), plus the packages listed in the SWRT README.
- `/bin/sh` → bash, because the asuswrt Makefiles assume bash.
- User `builder` (passwordless sudo). Git identity `builder <builder@localhost>`, `safe.directory '*'`. Without it, `rt_ver_ntools` logs "Please tell me who you are" (that error is ignored, but it may break the version stamp).
- Docker warns `FromPlatformFlagConstDisallowed`. That's harmless.

### Concurrency guard

`scripts/build.sh build` runs the container under the fixed name **`bluecave-builder`** and refuses to start if one is already running. Two `make` processes on the same volume will corrupt the object tree.
Note: `docker ps --filter ancestor=bluecave-build` **misses** containers started before the image was rebuilt (the tag has moved). Use the container name instead.

## Why the source lives in a Docker volume

macOS APFS is case-insensitive. The Linux 3.10 kernel tree has files whose names differ only by case (`xt_TCPMSS.h` / `xt_tcpmss.h`, 45 paths in total). A clone on macOS silently corrupts them, so **always build from the volume**. Never build from `src/`.

## Toolchain

| Item | Value |
|---|---|
| Location | `release/src-lantiq/tools/toolchain-mips_mips32_gcc-4.8-linaro_uClibc-0.9.33.2` (in the repo) |
| Prefix | `mips-openwrt-linux-uclibc-` |
| Compiler | OpenWrt/Linaro GCC 4.8-2014.04 15.05_ltq, gcc 4.8.3 |
| libc | uClibc 0.9.33.2 |
| Host binaries | 32-bit i386 ELF. They run in the amd64 container under emulation on Apple Silicon |
| Kernel | `release/src-lantiq/linux/linux-3.10.104` |

## Git notes

- `release/src-lantiq/Makefile` is a **symlink** to `../src-rt/Makefile`. Stage `release/src-rt/Makefile` when you change it.
- The macOS clone always shows about 45 modified files (case collisions in the kernel headers, `iptables-1.4.21`, the toolchain). **Never `git add -A` at the repo root.** Stage explicit paths.
- History rewrites (filter-branch, rebase) refuse to run with those "changes" present, so do them in a **bare clone** (`git clone --bare src /tmp/x.git`) and push from there.
- When importing upstream packages, strip test/demo private keys (`git grep -lE 'BEGIN ([A-Z]+ )?PRIVATE KEY'`) or GitHub push protection will block the push.

## Editing workflow

1. Edit in `src/` on macOS, but avoid the case-colliding kernel headers. Or edit inside `scripts/build.sh shell`.
2. Commit and push to a branch on the fork.
3. Run `BRANCH=<branch> scripts/build.sh clone build`.

## Build log

| Date | Commit | Result | Time | Notes |
|---|---|---|---|---|
| 2026-11-27 04:53 | 993adeb (SWRT 5.2.9) | _running_ | | First baseline build. Container `gifted_jepsen`, started before the guard existed. Passed menuconfig, userspace dependency step, kernel headers. Compiling the kernel and modules (`drivers/crypto/lantiq_eip97`, `net/*`) |

### Build notes and incidents

- **"fatal error: wireless.h / busybox autoconf.h: No such file"** early in the log comes from the dependency-scan step. It's harmless and the build continues.
- **"Please tell me who you are" / `rt_ver_ntools Error 1 (ignored)`**: missing git identity. Fixed in the image (it affects the next build).
- **05:15 incident:** a second `build.sh build` was started by mistake while the first was still running. It ran for about 5 seconds and was killed. It may have overwritten a few kernel objects and mixed lines into `out/build.log` (a copy from just before is in `out/build-1-interrupted.log`). **If the first build fails strangely, run `make clean` (or `scripts/build.sh shell` → `cd src/release/src-lantiq && make clean`) and rebuild.**
