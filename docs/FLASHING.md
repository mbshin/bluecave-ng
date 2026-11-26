# Flashing a Build to the Blue Cave

> Status 2026-11-27: **no build has been flashed yet.** Follow the order below. Don't skip steps.

## What's safe to flash, and when

| Image | Contents | Flash? |
|---|---|---|
| SWRT R5.2.9 prebuilt (SourceForge) | Upstream SWRT, built by its maintainer | ✅ **First step.** It proves the flash and AiMesh path with a known-good image |
| CI `master` build (`bluecave-<sha>.trx`) | Our build of the unmodified SWRT 5.2.9 | ✅ After the step above. It validates **our** toolchain and build |
| CI `bluecave-ng` build, OpenSSL 1.0 default | SWRT + dropbear 2026.94 + new `rc/ssh.c` | ⚠️ After `master` works. Risk: SSH start-up. Boot, Wi-Fi and AiMesh are unchanged |
| `bluecave-ng` with `OPENSSL35=y` | + OpenSSL 3.5, shim, private 1.0.2u for Wi-Fi | ❌ **Not yet.** Needs the hostapd/wpa_supplicant work and on-device testing of AiMesh, VPN and the web UI |

## Before any flash

- [x] Full NAND backup, including **`calibration`** (mtd4), with SHA256SUMS. Copy it **off the Mac**.
- [ ] **Wired connection or isolated test network.** The Blue Cave is a *wireless* AiMesh node, and flashing or resetting drops the backhaul.
- [ ] Remove the node from AiMesh in the main router UI (or accept that you'll re-add it afterwards).
- [ ] Optional but strongly recommended: **UART console** (3.3 V, `ttyLTQ0` 115200 8N1) so a failed boot can be recovered.
- [ ] Know the recovery path. ASUS **Rescue Mode**: power off, hold Reset, power on and keep holding until the LED blinks slowly. Then use the ASUS Firmware Restoration utility or TFTP to `192.168.1.1` with stock `3.0.0.4.384.46630`. Test this **with the stock image first**, if possible.

## How to flash

1. Download the artifact: Actions → run → **bluecave-&lt;sha&gt;** → unzip → `*.trx`.
2. Connect a PC to a Blue Cave LAN port. Factory-reset the node, or open its own web UI.
3. Administration → **Firmware Upgrade** → *Manual firmware update* → upload the `.trx`.
4. Wait 5 minutes without powering off.
5. Check: web UI loads, both bands broadcast, SSH (LAN only), `uname -a`, `nvram get buildinfo`, and AiMesh re-join from the main router.

## A/B banks

The NAND has kernelA/rootfsA and kernelB/rootfsB (`active_bank=A` at survey time). The ASUS/SWRT updater's behaviour (does it write the inactive bank and switch?) is **still unknown**. Until it's confirmed, don't rely on automatic fallback.
