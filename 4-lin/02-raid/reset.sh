#!/bin/bash
# 4/02 — návrat do výchozího stavu: pole se rozebere a disky vyčistí.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/disk-lib.sh"
LAB="$HOME/netlab/raid"
zkontroluj_disky 3 || exit 1
DISK_A="${LABOVE_DISKY[1]}"; DISK_B="${LABOVE_DISKY[2]}"
echo
echo "  Tím rozeberete pole a smažete všechno na /dev/$DISK_A a /dev/$DISK_B."
echo "  Prvního labového disku, projektu ani systému se to nedotkne."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aAyY])
    mountpoint -q "$LAB/data" 2>/dev/null && sudo umount "$LAB/data"
    uvolni_disk "$DISK_A" && uvolni_disk "$DISK_B" || {
      echo "  Disky se nepodařilo uvolnit — řekněte o tom vyučujícímu."; exit 1; }
    rm -rf "$LAB"
    echo "  Hotovo."
    exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
