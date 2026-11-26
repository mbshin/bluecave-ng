# Changelog

Firmware changes are in [mbshin/bluecave-asuswrt @ `bluecave-ng`](https://github.com/mbshin/bluecave-asuswrt/tree/bluecave-ng). They're measured against the base **SWRT 5.2.9** (`993adeb230`, ASUS 384 GPL, kernel 3.10.104).

## [Unreleased] — firmware (`bluecave-ng`)

> ⚠️ **Not built or flashed yet.** CI builds are running. Don't flash anything from this branch until a release is tagged.

### Security updates

- **dropbear (SSH server) 2019.78 → 2026.94** (`9923cbafb5`)
  - Seven years of upstream fixes, including CVE fixes in key exchange, scp and channel handling.
  - Taken from Asuswrt-Merlin with Merlin's `localoptions.h`: 3 auth tries, per-IP unauthenticated connection limits, SFTP via Entware's `/opt/libexec/sftp-server`.
  - Build rule now links `libnvram`/`libshared` (Merlin patches) and uses `-O2` and `IGNORE_SPEED=1`.
- **SSH service (`rc/ssh.c`) rework** (`9923cbafb5`)
  - Host keys are **kept in `/jffs/.ssh/`** (they survive reboots and upgrades) instead of nvram.
  - **ed25519** host key added. **DSS removed**, because modern dropbear no longer supports it.
  - **Multiple authorized keys**: separate them with `>` in the web UI field.
  - Invalid `sshd_port` values now turn SSH off and reset the port to 22 instead of starting with a bad port.
  - **TCP/agent forwarding is now off by default** (`-j -k`). Turn it on with `sshd_forwarding=1`.
  - `authorized_keys` is written with mode `0600` (was `0700`).
  - "LAN only" mode **still binds to the LAN IP** (SWRT behaviour). Merlin removed that and relies on the firewall.
- **OpenSSL 3.5.9 added, not turned on yet** (`d2a52749e2`, `2bae6f2d0`)
  - New build option `OPENSSL35=y` → `RTCONFIG_OPENSSL35` → `openssl-3.5`, configured with `--api=1.1.1 no-async no-tests no-docs`, devrandom seeding, ChaCha preferred over GCM (good for a CPU without AES acceleration).
  - Installs `libcrypto.so.3`, `libssl.so.3`, `/usr/sbin/openssl` and `ossl-modules/legacy.so`.
  - **The Blue Cave still builds with OpenSSL 1.0.2u by default.** 52 prebuilt ASUS/Lantiq binaries need OpenSSL 1.0, so 3.5 stays off until a compatibility layer exists. See [docs/OPENSSL-ABI.md](docs/OPENSSL-ABI.md).
  - Imported Merlin's `openssl10-compat` and `openssl11-compat` shims as a starting point, with CFLAGS adapted for gcc 4.8. **They won't be used as-is**, because they exit on uClibc. A Blue Cave-specific shim is planned.

### Removed

- Upstream **test/demo private keys** in OpenSSL 3.5 (`apps/*.pem`, `test/**`, `demos/**`) and dropbear's bundled libtomcrypt (`test*/*.key`), 285 files. The build doesn't use them, and GitHub push protection blocks them.

### Size of change

| Component | Files | Lines |
|---|---|---|
| openssl-3.5 (new) | 5,497 | +1,746,068 |
| dropbear | 565 | +47,767 / −56,803 |
| openssl10/11-compat (new) | 12 | +2,395 |
| Build system + `rc/ssh.c` | 4 | +155 / −21 |

## [Unreleased] — this repo (`bluecave-ng`: tooling and docs)

### Added
- **GitHub Actions firmware build** (`.github/workflows/build.yml`): manual dispatch (repo/ref/target), `.trx` and build-log artifacts, error summary on failure.
- **Docker build environment**: Ubuntu 18.04 amd64 with i386 libs and a git identity. Source lives in a case-sensitive Docker volume. Has a concurrency guard.
- **Router tools**: `router-survey.sh` (read-only hardware/firmware report) and `router-backup.sh` (resumable, size-verified dump of every MTD partition plus SHA256SUMS). Validates router-supplied fields and keeps the SSH mux socket in `~/.ssh/cm`.
- **Docs**: research, phased plan, build guide, package inventory against Merlin, OpenSSL ABI analysis, router/NAND notes, work log.

## Planned

- Baseline build check of SWRT 5.2.9 (local and CI)
- Blue Cave OpenSSL 1.0 shim (40 missing symbols) plus a private OpenSSL 1.0.2u for Lantiq hostapd/wpa_supplicant, then turn on `OPENSSL35=y`
- dnsmasq 2.84 → 2.93, curl 7.67 → 8.x, miniupnpd 1.9 → 2.3, zlib 1.2.5 → 1.3, openvpn 2.4 → current
- Port Merlin `384.14_x` rc/httpd/web UI fixes, add WireGuard (wireguard-linux-compat on 3.10)
- Kernel 3.10 CVE backports
