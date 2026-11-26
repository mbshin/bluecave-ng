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
| ~05:25 | **Commit `e3906ca1bb`** on `bluecave-ng`: imported `openssl-3.5`, `openssl10-compat` and `openssl11-compat` from Merlin `main`. Added the `RTCONFIG_OPENSSL35` selection, build/install/stage rules and the `OPENSSL35=y` hook. Adapted the shim CFLAGS for gcc 4.8. Off by default; not pushed yet |
| ~05:30 | Scan, partial: `libvpn/prebuild/libvpn.so` links OpenSSL **1.0.0**, so it needs `openssl10-compat` symbol coverage. `dm2_nzbget` links 0.9.8 (optional app) |
| ~05:35 | **Commit `8cefebda05`**: dropbear 2026.94 from Merlin plus Merlin's build rule (adapted `$(TOP_PLATFORM)`→`$(TOP)`). Ported `rc/ssh.c` (no `nvram_default_get` in SWRT, so port 22 is hardcoded; LAN-IP bind kept) |
| ~05:40 | Scan finished: **52 prebuilt blobs link OpenSSL 1.0.0**, including Lantiq hostapd/wpa_supplicant (Wi-Fi) and AiMesh cfg_server/cfg_client. httpd/rc also link 1.0 blob libs (libvpn, libletsencrypt, libamas-utils). 308 symbols: 43 in the shim, 230 forwardable, 35 removed in 3.5. A first count was wrong (macOS vs C-locale `sort`), now fixed. Wrote `docs/OPENSSL-ABI.md` with the hybrid design |
| ~05:50 | Exact gap: **40 symbols** missing from 3.5 (31 crypto + 9 ssl). `EVP_MD_CTX_init`/`HMAC_CTX_init` (stack contexts) are imported **only** by Lantiq hostapd/wpa_supplicant, which confirms the hybrid. Found that Merlin's `openssl10-compat` `_Exit(127)`s on non-glibc and its libssl map exports nothing, so we need our own design (OPENSSL-ABI.md §3c) |
| ~05:55 | Found that `release/src-lantiq/Makefile` is a **symlink** to `../src-rt/Makefile`, so the OPENSSL35 hook had been left out of the commit. Added commit `c20a93bf93` |
| ~05:57 | **First push blocked by GitHub push protection**: OpenSSL/libtomcrypt **test and demo private keys** (`apps/*.pem`, `test/**`, `demos/**`, dropbear `libtomcrypt/test*/*.key`). They're public upstream test vectors, not real secrets. The push protection wasn't bypassed. Instead the 285 key files were removed from the 3 unpushed commits with `git filter-branch` in a bare clone (the macOS worktree couldn't be used because of case collisions). New IDs: `e3906ca1bb` (openssl), `8cefebda05` (dropbear), `c20a93bf93` (build hook) |
| ~06:00 | **Pushed** `bluecave-ng` → <https://github.com/mbshin/bluecave-asuswrt/tree/bluecave-ng>. Local `src/` reset to it (the removed key files remain on disk as untracked files) |
| ~06:01 | Redacted private network details from the docs (moved to a gitignored `private/` folder). Added root `README.md`, `LICENSE` (GPL-2.0) and `.gitignore` |
| ~06:05 | **Published** this repo publicly: <https://github.com/mbshin/bluecave-ng>. Commits use the GitHub no-reply e-mail |

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
