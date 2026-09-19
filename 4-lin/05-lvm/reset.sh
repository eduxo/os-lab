#!/bin/bash
# 4/05 — návrat do výchozího stavu: smaže se LVM i celý sejf.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/disk-lib.sh"
LAB="$HOME/netlab/lvm"
PRIPOJ="$LAB/data"
MAPPER="sejf-$ZAK2"
SKUPINA="data-$ZAK2"
zkontroluj_disky 4 || exit 1
DISK="$(labovy_disk 4)"
echo
echo "  Tím smažete logické svazky i šifrovaný kontejner na /dev/$DISK."
echo "  Budete si muset založit nový sejf — i s novým heslem."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aAyY])
    mountpoint -q "$PRIPOJ" 2>/dev/null && sudo umount "$PRIPOJ"
    # Skupina leží uvnitř sejfu. Kdyby se smazala až s hlavičkou LUKS,
    # zůstaly by po ní zálohy metadat v /etc/lvm/backup a příští vgcreate
    # by hlásil, že skupina už existuje.
    sudo vgchange -an "$SKUPINA" >/dev/null 2>&1
    sudo vgremove -f "$SKUPINA" >/dev/null 2>&1
    uvolni_disk "$DISK" || {
      echo "  Disk se nepodařilo uvolnit — řekněte o tom vyučujícímu."; exit 1; }
    rm -rf "$LAB"
    echo "  Hotovo."
    exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
