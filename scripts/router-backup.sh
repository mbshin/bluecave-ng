#!/usr/bin/env bash
# Dump every MTD partition from the Blue Cave over SSH. Read-only on the router.
# Resumable: pass an existing backup dir as 3rd arg; complete partitions are skipped.
# Keep these files safe: they include factory/calibration data that cannot be regenerated.
# usage: scripts/router-backup.sh [user@]host [port] [existing-backup-dir]
#   env: SSH_KEY=~/.ssh/bluecave_rsa to use key auth
set -uo pipefail
HOST=${1:?usage: $0 [user@]host [port] [dir]}; PORT=${2:-22}
DIR=${3:-"$(dirname "$0")/../backup/mtd-$(date +%Y%m%d-%H%M%S)"}
SSH=(ssh -p "$PORT" -o ControlMaster=auto -o ControlPath=/tmp/bluecave-ssh-%r@%h:%p -o ControlPersist=300
     -o ServerAliveInterval=15 -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa)
[ -n "${SSH_KEY:-}" ] && SSH+=(-i "$SSH_KEY" -o IdentitiesOnly=yes)
SSH+=("$HOST")
mkdir -p "$DIR"
"${SSH[@]}" cat /proc/mtd > "$DIR/proc_mtd.txt" || { echo "ssh failed"; exit 1; }
cat "$DIR/proc_mtd.txt"
[ -s "$DIR/nvram.txt" ] || "${SSH[@]}" 'nvram show 2>/dev/null' > "$DIR/nvram.txt"
fail=0
while read -r dev size _ name; do
  dev=${dev%:}; name=${name//\"/}; want=$((16#$size))
  out="$DIR/$dev-$name.bin"
  have=$( [ -f "$out" ] && stat -f%z "$out" || echo 0 )
  if [ "$have" -eq "$want" ]; then echo "skip $dev ($name): complete"; continue; fi
  if ! "${SSH[@]}" "[ -e /dev/$dev ]" < /dev/null; then echo "skip $dev ($name): no /dev node (UBI volume, contained in system_sw dump)"; continue; fi
  for try in 1 2 3; do
    echo "dumping $dev ($name, $want bytes) try $try..."
    "${SSH[@]}" "cat /dev/${dev}ro 2>/dev/null || cat /dev/$dev" > "$out" < /dev/null
    have=$(stat -f%z "$out")
    [ "$have" -eq "$want" ] && break
    echo "  got $have of $want bytes"
  done
  [ "$have" -eq "$want" ] || { echo "FAILED $dev"; fail=1; }
done < <(grep '^mtd' "$DIR/proc_mtd.txt")
( cd "$DIR" && shasum -a 256 *.bin > SHA256SUMS && ls -la )
[ $fail -eq 0 ] && echo "Backup complete in $DIR. Copy it off this machine too." || { echo "Backup INCOMPLETE"; exit 1; }
