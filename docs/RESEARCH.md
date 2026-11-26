# ASUS Blue Cave: Firmware Research

_Researched 2026-11-27. Anything marked **(unverified)** still needs checking on a real unit or in the source._

## 1. Hardware

| Item | Value | Notes |
|---|---|---|
| SoC | Intel/Lantiq **GRX350** (xRX500 family, "AnyWAN"), MIPS interAptiv | Not Broadcom. This is why stock Merlin can't build it |
| Wi-Fi | Intel **WAVE500**-family radios | Proprietary driver from Intel's UGW SDK. No mainline Linux driver found |
| Boot | U-Boot on NAND | `u-boot-nand.bin` is in the SWRT tree |
| Datapath | Lantiq PPA / TMU / GPHY firmware, EIP97 crypto | All blobs from the vendor SDK |

**Confirmed on the device on 2026-11-27.** See ROUTER.md → Survey results for: GRX500 rev 1.2 / EASY350 ANYWAN (GRX350), interAptiv @ 800 MHz, 450 MB RAM, dual-bank A/B NAND, U-Boot 2010.06 LANTIQ v2.3.136. Commands used: `uname -a`, `cat /proc/cpuinfo`, `cat /proc/mtd`, `lsmod`, `nvram get buildno`.

## 2. Official ASUS status

- **End of life.** ASUS says: *"This model was end of its life, and its firmware, utility, website, and manual will no longer be updated."*
- The last stable release is **3.0.0.4.384.46630 (2021-05-14)**. A 9.0.0.4.384.46629 beta (2021-02-02) carried dnsmasq CVE fixes.
- So the ASUS base stops at the **384** branch. The Blue Cave never got the 386, 388 or 3006 code bases.
- The ASUS support page doesn't list a GPL tarball. The SWRT README sends people to support.asus.com for it.

## 3. Existing third-party projects

| Project | Base | Last activity | Status |
|---|---|---|---|
| [SWRT-dev/bluecave-asuswrt](https://github.com/SWRT-dev/bluecave-asuswrt) (maintainer: paldier) | ASUS 384 GPL plus parts of Merlin NG, tree `release/src-lantiq` | Commit "Bumped version to 5.2.9" on **2026-01-27**. SourceForge build R5.2.9 uploaded 2026-03-16 | **Alive but slow.** One maintainer, a few releases a year, very few downloads (about 30 per build) |
| [kimiazhu/bluecave-merlin](https://github.com/kimiazhu/bluecave-merlin) | Fork of SWRT, base 384.45149 | 2019-05-17 | Abandoned |
| [paldier/K3C](https://github.com/paldier/K3C) | OpenWrt/UGW for the Phicomm K3C (also GRX350 + WAVE500) | 2020-09-24 | Dormant. Useful as a reference for the vendor kernel and UGW |
| [RMerl/asuswrt-merlin.ng](https://github.com/RMerl/asuswrt-merlin.ng) | Latest tag **3006.102.9**, last push 2026-11-25 | Active | **Broadcom only.** It doesn't support the Blue Cave and never has |
| OpenWrt (mainline) | n/a | n/a | **No support.** A GRX350 patch from Hauke Mehrtens was never accepted upstream, and OpenWrt's lantiq target only takes code that's already upstream |

Prebuilt SWRT images: <https://sourceforge.net/projects/swrt/files/ASUS/BLUECAVE/> (R5.2.7, R5.2.8, R5.2.9, each about 36 MB `.trx`).

## 4. What's inside the SWRT tree

From the GitHub API, under `release/src-lantiq/`:

- **Kernel:** `linux/linux-3.10.104`. The vendor tree is still **Linux 3.10**, which reached EOL upstream in 2017.
- **Version:** `version.conf` gives `SERIALNO=384`, so the platform layer is ASUS 384.
- **Proprietary SDK blobs (`proprietary/`):**
  - UGW SDKs `sdk_7.2pr1`, `7.2mr1`, `7.2.1.20`, `7.2.1.21`, `7.2.4.4`
  - `rom_lantiq_05.04.00.{61,84,131}`, which hold the WAVE500 driver and firmware, with SWRT patches
  - `gphy_firmware.img`, `ltq_eip97_1.2.2x`, `u-boot-nand.bin`, `dts/`
- **Build:** Ubuntu or Fedora host with 32-bit libs, then `cd release/src-lantiq && make bluecave`. The toolchain ships with the tree.
- **README warning:** the "P_" overclocked builds need you to *"ensure that the CPU does not overheat"*.

## 5. Constraints that shape any plan

1. **The kernel is stuck at 3.10** as long as Wi-Fi has to work. The WAVE500 driver, PPA/datapath and TMU are binary modules built for that kernel. Without them you get no Wi-Fi and no hardware NAT.
2. **Mainline OpenWrt isn't realistic.** You'd need SoC support upstream plus a new Wi-Fi driver. That's years of work, not a fork.
3. **You can't rebase "up-to-date Merlin" directly.** Merlin 3006/388 is built on ASUS's Broadcom GPL. Lantiq code paths (`RTCONFIG_LANTIQ`, `src-lantiq`) exist only in the 384-era ASUS code. What you *can* do is port Merlin's userspace (rc, httpd, web UI, bundled packages) onto the SWRT Lantiq platform layer, which is roughly what SWRT already does piece by piece.
4. **What can be updated:** OpenSSL, dnsmasq, dropbear, curl, busybox, openvpn, the web UI, services, and WireGuard (`wireguard-linux-compat` supports kernels from 3.10) **(unverified on this toolchain)**.
5. **What can't be updated:** the kernel version, the Wi-Fi driver, the datapath, and the bootloader. Bootloader changes are possible but carry the highest risk of bricking.

## 6. Open questions

- [x] Toolchain version: **gcc 4.8.3 (Linaro) with uClibc 0.9.33.2**, `mips-openwrt-linux-uclibc-`, in `release/src-lantiq/tools/`. The host binaries are **32-bit i386 ELF**. gcc 4.8 can compile C99/C11 code, but uClibc 0.9.33 lacks newer libc APIs (for example `getrandom`), so modern packages will need compatibility shims. A newer toolchain would have to stay ABI-compatible with the vendor blobs.
- [x] macOS clone: 45 kernel header paths collide because APFS is case-insensitive (`xt_TCPMSS.h` vs `xt_tcpmss.h` and so on). **Build only from a case-sensitive filesystem**, meaning the Docker volume.
- [ ] Does SWRT 5.2.9 actually build in Docker on Apple Silicon? It probably needs an x86_64 VM or container.
- [ ] Which files does SWRT take from Merlin NG, and from which Merlin version?
- [ ] Can I get the ASUS GPL tarball for 384.46630 to check against SWRT?
- [ ] The NAND layout and where the Wi-Fi calibration data is stored, before flashing anything.

## Sources

- ASUS Blue Cave support/firmware page: <https://www.asus.com/supportonly/blue%20cave/helpdesk_bios/>
- SWRT-dev/bluecave-asuswrt: <https://github.com/SWRT-dev/bluecave-asuswrt> (commits, releases, README)
- SWRT Blue Cave builds: <https://sourceforge.net/projects/swrt/files/ASUS/BLUECAVE/>
- kimiazhu/bluecave-merlin: <https://github.com/kimiazhu/bluecave-merlin>
- paldier/K3C: <https://github.com/paldier/K3C>
- GitHub topic grx350: <https://github.com/topics/grx350>
- Asuswrt-Merlin NG: <https://github.com/RMerl/asuswrt-merlin.ng>
- OpenWrt forum, "The abandonment of LANTIQ (WAV300/600 Intel InterAptiv)": <https://forum.openwrt.org/t/the-abandonment-of-lantiq-wav300-600-intel-interaptiv/95193>
- SNBForums "Blue Cave support" thread: <https://www.snbforums.com/threads/blue-cave-support.55210/> (blocked to automated fetch, not read)
- OpenWrt ToH Blue Cave page: blocked to automated fetch, not read
