# Router and Network Notes

## Network (as found 2026-11-27)

| Device | Model | IP | MAC | Firmware | Notes |
|---|---|---|---|---|---|
| Main router (AiMesh router) | ASUS **ExpertWiFi EBG15** (wired) | `<main-router-ip>` | `<redacted>` | 3.0.0.6.102_46374 | Web UI `<main-router-url>` (DDNS, valid certificate). Admin user `<admin-user>` |
| Node | RT-AX82U | | | | Study |
| Node | EBP15 | | | | |
| Node | ExpertWiFi EBA63 | | | | Living Room |
| Node | ExpertWiFi EBA63 | `<uplink-node-ip>`? | `<redacted>` | | Living Room. **The Blue Cave's uplink** |
| **Blue Cave** | **BLUE CAVE** | **`<bluecave-ip>`** | **`<bluecave-mac>`** | **3.0.0.4.384_32948** (2018-10) | AiMesh node, uplink is wireless 5 GHz through an EBA63. Ports 80, 7788 and 18017 open |
| Build Mac | | `<build-host-ip>` | | | |

The Blue Cave runs **384_32948**, which is older than ASUS's final 384_46630 release.
Because it's a **wireless** AiMesh node, flashing it or taking it out of the mesh drops its backhaul. For flashing, give it a wired connection or a separate test network.

## Survey results (2026-11-27, `backup/survey-20261127-050134.txt`)

| Item | Value |
|---|---|
| SoC | `GRX500 rev 1.2`, machine `EASY350 ANYWAN (GRX350) Router model` |
| CPU | MIPS interAptiv V2.0 @ 800 MHz, `maxcpus=4` on the cmdline. The 3 `processor` entries counted in the survey output are **(unverified)** |
| RAM | 450 MB usable (`mem=480M@512M`) |
| Kernel | `3.10.104 #1 SMP Fri Oct 5 2018`, built with **gcc 4.8.3 (OpenWrt/Linaro 15.05_ltq)**. That's the same toolchain as the SWRT tree, which is good for module ABI |
| Bootloader | `U-Boot-2010.06-03642-g25863ba-dirty-LANTIQ-v-2.3.136` |
| Serial console | `console=ttyLTQ0,115200` |
| Firmware | `3.0.0.4.384_32948-g8ec6a66`, productid `BLUECAVE`, territory `US/01` |
| Boot banks | **Dual-bank A/B** (`active_bank=A`): kernelA/rootfsA and kernelB/rootfsB UBI volumes inside `system_sw` |
| Wi-Fi stack | Lantiq WAVE with `hostapd`/`wpa_supplicant` (nl80211), `drvhlpr`, scripts in `/opt/lantiq/wave/`. wlan1 and wlan3 run as STA for the AiMesh backhaul |
| Load | load average about 8 to 10 while idle as a mesh node, which is worth looking into |

### NAND layout (`/proc/mtd`)

| mtd | Name | Size | Notes |
|---|---|---|---|
| 0 | uboot | 1 MB | **Never write** |
| 1 / 2 | ubootconfigA/B | 256 KB each | U-Boot environment |
| 3 | gphyfirmware | 256 KB | Ethernet PHY firmware |
| 4 | **calibration** | 1 MB | **Wi-Fi calibration, irreplaceable** (gzip data) |
| 5 | bootcore | 16 MB | |
| 6 | system_sw | 94 MB | UBI: kernelA, rootfsA, kernelB, rootfsB, jffs2 (mtd11 to 15) |
| 7 | nvram | 1 MB | Settings |
| 8 | jffs2 | 13 MB | |
| 9 | data2 | 1 MB | |
| 10 | res | 256 KB | |

**The A/B banks are a safety net:** test firmware can go to the inactive bank while the known-good bank stays bootable. How the ASUS/SWRT updater picks a bank still needs checking.

## Enabling SSH on an AiMesh node

Set it on the **main router**: Settings → Administration → System → Enable SSH → **LAN only**. AiMesh normally copies the setting and the admin credentials to the nodes. Turn it off again when you're done.

- 2026-11-27: SSH turned on for the EBG15 (LAN only, port 22, password login). The EBG15 accepted it right away. Copying it to the Blue Cave (384 firmware under an ExpertWiFi 3.0.0.6 router) **worked within about 10 s**. The Blue Cave accepts publickey and password logins on port 22.
- 2026-11-27: password login over SSH failed, either because the password didn't sync or because of a terminal problem. **Key login works:** key `~/.ssh/bluecave_rsa` (RSA, because the 2018 dropbear may not support ed25519) was added to the EBG15 Authorized Keys and reached the node within seconds.
- Use: `SSH_KEY=~/.ssh/bluecave_rsa scripts/router-backup.sh <admin-user>@<bluecave-ip>`, or `ssh -i ~/.ssh/bluecave_rsa -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa <admin-user>@<bluecave-ip>`

## Phase 0 scripts (read-only on the router)

```sh
scripts/router-survey.sh <admin-user>@<bluecave-ip>   # → backup/survey-<date>.txt
scripts/router-backup.sh <admin-user>@<bluecave-ip>   # → backup/mtd-<date>/*.bin + SHA256SUMS
```

- The survey collects kernel, CPU, memory, the MTD layout, modules, firmware version (nvram), dmesg and interfaces.
- The backup reads every `/dev/mtdX`, plus `nvram show` and checksums.
- **`nvram.txt` contains Wi-Fi and admin passwords in plain text.** `backup/` is gitignored. Keep a copy off this machine.
- `cat /dev/mtdX` on NAND skips OOB data and doesn't handle bad blocks. That's fine as a safety copy, but for a bit-exact restore also take a `nanddump` over the UART/U-Boot console later.

## Before the first flash

- [x] Confirm the node model and IP: BLUE CAVE, `<bluecave-ip>`
- [x] Survey done
- [x] Full MTD backup done: `backup/mtd-20261127-050147/` (207 MB). mtd0 to mtd14 size-verified, plus `jffs-files.tar.gz` and `SHA256SUMS`. mtd15 has no /dev node; it's inside the mtd6 dump
- [ ] Backup copied off this Mac
- [ ] UART console connected (3.3 V) and U-Boot reachable
- [ ] Recovery tested: stock `3.0.0.4.384.46630` restorable
- [ ] Node taken out of AiMesh, or on a test network
