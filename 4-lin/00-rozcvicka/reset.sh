#!/bin/bash
# 4/00 — návrat do výchozího stavu.
#
# POZOR: maže JEN rozcvičku. Ročníkového projektu se nedotkne — je na
# vlastním disku a roste celý rok. Kdyby ho reset mazal, stačila by jedna
# ukvapená klávesa a žák přijde o práci za měsíce.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/disk-lib.sh"
ROZ="$HOME/netlab/rozcvicka4"
echo
echo "  Tím smažete podklady i vyplněné odpovědi rozcvičky."
echo "  Ročníkový projekt v $PROJEKT_PRIPOJ zůstane nedotčený."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aAyY])
    rm -rf "$ROZ"
    echo "  Smazáno. Nové podklady vyrobí ./start.sh"
    exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
