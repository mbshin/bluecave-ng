#!/usr/bin/env bash
# Read-only survey of the Blue Cave over SSH. Changes nothing on the router.
# usage: scripts/router-survey.sh [user@]<main-router-ip> [port]
set -euo pipefail
HOST=${1:?usage: $0 [user@]host [port]}; PORT=${2:-22}
OUT="$(dirname "$0")/../backup/survey-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$OUT")"
ssh -p "$PORT" -o ControlMaster=auto -o ControlPath=/tmp/bluecave-ssh-%r@%h:%p -o ControlPersist=120 -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa "$HOST" '
  for c in "uname -a" "cat /proc/version" "cat /proc/cpuinfo" "cat /proc/meminfo" \
           "cat /proc/mtd" "cat /proc/partitions" "df -h" "mount" "lsmod" "ls /lib/modules/*/" \
           "nvram get firmver" "nvram get buildno" "nvram get extendno" "nvram get productid" \
           "nvram get odmpid" "nvram get bl_version" "nvram get territory_code" \
           "cat /proc/cmdline" "dmesg | head -200" "ifconfig -a" "ps w"; do
    echo "===== $c"; sh -c "$c" 2>&1
  done' | tee "$OUT"
echo "saved: $OUT"
