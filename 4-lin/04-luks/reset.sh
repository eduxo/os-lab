#!/bin/bash
# 4/04 — návrat do výchozího stavu: sejf i s daty se smaže.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/disk-lib.sh"
LAB="$HOME/netlab/sejf"
PRIPOJ="$LAB/data"
MAPPER="sejf-$ZAK2"
zkontroluj_disky 4 || exit 1
DISK="$(labovy_disk 4)"
echo
echo "  Tím smažete sejf i všechno, co v něm je, na disku /dev/$DISK."
echo "  Hodí se to, když jste zapomněli heslo — jinak se k datům nedostanete."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aAyY])
    mountpoint -q "$PRIPOJ" 2>/dev/null && sudo umount "$PRIPOJ"
    [ -b "/dev/mapper/$MAPPER" ] && sudo cryptsetup close "$MAPPER"
    uvolni_disk "$DISK" || {
      echo "  Disk se nepodařilo uvolnit — řekněte o tom vyučujícímu."; exit 1; }
    rm -rf "$LAB"
    echo "  Hotovo."
    exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
