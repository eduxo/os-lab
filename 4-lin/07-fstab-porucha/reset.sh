#!/bin/bash
# 4/07 — návrat do výchozího stavu: fstab se vrátí do správné podoby
# a start.sh nasadí závadu znovu.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/disk-lib.sh"
LAB="$HOME/netlab/emergency"
ZALOHA="$LAB/fstab.pred-cvicenim"
ZALOHA_SYS="/etc/fstab.zaloha"
ZNACKA="$LAB/.zavada"
ZDROJ=""
[ -s "$ZALOHA" ] && ZDROJ="$ZALOHA"
[ -z "$ZDROJ" ] && [ -s "$ZALOHA_SYS" ] && ZDROJ="$ZALOHA_SYS"
echo
if [ -z "$ZDROJ" ]; then
  echo "  Zálohu fstab nenajdu ani v $ZALOHA, ani v $ZALOHA_SYS."
  echo "  Řekněte o tom vyučujícímu — fstab neupravujte naslepo."; echo
  exit 1
fi
echo "  Tím vrátíte /etc/fstab do správné podoby a dostanete novou závadu."
echo "  Disky ani data se nemění."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aAyY])
    sudo cp "$ZDROJ" /etc/fstab || { echo "  Vrácení se nepodařilo."; exit 1; }
    rm -f "$LAB/.proslo-startem"
    rm -f "$ZNACKA"
    echo "  Hotovo."
    exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
