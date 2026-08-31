#!/bin/bash
# 2/18 — úklid: obnoví správná práva. Nikdo nemá odejít od rozbité struktury.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/poruchy.sh"
[ -f "$LAB_ZALOHY/zavedeno" ] || { echo; echo "  Žádné závady zavedené nejsou."; echo; exit 0; }
echo
echo "  Tím se práva vrátí do pořádku a závady zmizí."
echo "  Ve výpisu kontroly pak bude, že cvičení dokončil skript."
read -r -p "  Uklidit? [a/N] " o
case "$o" in
  [aA]|[aA][nN][oO]|[yY]|[yY][eE][sS])
    sudo bash "$(dirname "$0")/uklid.sh" "$LAB_KOREN" "$LAB_ZALOHY" "$(id -un)" || {
      echo "  Úklid selhal — řekněte o tom vyučujícímu."; exit 1; }
    echo "  Hotovo." ;;
  *) echo "  Zrušeno." ;;
esac
echo
