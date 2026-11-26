# Blue Cave NG: Docs

Custom, maintained firmware for the end-of-life **ASUS Blue Cave** (Intel GRX350 + WAVE500). It's based on a fork of SWRT and brings in code from Asuswrt-Merlin (`384.14_x` for rc/httpd/web UI, `main` for packages).

| Doc | Contents |
|---|---|
| [RESEARCH.md](RESEARCH.md) | Hardware, ASUS EOL status, existing projects, constraints, sources |
| [PLAN.md](PLAN.md) | Phased plan with progress checkboxes and next actions |
| [BUILD.md](BUILD.md) | Docker build environment, toolchain, build log, incidents |
| [PACKAGES.md](PACKAGES.md) | Package versions SWRT vs Merlin NG, porting priorities |
| [ROUTER.md](ROUTER.md) | Mesh topology, the Blue Cave node, SSH access, survey results, NAND layout, backup |
| [OPENSSL-ABI.md](OPENSSL-ABI.md) | 52 prebuilt blobs on OpenSSL 1.0: symbol coverage, risks, hybrid design |
| [LOG.md](LOG.md) | Dated log of everything done, external changes and how to undo them |

## Status (2026-11-27)

| Item | State |
|---|---|
| Research | Done |
| Fork | <https://github.com/mbshin/bluecave-asuswrt>. Local clone `src/`, branch `bluecave-ng` **pushed**: <https://github.com/mbshin/bluecave-asuswrt/tree/bluecave-ng> |
| Build image | Done (`bluecave-build`, toolchain verified, git identity added) |
| Baseline build (SWRT 5.2.9) | **Running**: kernel compile stage |
| Router access | SSH LAN-only on the EBG15, key login `~/.ssh/bluecave_rsa` to the Blue Cave `<bluecave-ip>` |
| Survey and NAND backup | **Done**: `backup/` (copy it off this Mac) |
| Package inventory | Done. P0: OpenSSL 1.0.2u → 3.5, dropbear 2019.78 → 2026.94, dnsmasq 2.84 → 2.93 |
| Project docs/scripts | Committed to a **local-only** repo (`~/projects/bluecave`), not pushed because of private network details |
| OpenSSL-linked prebuilt scan | **Done**: 52 blobs on 1.0.0 (incl. Wi-Fi hostapd/wpa_supplicant, AiMesh cfg_*), 308 symbols. See OPENSSL-ABI.md |
| OpenSSL 3.5 | Imported and wired in (commits `e3906ca1bb` + `c20a93bf93`, pushed), **not turned on yet**. Needs shim extension (230 forwards + 35 implementations) and a private 1.0.2u for Wi-Fi |
| dropbear | **2026.94** (commit `8cefebda05`, pushed), not build-tested |
| Merlin port | Not started. Base: Merlin `384.14_x` |

## Key facts

- **Device:** Blue Cave at `<bluecave-ip>`, MAC `<bluecave-mac>`, fw **3.0.0.4.384_32948** (2018). It's a wireless AiMesh node under an ExpertWiFi EBG15.
- **Hardware:** GRX350 (GRX500 rev 1.2), interAptiv @ 800 MHz, 450 MB RAM, NAND with **dual boot banks A/B** (A active).
- **Kernel:** stays at **3.10.104**, because the vendor Wi-Fi and datapath blobs require it. The stock kernel was built with the same gcc 4.8.3 as our toolchain.
- **Toolchain:** gcc 4.8.3 Linaro with uClibc 0.9.33.2. Host binaries are i386 and run under emulation on Apple Silicon.
- **Merlin:** the `main` reference is 3006.102.9, which is Broadcom-only, so we take packages from it. The 384 branches share the Blue Cave's base.
- **Build location:** only from the case-sensitive Docker volume, never from the macOS `src/` clone (45 case collisions).

## Repo layout

```
bluecave/
├── docs/            these docs
├── docker/          build image
├── scripts/         build.sh, router-survey.sh, router-backup.sh
├── src/             fork clone (read and edit only, gitignored)
├── out/             build logs, .trx, scan results (gitignored)
└── backup/          router survey + NAND dumps (gitignored, SENSITIVE)
```
