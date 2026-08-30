#!/bin/bash
# 2/13 — návrat do výchozího stavu (uklidí a zavede závady znovu)
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/poruchy.sh"
INST="$HOME/netlab/instalace"
echo
echo "  Tím se stanice uvede do pořádku a závady se zavedou znovu."
echo "  Přijdete o vyplněné nálezy."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aA]|[aA][nN][oO]|[yY]|[yY][eE][sS])
    # Nejdřív úklid, a jen když projde. Kdyby se `zavedeno` smazalo při
    # neúspěšném úklidu, závady by na stanici zůstaly bez záznamu o nich
    # a stop.sh by pak tvrdil, že není co uklízet.
    sudo bash "$(dirname "$0")/uklid.sh" "$LAB_ETC_APT" "$LAB_HOSTS" "$LAB_ZALOHY" || {
      echo "  Úklid selhal — stanice zůstává v současném stavu."; echo; exit 1; }
    rm -rf "${INST:?}"
    echo "  Uklizeno."; exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
