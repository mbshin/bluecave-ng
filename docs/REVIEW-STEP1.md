# Independent review: step 1 flash (Codex, 2026-11-27)

Reviewer: OpenAI Codex CLI 0.160.0, `codex exec -s read-only`, run on an isolated bundle (public docs, the `rc/ssh.c` / dropbear / Makefile diffs `993adeb230..10681c21c6`, and redacted pre-flight facts). No private data, backups or credentials were given to it.

Question: is it safe to flash the CI image `R5.2.9_30001-gf543003` on the only, wireless-only Blue Cave node now?

## Outcome

- **Verdict: don't flash yet.** This agrees with our own assessment. Step 1 is on hold.
- Code findings, checked against the node's nvram (`backup/nvram-384_46630-*.txt`):

| Finding | Applies to this node? | Action |
|---|---|---|
| Invalid `sshd_port` sets `sshd_enable=0` (lockout) | No (`sshd_port=22`, `sshd_enable=2`), but a real bug | **Fixed** `f7b396110d`: falls back to 22, SSH stays on |
| Host keys in nvram not migrated (fingerprint change) | Yes (`sshd_hostkey`, `sshd_ecdsakey` present) | **Fixed** `f7b396110d`: migrated to `/jffs/.ssh`, mode 0600 |
| Key generation / symlink results unchecked | Yes | **Fixed** `f7b396110d`: falls back to RAM keys. Also fixed `f_size()` returning -1 (true) for a missing file |
| `sshd_authkeys` truncated at 3,499 B | No (568 B) | Left as is |
| `IS_PTCSRV_LOCKED` lockout pre-check gated off | Yes (same as the old 2019.78) | Left as is; reconsider with a newer libptcsrv |
| Forwarding now off by default | Yes | Intended |

## Conditions before any custom flash (from the review, still open)

1. Read the stock `restart_upgrade` end to end: validation, which bank it writes, UBI volume recreate order, error handling. **Do not count on U-Boot falling back to bank B on its own** (unverified).
2. Rehearse Rescue Mode with the official image and a PC/cable. Copy `backup/` off the Mac and verify it.
3. Check ASUS 384 → SWRT nvram compatibility (mesh credentials, SSH, JFFS) and write down a reset, re-pair and rollback procedure.
4. Staged plan: unmodified SWRT baseline before our modified image. Verify the image with full sha256 on the node, not md5.
5. Choose a window where downtime is acceptable, with physical access. A UART adapter is strongly recommended.

## Full review text

**Verdict: don’t flash yet.** The CI image has never booted, the stock upgrade path and recovery behavior are insufficiently verified, and the only management path depends on wireless mesh rejoining and the newly ported SSH service. A successful build and valid image header do not establish those outcomes.

**Brick and recovery risk**

- **CONFIRMED:** The current boot is from bank B. The CI root filesystem needs about 264 LEBs; existing rootfs A has 282, rootfs B 251, and UBI reports 149 available. **UNVERIFIED:** Which bank `restart_upgrade` writes, whether it resizes or recreates volumes, its peak space requirements and bad-block handling, and whether it can complete without damaging the active bank. Arithmetic alone does not prove the update fits. [PREFLIGHT.md:7](PREFLIGHT.md:7)
- **UNVERIFIED:** Whether U-Boot automatically falls back to the other bank after a failed boot, how `update_chk=2` affects that decision, and whether bank A currently contains a bootable recovery image. Do not count bank B—or either bank—as automatic fallback. [FLASHING.md:49](docs/FLASHING.md:49)
- **CONFIRMED:** Bootloader, calibration and NVRAM are separate MTD partitions, and a full NAND backup exists. **UNVERIFIED:** The updater’s actual write boundaries, whether the backup is restorable with available tools, and whether Rescue Mode works on this unit. A backup alone cannot restore an inaccessible or damaged bootloader/calibration partition. The backup had not yet been copied off the Mac in the handoff. [HANDOFF.md:43](docs/HANDOFF.md:43)

**Connectivity risk**

- **CONFIRMED:** The current stock image rejoined the mesh; neither the SWRT base nor this CI image has been device-tested. The packet identifies closed-source AiMesh and wireless components. **UNVERIFIED:** SWRT’s compatibility with the EBG15, retained ASUS 384 settings, radio initialization and wireless backhaul. The claim that “boot, Wi-Fi and AiMesh are unchanged” is not established merely by the SSH diff. [FLASHING.md:27](docs/FLASHING.md:27)
- **CONFIRMED:** The node is wireless-only under the stated constraint, and clients remain attached. If it fails to rejoin, remote SSH and UI access may disappear even if Linux boots. **UNVERIFIED:** A reset will restore mesh membership without reconfiguration. Arrange a recovery window and physical PC/cable access, test stock Rescue Mode first, and ideally have a working UART console. A temporary wired management path and moving clients would reduce risk, but conflict with the documented constraints.

**Diff review**

- **CONFIRMED — SSH can be disabled on upgrade:** An absent, zero, malformed-as-zero, or out-of-range `sshd_port` causes `sshd_enable` to be set to 0 before startup, instead of using the old default port 22. Thus an inherited configuration with an unset port can lose SSH. Check actual NVRAM values before any flash. [rc-ssh.diff:74](diffs/rc-ssh.diff:74)
- **CONFIRMED — host key migration is absent:** Old NVRAM host keys are no longer read; new keys are generated in `/jffs/.ssh`. Existing clients can reject the changed host key. Verify the new fingerprint through a trusted local channel. **UNVERIFIED:** If `/jffs/.ssh` already exists but is unwritable, full, or contains a corrupt key, the code does not fall back to RAM or check key generation, symlink, or file-write results; SSH may fail to start. [rc-ssh.diff:33](diffs/rc-ssh.diff:33)
- **CONFIRMED — key truncation:** `strlcpy` limits the authorized-keys field to 3,499 bytes; later keys or a truncated key can become unusable. **UNVERIFIED:** The actual stored key length and whether the new Dropbear accepts the existing RSA key and signature algorithms. Forwarding also changes to off by default. [rc-ssh.diff:85](diffs/rc-ssh.diff:85)
- **CONFIRMED — lockout check removed:** Without `HAVE_PTCSRV_LOCKED`, this code no longer rejects authentication based on that protection-service lock state, though the diff says event reporting remains. **UNVERIFIED:** Whether another component enforces an equivalent lockout. Password authentication relies solely on `crypt()` when the fallback is disabled; compatibility with the node’s actual stored hash is unverified. [dropbear-gate.diff:24](diffs/dropbear-gate.diff:24)
- **CONFIRMED:** Dropbear now links additional shared libraries, and the build changes remove several explicit algorithm restrictions. **UNVERIFIED:** Runtime library availability, effective compiled algorithm defaults and authentication behavior on the image. OpenSSL 3.5 is reported disabled, so its untested shim is not an established cause of failure for this artifact; verify the artifact’s actual configuration and libraries. [build-makefiles.diff:91](diffs/build-makefiles.diff:91)

**Before reconsidering**

1. **UNVERIFIED:** Inspect the stock `restart_upgrade` implementation end to end: image validation, write targets, UBI resize order, error handling, bank selection and bootloader fallback. Confirm available RAM and `/tmp` space, full artifact SHA-256 after transfer, and exact image identity; an MD5 transfer check alone is insufficient evidence of provenance.
2. **UNVERIFIED:** Test Rescue Mode with the verified stock image and a directly connected PC; establish how to recover if rescue fails. Copy and verify the sensitive NAND/NVRAM backup off the Mac. Do not blindly restore raw NAND or NVRAM across firmware versions.
3. **UNVERIFIED:** Establish ASUS 384 → SWRT NVRAM compatibility, including mesh credentials, SSH settings, JFFS mounting and downgrade behavior. Save the current configuration and document a factory-reset, re-pair and stock rollback procedure. A reset can erase mesh settings; preserving them can carry incompatible values.
4. **CONFIRMED:** The documented staged plan calls for a known SWRT build and then the unmodified CI baseline before the modified image; neither has been flashed. **UNVERIFIED:** Even those stages would prove this image safe, but they would isolate failures. Resolve the recovery and connectivity conditions first, then test in stages with explicit acceptance of downtime.