# Handoff — 2026-11-27 06:02 KST

Snapshot for whoever picks this up next (human or agent). Read this first, then [PLAN.md](PLAN.md) and [LOG.md](LOG.md).

## TL;DR

- **Device:** one ASUS Blue Cave, a **wireless leaf AiMesh node** under an ExpertWiFi EBG15. **Healthy and unchanged**: stock `3.0.0.4.384_32948-g8ec6a66` (2018), up 6 days, in the mesh. **Nothing has been flashed.**
- **Step 0** (official ASUS `384.46630` through the main router's AiMesh *Manual firmware update → Upload*) was **attempted and didn't apply**. The image started arriving on the node (`/tmp/linux.trx` reached 21.3 of 34.7 MB at 05:58), then was discarded. No flash, no reboot. **Likely cause:** the main router's web session dropped mid-transfer (new login at 05:59:11). Not proven. The EBG15 log has no node-upgrade entries. Node flags afterwards: `upgrade_fw_status=4`, `webs_state_error=1` (meaning unknown).
- **Firmware source:** `mbshin/bluecave-asuswrt@bluecave-ng` has dropbear 2026.94, OpenSSL 3.5 (off) and the Blue Cave OpenSSL 1.0 shim. **None of it has compiled yet.**
- **CI:** the first runs failed in setup (missing `libltdl-dev`), not because of our changes. Fixed in `2edee50`, and **reruns are in progress** (`45895086853` bluecave-ng, `45895088817` master).

## State of each workstream

| Workstream | State | Next action |
|---|---|---|
| Step 0: official ASUS 384.46630 on the node | ❌ Attempt 1 didn't apply (see above) | Retry the AiMesh upload and **keep the main router page open and logged in until the node reboots** (~10 min). Watch `/tmp/linux.trx` on the node over SSH. Fallback (needs user OK): flash on the node over SSH with the same verified `.trx` |
| CI firmware build | 🔄 Reruns after the libltdl fix | Check `gh run list -R mbshin/bluecave-ng`. If green, download the `bluecave-<sha>` artifact. If red, see the job summary |
| Local Mac build | ⏹ Stopped (it used the old image without libltdl, so it would fail) | Optional: `scripts/build.sh image && scripts/build.sh build` (slow under emulation; CI is preferred) |
| dropbear 2026.94 + `rc/ssh.c` | ✅ Committed `9923cbafb5` | Needs a green CI build |
| OpenSSL 3.5 | ✅ Imported and wired in (`d2a52749e2`, `2bae6f2d09`), **off** | Turn on `OPENSSL35=y` in a branch once the baseline is green |
| Blue Cave openssl10 shim | ✅ Written `323c076cdc` (36 symbols + `make check` for 151) | Compiles only with OPENSSL35. Then disassembly spot-check of the cfg_*/libvpn macros |
| Private OpenSSL 1.0.2u for Lantiq hostapd/wpa_supplicant | ⏳ Not started | Launch path: `fapi_wlan_wave_lib_common.sh` does `cp -s ${BINDIR}/hostapd /tmp/hostapd_<radio>` (a symlink), so use DT_RUNPATH on the binary or a wrapper at `${BINDIR}` |
| dnsmasq / curl / miniupnpd / zlib / openvpn | ⏳ Planned | [PACKAGES.md](PACKAGES.md) |
| Merlin `384.14_x` rc/httpd port, WireGuard | ⏳ Planned | [PLAN.md](PLAN.md) Phase 4 |

## Hard constraints from the user

1. **One Blue Cave, no spare, no test environment.** Every flash is to the real device.
2. **Can't change the current configuration:** no cable, no rewiring, the node stays a wireless AiMesh node, clients stay.
3. Therefore: official images go through the **AiMesh manual upload**. Custom images go **directly to the node** (SSH or the node UI) over Wi-Fi and must rejoin the mesh on their own. Recovery is **physical** (reset button / Rescue Mode). **Still unanswered: can the user physically reach the device for recovery?**
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

- `release/src-lantiq/Makefile` is a **symlink** to `../src-rt/Makefile`.
- Upstream packages bring **test private keys**, and GitHub push protection blocks them. Strip `*.pem`/`*.key` that contain `PRIVATE KEY` before committing.
- History rewrites in the fork: do them in a **bare clone** (the macOS worktree has case collisions).
- `docker ps --filter ancestor=` misses containers after the image is rebuilt. The build container is named **`bluecave-builder`**.
- `pkill -f 'scripts/build.sh build'` once killed the real build. Use `docker stop bluecave-builder`.
- macOS vs C-locale `sort` broke `comm`. Use `LC_ALL=C`.
- Merlin's `openssl10-compat` `_Exit(127)`s on uClibc. Don't reintroduce it.

## Open questions for the user

1. Physical access to the Blue Cave for recovery?
2. OK to retry step 0 (AiMesh upload, keeping the page open), or to flash step 0 over SSH on the node?
3. Copy `backup/` off the Mac (USB or trusted cloud).
4. Optional: buy a 3.3 V USB-UART adapter before any OpenSSL 3.5 image.
5. Later: turn off SSH on the main router and remove the key when done. Consider turning off *Web Access from WAN* (see `private/NETWORK.md`).
