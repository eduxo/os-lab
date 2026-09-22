#!/bin/bash
# 4/08 — návrat do výchozího stavu.
#
# Maže se JEN druhý oddíl (repozitář) a kontejner. Prvního oddílu se to
# nedotkne — leží na něm práce ze cvičení 1 a ta s dnešním labem nesouvisí.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
SERVER_KONT="zaloha-$ZAK2"   # až ZA lab-lib.sh: ZAK2 vzniká teprve tam
source "$(dirname "$0")/../../lib/disk-lib.sh"
source "$(dirname "$0")/../../lib/server-lib.sh"
LAB="$HOME/netlab/zalohy"
REPO="$LAB/repo"
zkontroluj_disky 1 || exit 1
DISK="$(labovy_disk 1)"
[ -n "$DISK" ] || { echo "  Labový disk se nepodařilo určit."; exit 1; }
CAST2="$(lsblk -rno NAME,TYPE "/dev/$DISK" 2>/dev/null | awk '$2=="part"{print $1}' | sed -n 2p)"
echo
echo "  Tím smažete repozitář se zálohami na /dev/${CAST2:-?} i kontejner"
echo "  $SERVER_KONT. Prvního oddílu, projektu ani systému se to nedotkne."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aAyY])
    mountpoint -q "$REPO" 2>/dev/null && sudo umount "$REPO"
    if [ -n "$CAST2" ]; then
      # Pojistka: oddíl musí patřit labovému disku. Mazání jinam nepatří.
      if je_labovy "$CAST2"; then
        sudo wipefs -a "/dev/$CAST2" >/dev/null 2>&1 \
          || { echo "  Oddíl se nepodařilo vyčistit."; exit 1; }
      else
        echo "  Odmítám sáhnout na /dev/$CAST2 — není to labový disk."; exit 1
      fi
    fi
    lxc info "$SERVER_KONT" >/dev/null 2>&1 && lxc delete -f "$SERVER_KONT" >/dev/null 2>&1
    rm -rf "$LAB"
    echo "  Hotovo."
    exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
