# Handoff — 2026-11-27 18:00 KST

Snapshot for whoever picks this up next (human or agent). Read this first, then [PLAN.md](PLAN.md) and [LOG.md](LOG.md).

## TL;DR

- **Device:** one ASUS Blue Cave, a **wireless leaf AiMesh node** under an ExpertWiFi EBG15. **Healthy and unchanged**: stock `3.0.0.4.384_32948-g8ec6a66` (2018), up 6 days, in the mesh. **Nothing has been flashed.**
- **Step 0** (official ASUS `384.46630` through the main router's AiMesh *Manual firmware update → Upload*) was **attempted and didn't apply**. The image started arriving on the node (`/tmp/linux.trx` reached 21.3 of 34.7 MB at 05:58), then was discarded. No flash, no reboot. **Likely cause:** the main router's web session dropped mid-transfer (new login at 05:59:11). Not proven. The EBG15 log has no node-upgrade entries. Node flags afterwards: `upgrade_fw_status=4`, `webs_state_error=1` (meaning unknown).
- **Step 0 attempt 2** is ready. The node was checked at 17:44 (clean, 367 MB free) and a watcher logs to `out/step0-attempt2-174457.log`. **As of 17:53 nothing had been uploaded.**
- **Firmware source:** `mbshin/bluecave-asuswrt@bluecave-ng` (head `10681c21c6`) has dropbear 2026.94, OpenSSL 3.5 (off) and the Blue Cave OpenSSL 1.0 shim.
- **CI:** the unchanged SWRT 5.2.9 `master` **builds green** (run `45895088817`, artifact `bluecave-993adeb230`). `bluecave-ng` failed at the dropbear link (ASUS hooks missing from SWRT). Fixed in `10681c21c6`. **Run `45966381209` is green** (built from the pre-rewrite ID `f543003ea0`, same tree): `3.0.0.4_BLUECAVE_R5.2.9_30001-gf543003.trx`, 36.3 MB, HDR0/XRX500/BLUECAVE, sha256 `3516d6d8…c58802`, in `out/ci/45966381209/`. **Not flashed. Do step 0 first.**

## State of each workstream

| Workstream | State | Next action |
|---|---|---|
| Step 0: official ASUS 384.46630 on the node | ❌ Attempt 1 didn't apply. ⏳ Attempt 2 waiting for the user's upload | Retry the AiMesh upload and **keep the main router page open and logged in until the node reboots** (~10 min). Watch `/tmp/linux.trx` on the node over SSH. Fallback (needs user OK): flash on the node over SSH with the same verified `.trx` |
| CI firmware build | ✅ Baseline `master` green. ✅ `bluecave-ng` green (run `45966381209`, after the dropbear link fix `10681c21c6`) | Check `gh run list -R mbshin/bluecave-ng`. If red, `gh run download` the build log and grep `] Error` without `ignored` |
| Local Mac build | ⏹ Stopped (it used the old image without libltdl, so it would fail) | Optional: `scripts/build.sh image && scripts/build.sh build` (slow under emulation; CI is preferred) |
| dropbear 2026.94 + `rc/ssh.c` | ✅ Committed `9923cbafb5`, link fix `10681c21c6`, **builds** | Flash test after step 0 (SSH start-up is the risk) |
| OpenSSL 3.5 | ✅ Imported and wired in (`d2a52749e2`, `2bae6f2d09`), **off** | Turn on `OPENSSL35=y` in a branch once the baseline is green |
| Blue Cave openssl10 shim | ✅ Written `9bdc2e04ee` (36 symbols + `make check` for 151) | Compiles only with OPENSSL35. Then disassembly spot-check of the cfg_*/libvpn macros |
| Private OpenSSL 1.0.2u for Lantiq hostapd/wpa_supplicant | ⏳ Not started | Launch path: `fapi_wlan_wave_lib_common.sh` does `cp -s ${BINDIR}/hostapd /tmp/hostapd_<radio>` (a symlink), so use DT_RUNPATH on the binary or a wrapper at `${BINDIR}` |
| dnsmasq / curl / miniupnpd / zlib / openvpn | ⏳ Planned | [PACKAGES.md](PACKAGES.md) |
| Merlin `384.14_x` rc/httpd port, WireGuard | ⏳ Planned | [PLAN.md](PLAN.md) Phase 4 |

## Hard constraints from the user

1. **One Blue Cave, no spare, no test environment.** Every flash is to the real device.
2. **Can't change the current configuration:** no cable, no rewiring, the node stays a wireless AiMesh node, clients stay.
3. Therefore: official images go through the **AiMesh manual upload**. Custom images go **directly to the node** (SSH or the node UI) over Wi-Fi and must rejoin the mesh on their own. Recovery is **physical** (reset button / Rescue Mode). **The user can physically reach the device** (confirmed 2026-11-27).
4. **Ask before anything irreversible** (flashing, force-pushing, router setting changes). The user has approved each so far one by one.

## Access (no secrets here)

| What | How |
|---|---|
| Real IPs, hostnames, MACs, admin user | `private/NETWORK.md` (gitignored, local only) |
| Node SSH | Key `~/.ssh/bluecave_rsa` (RSA; in the EBG15 *Authorized Keys*). `ssh -i ~/.ssh/bluecave_rsa -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa <admin-user>@<bluecave-ip>` |
| Main router web UI | User signs in (Claude can't enter passwords). Session auto-logs out after 30 min |
| Main router SSH | Enabled LAN-only, port 22 (**remember to turn it off**, see LOG.md "Changes made outside this repo") |
| Browser | Claude in Chrome. The file upload tool is capped at 10 MB, so the 34.7 MB `.trx` must be selected by the user |

## Artifacts on disk (gitignored)

| Path | What |
|---|---|
| `backup/mtd-20261127-050147/` | **Full NAND backup** (mtd0–14 + `/jffs` + SHA256SUMS, 207 MB). **Not yet copied off the Mac.** Includes `calibration` (irreplaceable) and `nvram.txt` (plain-text passwords) |
| `backup/survey-20261127-050134.txt` | Hardware/firmware survey |
| `firmware/asus-384.46630/` | Official ASUS zip (sha256 `52e64f8a…b81102`), extracted `.trx` `BLUECAVE_3.0.0.4_384_46630-g3e43ad7.trx` (sha256 `c6a523ef…168f9a`), verified HDR0/XRX5/BLUECAVE |
| `out/` | Logs, CI logs (`out/ci/`), OpenSSL symbol analysis (`openssl-imports*.txt`, `not-in-35.txt`, …) |
| `src/` | macOS clone of the fork. **About 45 files are always "modified" (case collisions). Never `git add -A` there** |

## Gotchas learned the hard way

- The fork clone `src/` now has a repo-local `user.email` (GitHub no-reply). The global `~/.gitconfig` is the personal gmail, so **check `git config user.email` in any new clone** before committing.
- Pushing from a scratch HTTPS clone hangs waiting for credentials. Push through `src/` (SSH remote): `git fetch <bare> <branch>` then `git push --force-with-lease=... origin FETCH_HEAD:refs/heads/<branch>`.
- Merlin packages may call ASUS functions that SWRT 5.2.9 lacks (`IS_PTCSRV_LOCKED`, `asus_openssl_crypt`). Gate them, don't stub them.

- `release/src-lantiq/Makefile` is a **symlink** to `../src-rt/Makefile`.
- Upstream packages bring **test private keys**, and GitHub push protection blocks them. Strip `*.pem`/`*.key` that contain `PRIVATE KEY` before committing.
- History rewrites in the fork: do them in a **bare clone** (the macOS worktree has case collisions).
- `docker ps --filter ancestor=` misses containers after the image is rebuilt. The build container is named **`bluecave-builder`**.
- `pkill -f 'scripts/build.sh build'` once killed the real build. Use `docker stop bluecave-builder`.
- macOS vs C-locale `sort` broke `comm`. Use `LC_ALL=C`.
- Merlin's `openssl10-compat` `_Exit(127)`s on uClibc. Don't reintroduce it.

## Open questions for the user

1. ~~Physical access~~: yes. ~~Step 0 method~~: retry the AiMesh upload (chosen 2026-11-27).
2. Upload the `.trx` in the EBG15 UI for attempt 2, and keep the page open.
3. Copy `backup/` off the Mac (USB or trusted cloud).
4. Optional: buy a 3.3 V USB-UART adapter before any OpenSSL 3.5 image.
5. Later: turn off SSH on the main router and remove the key when done. Consider turning off *Web Access from WAN* (see `private/NETWORK.md`).
