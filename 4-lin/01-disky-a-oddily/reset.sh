#!/bin/bash
# 4/01 — návrat do výchozího stavu: labový disk se vyčistí.
# Projektového ani systémového disku se to nedotkne — uvolni_disk je odmítne.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/disk-lib.sh"
LAB="$HOME/netlab/disky"
zkontroluj_disky 1 || exit 1
DISK="$(labovy_disk 1)"
[ -n "$DISK" ] || { echo "  Labový disk se nepodařilo určit."; exit 1; }
echo
echo "  Tím smažete VŠECHNO na /dev/$DISK — oddíly, souborový systém i data."
echo "  Ročníkového projektu ani systému se to nedotkne."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aAyY])
    if uvolni_disk "$DISK"; then
      rm -rf "$LAB"
      echo "  Disk /dev/$DISK je prázdný."
      exec "$(dirname "$0")/start.sh"
    else
      echo "  Disk se nepodařilo uvolnit — řekněte o tom vyučujícímu."; exit 1
    fi ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
