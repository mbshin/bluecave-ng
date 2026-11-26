# OpenSSL 1.0 → 3.5: Prebuilt Blob ABI Analysis

_2026-11-27. Raw data is in `out/` (gitignored): `openssl-linked.txt`, `openssl-blobs.txt`, `openssl-imports.txt` (symbol ⇥ blob), `openssl-imports-union.txt`, `shim-missing.txt`, `missing-direct.txt`, `missing-removed.txt`._

## 1. What links OpenSSL 1.0 and can't be rebuilt

A scan of every MIPS ELF in `src/router` and `src-lantiq/proprietary` found **53** prebuilt binaries linked against OpenSSL. 52 use 1.0.0. The 53rd, `APP-IPK/.../dm2_nzbget`, uses 0.9.8, is an optional package and is already broken, so it's ignored.

| Area | Blobs | Feature | Needed? |
|---|---|---|---|
| **Wi-Fi (Lantiq WAVE)** | `rom_lantiq_05.04.00.{84,131}_patch/opt/lantiq/bin/hostapd`, `wpa_supplicant` | AP and AiMesh backhaul STA | **Essential** |
| **AiMesh** | `cfg_mnt/prebuild/cfg_server`, `cfg_client`, `cfg_reportstatus`, `amas-utils/prebuild/libamas-utils.so`, `amas-utils-cli` | Mesh control plane | **Essential** (while it's a mesh node) |
| VPN | `libvpn/prebuild/libvpn.so` | VPN Fusion / vpnc | High |
| Let's Encrypt | `libletsencrypt/prebuild/libletsencrypt.so` | DDNS certificates | Medium |
| Security / DPI | `asd/prebuild/asd`, `ahs/prebuild/ahs`, `libasc/prebuild/libasc.so` | ASUS security daemon | Medium |
| Remote / app | `aaews/prebuild/aaews`, `mastiff`, `asusnatnl/.../libasusnatnl.so`, `wb/prebuild/libws.so`, `nt_center/prebuild/*` | ASUS Router app, notifications | Optional |
| Cloud / USB | `lighttpd-1.4.39/prebuild/mod_*.so` (AiCloud), `webdav_client`, `asuswebstorage`, `dropbox_client`, `ftpclient` | AiCloud / cloud sync | Optional (can be turned off) |
| Bluetooth | `bluez-5.41/prebuild/*` | BT onboarding | Optional |

**Mixed processes:** the open-source `httpd` and `rc` link `libvpn.so`, `libletsencrypt.so` and `libamas-utils.so`. `cfg_mnt` links `libamas-utils.so`. So **one process will see both the 1.0 ABI (from blobs) and whatever the open-source code links.** Running a real 1.0.2 next to 3.5 in the same process would cause symbol clashes, because 1.0.2 symbols are unversioned.

## 2. Symbol coverage

| | Count |
|---|---|
| Distinct OpenSSL symbols the blobs import | **308** |
| Already in Merlin `openssl10-compat/*.map` | 43 |
| Missing from the shim, but **same name in 3.5** (simple forward) | **230** |
| Missing from the shim and **removed in 3.5** (need an implementation) | **35** |

The 35 removed symbols, with their replacements:

| Group | Symbols | 3.5 replacement |
|---|---|---|
| Locking / threads (no-ops since 1.1) | `CRYPTO_num_locks`, `CRYPTO_set_locking_callback`, `CRYPTO_set_dynlock_{create,lock,destroy}_callback`, `CRYPTO_THREADID_set_{callback,numeric}` | return 1 / no-op |
| Init / cleanup (automatic since 1.1) | `SSL_library_init`, `SSL_load_error_strings`, `ERR_free_strings`, `EVP_cleanup`, `ENGINE_cleanup`, `CRYPTO_cleanup_all_ex_data`, `ENGINE_load_dynamic` | `OPENSSL_init_ssl()` / no-op |
| Version | `SSLeay`, `SSLeay_version` | Return a **1.0.2-era version number**, because blobs may branch on it, and `OpenSSL_version()` |
| Methods | `SSLv23_method`, `SSLv23_server_method` | `TLS_method`, `TLS_server_method` |
| Stacks | `sk_new_null`, `sk_free`, `sk_num`, `sk_value`, `sk_push`, `sk_pop`, `sk_pop_free` | `OPENSSL_sk_*` |
| Renamed getters | `EVP_PKEY_id`, `EVP_PKEY_bits`, `EVP_CIPHER_CTX_block_size`, `SSL_cache_hit`, `SSL_get_peer_certificate`, `get_rfc3526_prime_1536`, `OpenSSLDie` | `EVP_PKEY_get_id`, `EVP_PKEY_get_bits`, `EVP_CIPHER_CTX_get_block_size`, `SSL_session_reused`, `SSL_get1_peer_certificate` (**refcount differs**), `BN_get_rfc3526_prime_1536`, `OPENSSL_die` |
| Ex-data indexes | `SSL_get_ex_new_index`, `SSL_SESSION_get_ex_new_index` | `CRYPTO_get_ex_new_index(CRYPTO_EX_INDEX_SSL…)` |
| State | `SSL_state` | `SSL_get_state()` mapped to the 1.0 numeric states (**approximate**) |

Removed-symbol users: Lantiq `hostapd` 17, `wpa_supplicant` 20, `libasusnatnl` 18, `mod_smbdav` 3, AiMesh `cfg_*`/`libamas-utils` 2 each, `libvpn`/`libletsencrypt` 1 each.

## 3. The risk symbols can't show: struct ABI

1.0-era code may **allocate OpenSSL structs on the stack or read fields directly** (`EVP_MD_CTX ctx; EVP_DigestInit(&ctx…)`, `HMAC_CTX`, `EVP_CIPHER_CTX`, `ssl->s3->…`, `x509->cert_info`). In 1.1 and later those structs are opaque and differ in size, so a forwarding shim **corrupts memory** for any blob that does this. A symbol list doesn't reveal it. Signs to look for:
- Imports of `EVP_MD_CTX_init`, `EVP_CIPHER_CTX_init`, `HMAC_CTX_init`, `*_cleanup` without a matching `*_new`/`*_create`
- Disassembly showing struct-offset loads after calls such as `SSL_get_current_cipher`

**hostapd/wpa_supplicant are the likeliest offenders**, because upstream `crypto_openssl.c` uses stack contexts under `OPENSSL_VERSION_NUMBER < 0x10100000L`.

**Confirmed (2026-11-27):** only the Lantiq `hostapd` and `wpa_supplicant` (both ROM versions) import `EVP_MD_CTX_init`, `EVP_MD_CTX_cleanup`, `HMAC_CTX_init` and `HMAC_CTX_cleanup`. Those functions are only used with **caller-allocated (stack) contexts**, so the shim **cannot** serve these two binaries. They must use a real OpenSSL 1.0.2u. **No other blob imports these functions.** That's a good sign for the shim path, though a disassembly spot-check is still worth doing.

**Security review follow-up (2026-11-27):** `X509_STORE_CTX` was public in 1.0 and could be stack-allocated before `X509_STORE_CTX_init`. Its only non-Wi-Fi importer, `libvpn.so`, also imports `X509_STORE_CTX_new` and `X509_STORE_CTX_free`, which is the heap pattern. No non-Wi-Fi blob imports `BN_init`, `BN_CTX_init`, `EVP_CIPHER_CTX_init`, `HMAC_Init` or `EVP_MD_CTX_init`. AiMesh `cfg_*`, `libamas-utils` and `bluetoothd` use `EVP_CIPHER_CTX_new` (heap).
**Residual risk symbols can't show:** 1.0 header **macros that read struct fields directly** (for example `X509_get_notBefore/notAfter` → `x->cert_info->validity`, and `M_ASN1_*`). These compile to inline loads with no import. They have to be found by disassembly spot-checks or by **on-device testing with a UART console**.

## 3b. Exact gap: 40 symbols not exported by OpenSSL 3.5

(308 imported − 268 that 3.5 exports by name.)

- **libcrypto side (31):** `CRYPTO_THREADID_set_callback`, `CRYPTO_THREADID_set_numeric`, `CRYPTO_cleanup_all_ex_data`, `CRYPTO_num_locks`, `CRYPTO_set_dynlock_{create,destroy,lock}_callback`, `CRYPTO_set_locking_callback`, `ENGINE_cleanup`, `ENGINE_load_dynamic`, `ERR_free_strings`, `EVP_CIPHER_CTX_block_size`, `EVP_MD_CTX_init`†, `EVP_MD_CTX_cleanup`†, `EVP_PKEY_bits`, `EVP_PKEY_id`, `EVP_cleanup`, `HMAC_CTX_init`†, `HMAC_CTX_cleanup`†, `OPENSSL_add_all_algorithms_noconf`, `OpenSSLDie`, `SSLeay`, `SSLeay_version`, `get_rfc3526_prime_1536`, `sk_{free,new_null,num,pop,pop_free,push,value}`
- **libssl side (9):** `SSL_SESSION_get_ex_new_index`, `SSL_cache_hit`, `SSL_get_ex_new_index`, `SSL_get_peer_certificate`, `SSL_library_init`, `SSL_load_error_strings`, `SSL_state`, `SSLv23_method`, `SSLv23_server_method`

† stack-context functions. Only hostapd/wpa_supplicant use them (served by real 1.0.2u). The shim may leave them out.

## 3c. Shim design for the Blue Cave (differs from Merlin)

Merlin's `openssl10-compat` **can't be used as-is**:
1. `compat_getenv()` calls `compat_fatal()` (`_Exit(127)`) when it isn't running on glibc. **On uClibc every process that loads the shim would exit immediately.**
2. Its `libssl.map` exports **nothing** (`local: *`). It only provides the SONAME for Trend Micro HNS.
3. Each export is a hand-typed wrapper that `dlopen`s `libcrypto.so.3` with `RTLD_LOCAL`. Doing that for 268 symbols would mean transcribing every signature by hand.

**Blue Cave design:**
- `libcrypto.so.1.0.0` (shim) has a **`DT_NEEDED` on `libcrypto.so.3`**, and `libssl.so.1.0.0` (shim) on `libssl.so.3` plus the crypto shim. The 268 same-name symbols then resolve **directly by name** from the 3.5 libraries in the process's global scope. No wrappers are needed, and mixed processes (`httpd`/`rc` + blob libs) behave the same way.
- The shim exports only the **31 + 9** symbols above, plus 1.0-semantics overrides where needed (`CRYPTO_malloc(int,…)`, one-argument `CRYPTO_free`; both are harmless on 32-bit MIPS even if 3.5's version is picked).
- **No environment checks and no `dlopen`.** uClibc 0.9.33 `ld.so` resolves by name and ignores symbol versions.
- **Build-time check:** a script makes sure every symbol in `openssl-imports-union.txt` is exported by shim ∪ `libcrypto.so.3` ∪ `libssl.so.3`.

## 4. Recommended design: hybrid

| Consumer | Links | Why |
|---|---|---|
| All open-source code (httpd, rc, openvpn, curl, dropbear, ...) | **OpenSSL 3.5** (`libssl.so.3`) | Main security goal. httpd (web UI TLS) and openvpn are the exposed parts |
| Blobs that share a process with open-source code or are network-facing (libvpn, libletsencrypt, libamas-utils, cfg_*, aaews, asd, nt_center, ...) | **Extended `openssl10-compat` shim** → 3.5 | Avoids two OpenSSLs in one process. Extend the shim by 230 forwards and 35 implementations |
| **Lantiq hostapd / wpa_supplicant** | **Private real OpenSSL 1.0.2u**, installed in e.g. `/usr/lib/ossl10/` and selected by a `DT_RUNPATH` patch (`patchelf --set-rpath`) or a wrapper with `LD_LIBRARY_PATH` | Standalone processes. Highest struct-ABI risk, and Wi-Fi must not break. Exposure is local WPA crypto, not internet TLS. EAP-TLS (enterprise) is the one TLS path |
| Optional blobs (AiCloud, cloud sync, Bluetooth, nzbget) | Shim if it works, else **turn off the feature** | Not worth the risk |

The real 1.0.2u only needs to be a **separate SONAME location** that the shim doesn't occupy. Because 1.0.2 and the shim share the SONAME `libcrypto.so.1.0.0`, keep the real one **out of the default library path**.

## 5. Work items

- [ ] Generate the shim's forwarding entries for the 230 same-name symbols (script from `missing-direct.txt`). Use plain `dlsym` forwarding as in Merlin's `crypto_compat.c`, or an alias in the version script.
- [ ] Implement the 35 removed symbols (table above). Keep `SSLeay()` returning `0x1000215fL`.
- [ ] Check every blob for stack-allocated contexts (the import patterns in §3, then `objdump -d` around the calls). Start with cfg_server, libvpn and libamas-utils.
- [ ] Build OpenSSL 1.0.2u as a private library for hostapd/wpa_supplicant. Check whether `patchelf` handles these MIPS32 uClibc binaries; otherwise use a wrapper script.
- [ ] Test on the device: Wi-Fi (both bands, WPA2/WPA3 if supported), AiMesh join/backhaul, VPN Fusion, Let's Encrypt, web UI over HTTPS.
