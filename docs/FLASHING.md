# Flashing a Build to the Blue Cave

> Status 2026-11-27: **no build has been flashed yet.** Follow the order below. Don't skip steps.

## Single-device reality

There's **one Blue Cave and no spare**, so every flash goes to the real unit. That's acceptable because of its role:

- It's a **leaf AiMesh node** serving ~1 client. The main router and the other nodes carry the network. If the Blue Cave goes down, **the network stays up**, so the Blue Cave is its own test device.
- "Test network" just means **a cable**. Connect a Blue Cave LAN port to a spare LAN port on the main router (or any wired node) and flash over the cable. Don't flash while relying on its wireless backhaul.
- The real risk is the **device**, not the network. The protection is the NAND backup (done; copy it off the Mac), Rescue Mode and stock `.trx` restore, and, for anything beyond step 3, a **UART console** (3.3 V USB-TTL adapter, about $5).
- Move its client (the smart speaker) to another node first, so nothing depends on it during testing.

## Constraint: no configuration changes (2026-11-27)

The user can't rewire or change the network: no cable, the Blue Cave stays a **wireless AiMesh node** and clients stay where they are. Consequences:

- **Step 0 (official ASUS image)** goes through **AiMesh firmware update from the main router**, over the existing wireless backhaul. This is the standard ASUS path; settings are kept and the node rejoins automatically.
- **Custom images (steps 1–4)** can't be pushed by AiMesh. They must be uploaded to the node directly (SSH or the node's own UI) over Wi-Fi, and after reboot the node must **rejoin the mesh wirelessly on its own**. If it doesn't, the only recovery is **physical**: reset button or Rescue Mode at the device.
- **Open question:** physical access to the Blue Cave (power, reset button) for recovery. Without it, stop after step 0.

## What's safe to flash, and when

| Image | Contents | Flash? |
|---|---|---|
| **ASUS official `3.0.0.4.384.46630`** | Final ASUS release (2021). The unit runs 384_32948 (2018) | ✅ **Step 0.** Nearly risk-free, real fixes, and a rehearsal of the cable, upload and AiMesh re-join procedure on the only unit. Also use it to rehearse **Rescue Mode** |
| SWRT R5.2.9 prebuilt (SourceForge) | Upstream SWRT, built by its maintainer | ✅ **Step 1.** It proves the custom-firmware flash and AiMesh path with an image others already use |
| CI `master` build (`bluecave-<sha>.trx`) | Our build of the unmodified SWRT 5.2.9 | ✅ After the step above. It validates **our** toolchain and build |
| CI `bluecave-ng` build, OpenSSL 1.0 default | SWRT + dropbear 2026.94 + new `rc/ssh.c` | ⚠️ After `master` works. Risk: SSH start-up. Boot, Wi-Fi and AiMesh are unchanged |
| `bluecave-ng` with `OPENSSL35=y` | + OpenSSL 3.5, shim, private 1.0.2u for Wi-Fi | ❌ **Not yet**, and **only with a UART console connected**. Needs the hostapd/wpa_supplicant work. On-device testing of AiMesh, VPN and the web UI is the only way to catch 1.0 macro struct access in blobs |

## Before any flash

- [x] Full NAND backup, including **`calibration`** (mtd4), with SHA256SUMS. Copy it **off the Mac**.
- [ ] **Wired connection** to a spare LAN port on the main router or a wired node. The Blue Cave is a *wireless* AiMesh node, and flashing or resetting drops the backhaul.
- [ ] Move its client(s) to another node.
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
