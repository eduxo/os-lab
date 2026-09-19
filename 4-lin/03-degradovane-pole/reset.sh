#!/bin/bash
# 4/03 — návrat do výchozího stavu: pole se rozebere, disky vyčistí a start.sh
# postaví nové pole i s novou poruchou.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/disk-lib.sh"
LAB="$HOME/netlab/degradace"
PRIPOJ="$HOME/netlab/raid/data"
zkontroluj_disky 3 || exit 1
DISK_A="$(labovy_disk 2)"; DISK_B="$(labovy_disk 3)"
echo
echo "  Tím rozeberete pole a smažete všechno na /dev/$DISK_A a /dev/$DISK_B,"
echo "  včetně dat pobočky. Projektového ani systémového disku se to nedotkne."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aAyY])
    mountpoint -q "$PRIPOJ" 2>/dev/null && sudo umount "$PRIPOJ"
    uvolni_disk "$DISK_A" && uvolni_disk "$DISK_B" || {
      echo "  Disky se nepodařilo uvolnit — řekněte o tom vyučujícímu."; exit 1; }
    rm -rf "$LAB"
    echo "  Hotovo."
    exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
