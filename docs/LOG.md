# Work Log

## 2026-11-27

| Time (KST) | What |
|---|---|
| 04:44 | Project folder `~/projects/bluecave` created (empty). Mac on `<build-host-ip>`, gateway `<main-router-ip>` |
| ~04:47 | Research done. SWRT-dev/bluecave-asuswrt is the only living Blue Cave firmware (5.2.9, 2026-01-27). ASUS is EOL at 384.46630 (2021-05-14). No OpenWrt support. Merlin NG is Broadcom-only. Wrote `docs/RESEARCH.md` and `docs/PLAN.md` |
| ~04:50 | Forked to <https://github.com/mbshin/bluecave-asuswrt>. Cloned to `src/` with remotes `origin`/`swrt`/`merlin` and branch `bluecave-ng` |
| ~04:51 | Found toolchain gcc 4.8.3 Linaro + uClibc 0.9.33.2 (i386 host bins) and kernel 3.10.104. The macOS clone has 45 case-collision files, so builds use a Docker volume |
| ~04:52 | Built Docker image `bluecave-build` (Ubuntu 18.04 amd64). Cross-gcc runs under emulation |
| 04:53 | Started the first baseline build (clone into volume `bluecave-src`, then `make bluecave`) |
| ~04:55 | LAN scan: ASUS devices at `.1` and `.169`. `.169` turned out to be an EBA63, not the Blue Cave |
| ~04:56 | Read the main router (ExpertWiFi EBG15, `<main-router-url>`) AiMesh topology. **Blue Cave = `<bluecave-ip>`**, MAC `<bluecave-mac>`, fw 384_32948, wireless 5 GHz backhaul through an EBA63 |
| ~04:57 | On the EBG15: Enable SSH = **LAN only**, port 22. Applied, and AiMesh pushed it to the Blue Cave within about 10 s |
| ~04:59 | User ran survey and backup with password auth. The survey worked; the backup stopped at mtd6 |
| ~05:03 | Created key `~/.ssh/bluecave_rsa` (RSA 3072), added it to EBG15 **Authorized Keys**, and it reached the node within seconds. Key login works |
| ~05:05 | Backup script made resumable (size check, retries, keepalive). Fixed the bug where `ssh` consumed the loop's stdin |
| ~05:08 | **Full NAND backup verified**: mtd0 to mtd14 size-matched, `/jffs` tarball, SHA256SUMS, 207 MB. mtd15 has no /dev node (it's inside the mtd6 dump) |
| ~05:10 | Package inventory written to `docs/PACKAGES.md`. Found the Merlin `384.14_x` branch as the porting base |
| ~05:12 | Added a git identity to the build image (fixes "Please tell me who you are") |
| 05:15 | **Incident:** a duplicate build was started by mistake and ran for about 5 s before being killed; the original build continues. Added a concurrency guard (`--name bluecave-builder`) to `build.sh` |
| 05:15+ | OpenSSL-linked prebuilt binary scan running → `out/openssl-linked.txt` |
| ~05:20 | Found Merlin's `openssl10-compat` shim (1.0.0 SONAMEs → 3.5, built for Trend Micro blobs). It applies to the Blue Cave (`BWDPI=y`) |
| ~05:25 | **Commit `d2a52749e`** on `bluecave-ng`: imported `openssl-3.5`, `openssl10-compat` and `openssl11-compat` from Merlin `main`. Added the `RTCONFIG_OPENSSL35` selection, build/install/stage rules and the `OPENSSL35=y` hook. Adapted the shim CFLAGS for gcc 4.8. Off by default; not pushed yet |
| ~05:30 | Scan, partial: `libvpn/prebuild/libvpn.so` links OpenSSL **1.0.0**, so it needs `openssl10-compat` symbol coverage. `dm2_nzbget` links 0.9.8 (optional app) |
| ~05:35 | **Commit `9923cbafb`**: dropbear 2026.94 from Merlin plus Merlin's build rule (adapted `$(TOP_PLATFORM)`→`$(TOP)`). Ported `rc/ssh.c` (no `nvram_default_get` in SWRT, so port 22 is hardcoded; LAN-IP bind kept) |
| ~05:40 | Scan finished: **52 prebuilt blobs link OpenSSL 1.0.0**, including Lantiq hostapd/wpa_supplicant (Wi-Fi) and AiMesh cfg_server/cfg_client. httpd/rc also link 1.0 blob libs (libvpn, libletsencrypt, libamas-utils). 308 symbols: 43 in the shim, 230 forwardable, 35 removed in 3.5. A first count was wrong (macOS vs C-locale `sort`), now fixed. Wrote `docs/OPENSSL-ABI.md` with the hybrid design |
| ~05:50 | Exact gap: **40 symbols** missing from 3.5 (31 crypto + 9 ssl). `EVP_MD_CTX_init`/`HMAC_CTX_init` (stack contexts) are imported **only** by Lantiq hostapd/wpa_supplicant, which confirms the hybrid. Found that Merlin's `openssl10-compat` `_Exit(127)`s on non-glibc and its libssl map exports nothing, so we need our own design (OPENSSL-ABI.md §3c) |
| ~05:55 | Found that `release/src-lantiq/Makefile` is a **symlink** to `../src-rt/Makefile`, so the OPENSSL35 hook had been left out of the commit. Added commit `2bae6f2d0` |
| ~05:57 | **First push blocked by GitHub push protection**: OpenSSL/libtomcrypt **test and demo private keys** (`apps/*.pem`, `test/**`, `demos/**`, dropbear `libtomcrypt/test*/*.key`). They're public upstream test vectors, not real secrets. The push protection wasn't bypassed. Instead the 285 key files were removed from the 3 unpushed commits with `git filter-branch` in a bare clone (the macOS worktree couldn't be used because of case collisions). New IDs: `d2a52749e` (openssl), `9923cbafb` (dropbear), `2bae6f2d0` (build hook) |
| ~06:00 | **Pushed** `bluecave-ng` → <https://github.com/mbshin/bluecave-asuswrt/tree/bluecave-ng>. Local `src/` reset to it (the removed key files remain on disk as untracked files) |
| ~06:01 | Redacted private network details from the docs (moved to a gitignored `private/` folder). Added root `README.md`, `LICENSE` (GPL-2.0) and `.gitignore` |
| ~06:05 | **Published** this repo publicly: <https://github.com/mbshin/bluecave-ng>. Commits use the GitHub no-reply e-mail |
| ~06:10 | The fork's commits turned out to carry a personal gmail address, not the work e-mail. The force-push to rewrite them to the no-reply address was **blocked by the permission check** and is waiting on the user. The fork clone now uses the no-reply identity for new commits |
| ~06:12 | Security review fixes in `router-backup.sh`/`router-survey.sh`: validate `/proc/mtd` fields (dev/size/name) before using them in arithmetic, paths or remote commands; SSH multiplexing socket moved from `/tmp` to `~/.ssh/cm/%C` (mode 700); portable `wc -c` / `sha256sum` |
| ~06:15 | Added **GitHub Actions** firmware build (`.github/workflows/build.yml`) |
| ~06:20 | With the user's approval: rewrote the personal gmail address on the 3 fork commits to the GitHub no-reply address and **force-pushed** `bluecave-ng`. New IDs: `d2a52749e2` (openssl), `9923cbafb5` (dropbear), `2bae6f2d09` (build hook). Contents unchanged |
| ~06:22 | Added `CHANGELOG.md` (release notes against SWRT 5.2.9) |
| ~06:30 | AiMesh: confirmed `AMAS=y` in the BLUECAVE flags and prebuilt `cfg_server`/`cfg_client`/`libcfgmnt.so` in the tree. Compatibility with the main router's 3.0.0.6 firmware has to be tested on the device |
| ~06:40 | **Commit `323c076cdc`**: Blue Cave `openssl10-compat` (replaces Merlin's). Added `docs/FLASHING.md` |
| ~06:45 | Security review of the shim: checked the `X509_STORE_CTX_init` stack-allocation risk. `libvpn` uses `_new`/`_free` (heap), so OK. Recorded the residual macro struct-access risk |
| ~06:47 | Constraint from the user: **one Blue Cave, no spare or test environment.** Reframed FLASHING.md: the leaf node is its own test device; flash over a cable; UART needed before OpenSSL 3.5 |
| ~06:48 | Hostapd/wpa_supplicant launch path found: `fapi_wlan_wave_lib_common.sh` does `cp -s ${BINDIR}/hostapd /tmp/hostapd_<radio>` (a symlink), then runs it. So a private-libs approach must work through symlinks (DT_RUNPATH on the binary, or a wrapper at `${BINDIR}/hostapd`) |

| ~05:55 | Downloaded official ASUS `FW_BLUECAVE_300438446630.zip` (34.6 MB, from dlcdnets.asus.com, path read off the ASUS support page). Verified `.trx`: HDR0, XRX5, `BLUECAVE`, `384_46630-g3e43ad7` |
| ~05:58 | **Step 0 attempt 1:** the user uploaded the `.trx` through EBG15 → Administration → Firmware Upgrade → BLUE CAVE → Upload. The node received 21.3/34.7 MB in `/tmp/linux.trx`, then discarded it. **No flash, no reboot.** The EBG15 web session had dropped (re-login at 05:59:11). The EBG15 log has no node-upgrade lines |
| ~06:00 | CI runs 1 and 2 (master and bluecave-ng) **failed in setup**: ipset autoreconf needs `ltdl.m4` (`libltdl-dev`). The `make\|tee` pipe masked it. Fixed in `2edee50` and reran. Stopped the stale local build |
| ~06:02 | Wrote `docs/HANDOFF.md` |
| 17:30 | CI reruns after the libltdl fix: **fork `master` (SWRT 5.2.9 baseline) builds green** (run `45895088817`, artifact `bluecave-993adeb230`). `bluecave-ng` failed at the dropbearmulti link: `IS_PTCSRV_LOCKED` (newer libptcsrv) and `asus_openssl_crypt` (newer libshared) aren't in SWRT 5.2.9 |
| 17:31 | **Commit `f543003ea0`** on `bluecave-ng`: gated both hooks behind `HAVE_PTCSRV_LOCKED` / `HAVE_ASUS_OPENSSL_CRYPT` (undefined), which matches the old 2019.78 behaviour (SWRT writes `$1$` hashes). Pushed, and CI run `45966381209` started |
| 17:32 | Found the fork clone had **no local `user.email`**, so `323c076cdc` and `f543003ea0` were pushed with the personal gmail address (the earlier note that it had been switched was wrong). Set the repo-local no-reply address. Rewriting the two commits needs a force-push, which the user approved |
| 17:44 | User decisions: **force-push OK**, **retry step 0 through the AiMesh upload**, **physical access to the Blue Cave: yes**. Node pre-check: still 384_32948, no `/tmp/linux.trx`, 367 MB free RAM, `upgrade_fw_status=4`, `webs_state_error=1`. Started a watcher (`out/step0-attempt2-174457.log`) |
| 17:45–18:05 | Rewrote the two commits in a bare clone (trees identical): `323c076cdc`→`9bdc2e04ee`, `f543003ea0`→`10681c21c6`. The HTTPS push from the scratch clone hung for about 20 minutes waiting for credentials. Killed it and **force-pushed through `src/`'s SSH remote** with `--force-with-lease`. `bluecave-ng` = `10681c21c6` |
| 17:53 | Step 0 attempt 2: no upload had reached the node yet |
| 17:56 | **CI run `45966381209` green**: first `bluecave-ng` firmware (dropbear 2026.94, OpenSSL 1.0 default). `3.0.0.4_BLUECAVE_R5.2.9_30001-gf543003.trx` 36,294,656 B, HDR0/XRX500/BLUECAVE, sha256 `3516d6d8394d3463999466a0101c230c0a902d9af1e7d36a5ae487ade5c58802`. Saved to `out/ci/45966381209/` |
| 18:05 | The extracted official `.trx` was missing from disk. Re-extracted it from the verified zip; the sha256 `c6a523ef…168f9a` matches |
| 18:09 | **Step 0 attempt 2:** the user uploaded the `.trx` through EBG15 → Firmware Upgrade → BLUE CAVE → Upload. The node received **34,717,696 / 34,717,696 B** at 18:09:49 (`upgrade_fw_status` 4→0→2), stopped its services at 18:09:51–54 |
| 18:10–18:13 | Node rebooted at 18:10:37 and answered SSH at 18:13. **Now `384_46630-g3e43ad7`**, still an AiMesh node (`sw_mode=3`, `re_mode=1`), `wlc_state=2`/`wlc1_state=2`, same IP, 369 MB free. **Step 0 done** |
| 18:22–18:31 | The Mac had moved to another network (192.168.0.x); nothing was done until it was back on the LAN |
| 18:32 | Step 1 pre-flight: node on bank B (`active_bank=B`, `update_chk=2`). The upgrade writes bank A; rootfsA has 282 LEBs and the CI rootfs needs 264; 149 LEBs free; same kernel (3.10.104, 2.75 MB). Both trx have valid CRCs and the same layout. Stock trigger: `cfg_client` → `/tmp/linux.trx` + `restart_upgrade`. Saved nvram to `backup/nvram-384_46630-20261127-183241.txt` |
| 18:40 | Explained to the user that the custom firmware isn't finished (OpenSSL 3.5 off), and recommended not flashing yet |
| 18:45 | **Independent review by Codex** (read-only, isolated bundle, no private data): don't flash yet. See [REVIEW-STEP1.md](REVIEW-STEP1.md). Redacted the LAN IP I had added to HANDOFF.md (`5fa2a70`; still in earlier commits of the public history) |
| 18:50 | **Commit `f7b396110d`** (`rc/ssh.c`): an invalid port falls back to 22 rather than turning SSH off; nvram RSA/ECDSA host keys are migrated (chmod 0600); key generation and symlink results are checked, with a fallback to RAM; fixed `f_size()==-1` being treated as present. CI run `45975183625` |
| 18:55 | OpenSSL 3.5 branch `bluecave-ng-ossl35`: `OPENSSL35=y` in the BLUECAVE flags (`9e865d9d14`). CI run `45975743475` was green **but built OpenSSL 1.0**: the log said `.config:320: trying to assign nonexistent symbol RTCONFIG_OPENSSL35`. Added the Kconfig choice (`b06e8905b2`), reran as `45980552818` |
| 19:04 | **Trial-boot rehearsal, first half** (user approved): `uboot_env --set --name update_chk --value 3`, read back, reboot. The node came up on **bank A** (`rootfsA`, official `384_32948`), U-Boot had saved `update_chk=2`, back in the mesh. It got a **new DHCP address** (found by ARP sweep for its MAC). 384_32948 has no `uboot_env` binary |
| 2026-11-28 | User power-cycled the node (uptime 1 day 1 h at the next check) |
| 2026-11-29 | **Trial-boot rehearsal, second half verified:** node on **bank B** (`rootfsB`, `active_bank=B`), official `384_46630-g3e43ad7`, `update_chk=2`, `re_mode=1`, `sw_mode=3`, `cfg_client`/`amas_wlcconnect` running, reachable over the wireless backhaul (`wlc0_ssid` set). `wlc*_state` reads 0 after a day of uptime (it read 2 right after step 0), so don't use it alone as the backhaul check. **The one-shot fallback works as documented** |
| 2026-11-29 | CI `45980552818` (real OpenSSL 3.5 build) **failed only at the shim check**: OpenSSL 3.5 itself built and installed. `openssl10-compat` was missing `SSLv3_method`/`SSLv3_server_method` (ssl3-method is off by default in 3.x). **Commit `16f7201223`** maps them to the TLS methods. CI run `46179228879` |

## Changes made outside this repo

| Where | Change | How to undo |
|---|---|---|
| GitHub `mbshin` | Fork `bluecave-asuswrt` created | Delete the repo on GitHub |
| Main router | SSH: LAN only, port 22, password login allowed | Settings → Administration → System → Enable SSH = No |
| Main router | Authorized Keys = `bluecave-backup` RSA public key | Clear the Authorized Keys field → Apply |
| This Mac | `~/.ssh/bluecave_rsa{,.pub}`, and `<bluecave-ip>` added to `~/.ssh/known_hosts` | Delete the files and the known_hosts line |
| Docker | Image `bluecave-build`, volume `bluecave-src` (~5 GB+) | `docker rmi bluecave-build; docker volume rm bluecave-src` |

## Open observations

- The Blue Cave's load average is about 8 to 10 while it's only a mesh node. Worth looking into.
- The test unit runs 384_32948 (2018), not even ASUS's last 384_46630.
