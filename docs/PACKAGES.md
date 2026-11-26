# Package Inventory: SWRT 5.2.9 vs Merlin NG

_Collected 2026-11-27. SWRT versions come from the local tree (`release/src/router/`, shared by `src-lantiq` through a symlink). Merlin versions come from `RMerl/asuswrt-merlin.ng@main` (tag 3006.102.9 era)._

| Package | SWRT 5.2.9 (Blue Cave) | Merlin NG `main` | Gap | Priority |
|---|---|---|---|---|
| **OpenSSL** | **1.0.2u-fips (Dec 2019)** | **3.5.9** (Sep 2026). 1.1 and compat shims also in tree | EOL since 2019, many CVEs | **P0** |
| **dnsmasq** | 2.84 | 2.93 | DNSpooq-era fixes are in 2.83+, later CVEs are not | **P0** |
| **dropbear** | 2019.78 → **2026.94 (done, commit 9923cbafb)** | 2026.94 | Several CVEs, no ed25519, old ciphers | ~~P0~~ |
| **curl** | 7.67.0 | 8.17.0 | Dozens of CVEs | **P1** |
| **miniupnpd** | 1.9 | 2.3.11 (plus `miniupnpd-igdv2`) | Exposed on the LAN, CVEs | **P1** |
| openvpn | 2.4.7 | newer 2.x (exact version to verify) | CVEs. Needs OpenSSL 1.1+ or 3 | P1 |
| zlib | 1.2.5 | 1.3.2 | CVE-2018-25032, CVE-2022-37434 | P1 |
| busybox | 1.25.1 | 1.25.1 (with Merlin patches) | Same base. Take Merlin's patches | P2 |
| sqlite | 3.7.2 | 3.42.0 | Mostly local exposure | P2 |
| lighttpd | 1.4.39 | 1.4.39 | Same | P3 |
| libevent | 2.0.21 | 2.0.21 | Same | P3 |
| pcre | 8.31 | 8.31 | Same | P3 |
| samba | 3.0.33 / 3.5.8 | 3.5.8 / 3.6.x (OpenWrt) | Only if USB sharing is used | P3 |
| iptables | 1.4.21 | 1.4.x / 1.8.11 | Keep 1.4.x (kernel 3.10) | — |
| libxml2 | 2.7.7 | (in tree) | Check | P3 |
| mbedtls | 2.6.0 | (not listed) | Used by what? Check | P2 |
| hostapd / wpa_supplicant | 2.6 / 0.6.10 | Broadcom: not used | **Lantiq WAVE ships its own hostapd** (`/opt/lantiq/wave`). Tied to the vendor driver, so leave it alone | — |
| WireGuard | **absent** | `wireguard-tools` 1.0.20210914 (plus kernel module on newer kernels) | Needs the `wireguard-linux-compat` module built against 3.10 | Feature |

## Porting reference: Merlin 384 branches

Merlin still has the legacy branches `384.4_x`, `384.7_x`, `384.13_x` and `384.14_x` (last commit 2020-04-21). Those **share the ASUS 384 code base with the Blue Cave**, so their `rc`/`httpd`/`www` changes apply much more cleanly than code from 3006. Suggested approach:

1. **Packages (Phase 3):** take the newest versions from Merlin `main`.
2. **rc/httpd/web UI (Phase 4):** cherry-pick from `384.14_x` first, then backport selected newer fixes from `main`.

## Toolchain risks for P0 packages

- **OpenSSL 3.5** needs C99 and atomics. gcc 4.8 is fine. uClibc 0.9.33 has no `getrandom()`, but OpenSSL falls back to `/dev/urandom`. Check the size: libcrypto 3.x is about 4 MB, so check free space in the rootfs.
- **dropbear 2026.x** should build. Turn on ed25519 and turn off legacy ciphers.
- **dnsmasq 2.93** should build. Merlin carries uClibc compatibility patches.
- **Moving off 1.0.2 breaks the ABI:** everything linking libssl/libcrypto has to be rebuilt (httpd, openvpn, curl, wget, aaews, etc.). Watch for **prebuilt binaries** in the tree that link OpenSSL 1.0 (`ldd`/`readelf -d` on `prebuild/` blobs), because those can't be rebuilt.

## OpenSSL migration: findings (2026-11-27)

**How the build picks OpenSSL**
- SWRT `release/src/router/Makefile:441`: `RTCONFIG_OPENSSL11=y` → `openssl-1.1`, `RTCONFIG_OPENSSL10=y` → `openssl-1.0`. This is set from `OPENSSL=11` / `OPENSSL11=y` in the model flags (`src-lantiq/Makefile:1104`).
- The `BLUECAVE` flags in `src-lantiq/target.mak:464` don't set OPENSSL11, so it **defaults to 1.0**. **The SWRT tree has no `openssl-1.1` directory.**
- The flags include `HTTPS=y OPENVPN=y VPNC=y SSH=y BWDPI=y`, so httpd, openvpn and Trend Micro DPI all link OpenSSL.

**How Merlin `main` does it** (`release/src/router/Makefile:842-847, 3878-3935`)
- A third option, `RTCONFIG_OPENSSL35=y` → `openssl-3.5`, configured with `--api=1.1.1 no-async no-tests no-docs no-aria no-sm2 no-sm3 no-sm4 --with-rand-seed=devrandom`, `-ffunction-sections -Wl,--gc-sections`.
- It installs `libcrypto.so.3`, `libssl.so.3`, `/usr/sbin/openssl` and `ossl-modules/legacy.so`.
- **`openssl11-compat`**: a shim that keeps the 1.1 SONAMEs and symbol versions and forwards only the APIs in `libcrypto.map`/`libssl.map` to 3.5. It's for vendor prebuilt blobs.
- **`openssl10-compat`**: the same idea for the **1.0.0 SONAMEs**. It was built for Trend Micro HNS prebuilt payloads. **This is directly relevant to the Blue Cave (`BWDPI=y`, Trend Micro blobs linked against OpenSSL 1.0).**

**Proposed path**
1. Copy `openssl-3.5/`, `openssl10-compat/` and the Makefile rules from Merlin `main` into the fork. Add `OPENSSL35` handling to `src-lantiq/Makefile` save_src_config.
2. Run the prebuilt scan (`out/openssl-linked.txt`) and list the **symbols** each 1.0-linked blob imports (`readelf --dyn-syms`). Compare them with `openssl10-compat/*.map` and add any missing forwards.
3. Fix the open-source code in the tree that uses removed 1.0 APIs (opaque structs since 1.1: `EVP_CIPHER_CTX`, `HMAC_CTX`, `RSA`, and so on). Merlin's 384.14_x and main versions of `httpd`, `rc` and `openvpn` already have these fixes.
4. Fallback if a blob can't be shimmed: drop that feature (for example `BWDPI=n`) instead of keeping OpenSSL 1.0.

### Prebuilt OpenSSL consumers (scan in progress, `out/openssl-linked.txt`)

| Blob | Links | Matters? |
|---|---|---|
| `src/router/libvpn/prebuild/libvpn.so` | libcrypto/libssl **1.0.0** | **Yes.** ASUS VPN (VPN Fusion / vpnc). Check its imported symbols against `openssl10-compat/*.map` |
| `src/router/APP-IPK/DM-ipk/.../dm2_nzbget` | 0.9.8 | No. Optional Download Master package that's already broken (no 0.9.8 on the device) |
