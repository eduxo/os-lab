#!/bin/bash
# 3/07 — návrat do výchozího stavu (smaže server i vaši práci na něm)
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
KONT="sluzby-$ZAK2"
echo
echo "  Tím smažete server $KONT včetně všeho, co jste na něm udělali."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aAyY]) lxc delete -f "$KONT" >/dev/null 2>&1; echo "  Smazáno."; exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
