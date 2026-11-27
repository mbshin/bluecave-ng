# Plan: Fork SWRT, Enhance from Current Merlin

**Goal:** firmware for the Blue Cave that is maintained, gets security updates, and keeps Wi-Fi and AiMesh working.

**Strategy:** fork **SWRT-dev/bluecave-asuswrt**, which already has the Lantiq platform layer. Then bring in userspace and packages from current **Asuswrt-Merlin NG** (latest tag 3006.102.9). The 3.10 vendor kernel and the WAVE500 blobs stay. See [RESEARCH.md](RESEARCH.md) for why.

```
┌──────────────────────────────────────────────────────────────┐
│ web UI · httpd · rc · services   ← port from Merlin NG        │
│ openssl · dnsmasq · dropbear · curl · openvpn · wireguard     │
│                                   ← bump to current upstream  │
├──────────────────────────────────────────────────────────────┤
│ Lantiq platform: kernel 3.10.104, UGW SDK 7.2.x,             │
│ WAVE500 driver/fw, PPA/TMU, GPHY fw  ← keep (SWRT), backport  │
│                                         kernel CVE fixes only │
├──────────────────────────────────────────────────────────────┤
│ U-Boot (NAND)                        ← don't touch            │
└──────────────────────────────────────────────────────────────┘
```

## Phase 0: Protect the hardware (before any flashing)

- [ ] Solder a UART header and connect a 3.3 V USB-TTL adapter. Confirm the U-Boot console works.
- [x] Dump every MTD partition over SSH with `scripts/router-backup.sh`: `backup/mtd-20261127-050147/` (207 MB, size-verified, SHA256SUMS). See [ROUTER.md](ROUTER.md).
- [ ] Copy the backup off this Mac. It includes `calibration` (irreplaceable) and `nvram.txt` (plain-text passwords).
- [x] Record the stock state with `scripts/router-survey.sh`: `backup/survey-20261127-050134.txt` (fw 384_32948, GRX350, dual-bank A/B).
- [ ] Check recovery: make sure the ASUS rescue mode or U-Boot TFTP recovery can reflash stock 384.46630.
- [ ] Move the Blue Cave out of AiMesh, or set up a separate test network. **It's a wireless node** (5 GHz backhaul through an EBA63), so it needs a cable or its own test network for flashing.
- [ ] Work out how the updater picks bank A or B, so test images can go to the inactive bank.

## Phase 1: Build environment and baseline

- [x] Docker build container: Ubuntu 18.04, `linux/amd64`, i386 libs (`docker/Dockerfile`). The i386 toolchain runs under emulation on Apple Silicon. See [BUILD.md](BUILD.md).
- [ ] Clone SWRT, run `make bluecave`, and get a `.trx` out of it. _In progress: first build started 2026-11-27 04:53, still compiling the kernel. See BUILD.md → Build log._
- [ ] Flash the baseline build and check Wi-Fi on both bands, WAN, NAT throughput and AiMesh.
- [x] Document the toolchain: gcc 4.8.3 Linaro, uClibc 0.9.33.2, i386 host binaries (see RESEARCH.md §6).

## Phase 2: Fork and repo layout

- [x] Fork `SWRT-dev/bluecave-asuswrt` on GitHub: <https://github.com/mbshin/bluecave-asuswrt> (2026-11-27).
- [x] Remotes: `origin` (your fork), `swrt` (upstream SWRT), `merlin` (`RMerl/asuswrt-merlin.ng`, as a reference for cherry-picks only). Local clone in `src/`.
- [x] Branches: `master` follows SWRT, `bluecave-ng` holds your changes. **Pushed 2026-11-27** (commits d2a52749e, 9923cbafb, 2bae6f2d0).
- [x] Rule: never commit upstream test/demo private keys (GitHub push protection blocks them). Strip `*.pem`/`*.key` that contain private keys when importing packages.
- [x] CI: GitHub Actions workflow `build.yml` in this repo (manual dispatch with repo/ref/target, `.trx` + log artifacts). First run 2026-11-27.

## Phase 3: Security-critical package updates (highest value)

See [PACKAGES.md](PACKAGES.md) for the version gap table (inventory done 2026-11-27).

Progress:
- [x] OpenSSL 3.5.9 + `openssl10-compat`/`openssl11-compat` imported from Merlin and wired into the build (`RTCONFIG_OPENSSL35`, `OPENSSL35=y`). Commits `d2a52749e` + `2bae6f2d0` on `bluecave-ng` (pushed). **Not turned on for BLUECAVE yet.**
- [x] **dropbear 2019.78 → 2026.94** from Merlin, plus a ported `rc/ssh.c` (keys in /jffs/.ssh, ed25519, no DSS, multiple keys, forwarding opt-in, LAN-IP bind kept). Commit `9923cbafb`, link fix `10681c21c6` (ASUS hooks missing from SWRT gated). Builds on CI (run `45966381209`). Not device-tested yet.
- [x] Prebuilt scan finished: **52 blobs on OpenSSL 1.0.0**, 308 imported symbols. The Merlin shim covers 43, 230 forward by name, 35 need implementations. See [OPENSSL-ABI.md](OPENSSL-ABI.md)
- [x] Exact gap: 40 symbols missing from 3.5. Stack-context functions are used **only** by Lantiq hostapd/wpa_supplicant, which confirms the hybrid design.
- [x] Wrote the Blue Cave shim (`DT_NEEDED` on 3.5, 36 removed symbols implemented, `make check` against the 151 required symbols). Commit `9bdc2e04ee` (pushed; was `323c076cdc` before the e-mail rewrite). **Not compiled yet.**
- [ ] Private OpenSSL 1.0.2u for Lantiq hostapd/wpa_supplicant (rpath or wrapper)
- [ ] Turn on `OPENSSL35=y` for BLUECAVE in a branch and get it to build in CI
- [ ] Hybrid design: open source → 3.5, blobs → extended `openssl10-compat` shim, **Lantiq hostapd/wpa_supplicant → private OpenSSL 1.0.2u** (work items in OPENSSL-ABI.md §5)
- [ ] Turn on `OPENSSL35=y` in the BLUECAVE flags (`src-lantiq/target.mak:464`) and fix the compile breakage (httpd, rc, openvpn, curl, wget, ...)

Order is by exposure on the WAN and LAN.

| Package | Why | Notes |
|---|---|---|
| openssl | TLS for web UI, VPN, DDNS | Try 3.x; fall back to 1.1.1 plus backports if the toolchain can't build it |
| dnsmasq | DNS/DHCP, history of CVEs | Merlin keeps this current. Take its version |
| dropbear | SSH | Simple bump |
| curl / libcurl | DDNS, firmware checks | |
| busybox | Shell and utilities | |
| openvpn | VPN server/client | |
| miniupnpd | UPnP, exposed on the LAN | |
| wireguard | New feature | `wireguard-linux-compat` module plus `wireguard-tools`. Merlin's web UI glue for it can be ported |

For each package: diff the SWRT version against the Merlin version, take Merlin's version and patches, build, then run a smoke test on the device.

## Phase 4: Port Merlin userspace (largest piece)

- [ ] Diff `release/src/router/{rc,httpd,shared,www}` between SWRT and Merlin **`384.14_x`** (same ASUS 384 base), then selectively against `main`.
- [ ] Cherry-pick by feature, not by bulk merge. Merlin's code is full of Broadcom `#ifdef`s, and ASUS 386+ dropped Lantiq paths.
- [ ] Order: security fixes in httpd/auth, then the Merlin addon API (`/jffs/scripts`, amtm), then DoT/DNS features, then UI.
- [ ] Wi-Fi settings code must keep calling the Lantiq/WAVE APIs (`wlcsm`/`wave` utilities), not the Broadcom `wl`.

## Phase 5: Kernel hardening (limited)

- [ ] Backport selected 3.10 CVE fixes in netfilter, TCP and PPP. The CIP/SLTS and Debian/Ubuntu 3.x trees are possible sources **(unverified)**.
- [ ] Don't change the ABI the binary modules depend on, or the WAVE and PPA modules will stop loading.

## Phase 6: Release

- [ ] Versioning: `BLUECAVE_NG_<swrt-ver>_<n>`.
- [ ] Release notes that list package versions and CVEs fixed.
- [ ] Optionally send generic fixes back to SWRT upstream.

## Risks

| Risk | Mitigation |
|---|---|
| Bricked unit | UART plus full NAND backup before Phase 1 flashing. Never flash U-Boot |
| Toolchain too old for modern packages | Find out in Phase 1. Fallback is the newest version that builds, plus backported patches |
| Mismatch with SWRT's Wi-Fi blobs | Keep `proprietary/` untouched. Test Wi-Fi after every change |
| AiMesh incompatible with newer ASUS nodes | Test against your other nodes. AiMesh protocol code is closed source in ASUS GPL |
| One-person upstream (SWRT) disappears | Your fork stands alone after Phase 2 |

## Next actions

1. Finish the baseline build (SWRT 5.2.9) and record the time and any fixes in BUILD.md.
2. Finish the OpenSSL-linked binary scan (`out/openssl-linked.txt`). It decides whether the OpenSSL 3 migration is feasible.
3. Copy `backup/` off this Mac.
4. Phase 3 P0: OpenSSL 1.0.2u → 3.5, dropbear 2019.78 → 2026.94, dnsmasq 2.84 → 2.93.
5. ~~Push `bluecave-ng`~~ (done). ~~Set up CI~~ (done: Actions).
6. Before the first flash: give the Blue Cave a wired connection or test network, connect UART, test recovery.
