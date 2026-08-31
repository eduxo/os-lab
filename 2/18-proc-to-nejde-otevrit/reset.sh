#!/bin/bash
# 2/18 — návrat do výchozího stavu (uklidí a zavede závady znovu)
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/poruchy.sh"
echo
echo "  Tím se práva vrátí do pořádku a závady se zavedou znovu."
echo "  Přijdete o vyplněné nálezy."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aA]|[aA][nN][oO]|[yY]|[yY][eE][sS])
    sudo bash "$(dirname "$0")/uklid.sh" "$LAB_KOREN" "$LAB_ZALOHY" "$(id -un)" || {
      echo "  Úklid selhal, nic se nemění."; exit 1; }
    sudo rm -rf "${LAB_KOREN:?}"
    echo "  Uklizeno."; exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
