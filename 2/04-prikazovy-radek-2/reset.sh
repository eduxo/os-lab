#!/bin/bash
# 2/04 — návrat do výchozího stavu (smaže adresář přijaté pošty)
set -uo pipefail
PRIJEM="$HOME/nakoleni/prijem"
echo
echo "  Tím smažete celý adresář $PRIJEM včetně toho, co jste v něm udělali."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aAyY]) rm -rf "$PRIJEM"; echo "  Smazáno."; exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
