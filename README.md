# Blue Cave NG

Maintained, security-updated firmware work for the end-of-life **ASUS Blue Cave** router (Intel/Lantiq **GRX350** + **WAVE500** Wi-Fi).

ASUS stopped updating the Blue Cave in 2021 (last release `3.0.0.4.384.46630`). It ships **OpenSSL 1.0.2u (2019)**, **dropbear 2019.78**, **dnsmasq 2.84** and a vendor **Linux 3.10** kernel. This project builds on the [SWRT Blue Cave firmware](https://github.com/SWRT-dev/bluecave-asuswrt) and brings in current packages and fixes from [Asuswrt-Merlin](https://github.com/RMerl/asuswrt-merlin.ng). Wi-Fi and AiMesh are kept working.

> ⚠️ **Work in progress. Nothing here has been flashed to a device yet.** Flashing custom firmware can brick your router. Before you flash anything, read [docs/ROUTER.md](docs/ROUTER.md): take a full NAND backup (including the **Wi-Fi calibration partition**) and have a serial console ready.

## Repositories

| Repo | Contents |
|---|---|
| **this repo** | Docs, Docker build environment, build and router-backup scripts |
| [mbshin/bluecave-asuswrt @ `bluecave-ng`](https://github.com/mbshin/bluecave-asuswrt/tree/bluecave-ng) | Firmware source: a fork of SWRT-dev/bluecave-asuswrt with our changes |

## Status

| Area | State |
|---|---|
| Research, hardware survey, NAND layout | ✅ Done ([RESEARCH](docs/RESEARCH.md), [ROUTER](docs/ROUTER.md)) |
| Docker build environment (Apple Silicon and x86) | ✅ Done ([BUILD](docs/BUILD.md)) |
| Baseline build of SWRT 5.2.9 | 🔄 In progress |
| **dropbear 2019.78 → 2026.94** | ✅ Imported, not build-tested yet |
| **OpenSSL 1.0.2u → 3.5.9** | 🔄 Imported and wired in, not turned on yet. 52 prebuilt blobs need a compatibility layer ([OPENSSL-ABI](docs/OPENSSL-ABI.md)) |
| dnsmasq, curl, miniupnpd, zlib, … | ⏳ Planned ([PACKAGES](docs/PACKAGES.md)) |
| Merlin web UI / rc features (from Merlin `384.14_x`) | ⏳ Planned |
| Kernel CVE backports (3.10) | ⏳ Planned |

## Key constraints

- **The kernel stays at 3.10.104.** The WAVE500 Wi-Fi driver, PPA/TMU datapath and GPHY firmware are binary-only blobs built for it.
- **Mainline OpenWrt isn't an option.** GRX350 support was never merged upstream, and there's no open WAVE500 driver.
- **Merlin NG is Broadcom-only**, so we take userspace and packages from it, not the platform.
- **Toolchain:** gcc 4.8.3 (Linaro) with uClibc 0.9.33.2. It ships inside the source tree as 32-bit x86 binaries.

## Build in GitHub Actions

[![Build firmware](https://github.com/mbshin/bluecave-ng/actions/workflows/build.yml/badge.svg)](https://github.com/mbshin/bluecave-ng/actions/workflows/build.yml)

Actions → **Build firmware** → *Run workflow* (or `gh workflow run build.yml -R mbshin/bluecave-ng -f ref=bluecave-ng`). The `.trx` is uploaded as an artifact. See [docs/BUILD.md](docs/BUILD.md#github-actions).

## Quick start (local build)

Requirements: Docker. About 15 GB of disk. On Apple Silicon the build runs under x86 emulation, which is slow.

```sh
scripts/build.sh image    # build the Ubuntu 18.04 amd64 build image
scripts/build.sh clone    # clone the firmware fork into a case-sensitive Docker volume
BRANCH=bluecave-ng scripts/build.sh clone build   # build → out/*.trx, log in out/build.log
```

The source must live on a **case-sensitive** filesystem, which is why the build uses a Docker volume. See [docs/BUILD.md](docs/BUILD.md).

## Back up your router first (read-only)

With SSH enabled on the router (LAN only):

```sh
scripts/router-survey.sh admin@<router-ip>                          # hardware/firmware report
SSH_KEY=~/.ssh/id_rsa scripts/router-backup.sh admin@<router-ip>    # dump every MTD partition + SHA256SUMS
```

The backup includes `nvram.txt`, which has your Wi-Fi and admin passwords in plain text. **Keep it private. Never commit it.** `backup/` is gitignored.

## Documentation

| Doc | Contents |
|---|---|
| [docs/HANDOFF.md](docs/HANDOFF.md) | **Start here**: current state, constraints, next actions |
| [docs/RESEARCH.md](docs/RESEARCH.md) | Hardware, ASUS EOL status, existing projects, constraints, sources |
| [docs/PLAN.md](docs/PLAN.md) | Phased plan with progress checkboxes |
| [docs/BUILD.md](docs/BUILD.md) | Build environment, toolchain, git notes, build log |
| [docs/PACKAGES.md](docs/PACKAGES.md) | Package versions SWRT vs Merlin, priorities |
| [docs/OPENSSL-ABI.md](docs/OPENSSL-ABI.md) | OpenSSL 1.0 → 3.5 migration: prebuilt blob analysis and the hybrid design |
| [docs/FLASHING.md](docs/FLASHING.md) | What is safe to flash and when, pre-flash checklist, recovery |
| [docs/ROUTER.md](docs/ROUTER.md) | Survey results, NAND layout, SSH access in AiMesh, backup procedure |
| [CHANGELOG.md](CHANGELOG.md) | Release notes: what changed against SWRT 5.2.9 |
| [docs/LOG.md](docs/LOG.md) | Dated work log |

## Credits

- [SWRT-dev/bluecave-asuswrt](https://github.com/SWRT-dev/bluecave-asuswrt) by paldier: the Lantiq platform port this builds on
- [Asuswrt-Merlin](https://github.com/RMerl/asuswrt-merlin.ng) by RMerl: package updates and fixes
- ASUS GPL source releases

## License

Scripts and docs in this repo: **GPL-2.0** (see [LICENSE](LICENSE)), matching the Asuswrt GPL code they build. Firmware source licenses are those of the respective upstream components.
