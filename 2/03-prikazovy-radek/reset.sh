#!/bin/bash
# 2/03 — návrat do výchozího stavu (smaže vaši práci v ~/nakoleni)
set -uo pipefail
BAZE="$HOME/nakoleni"
echo
echo "  Tím smažete celý adresář $BAZE včetně toho, co jste v něm udělali."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aAyY]) rm -rf "$BAZE"; echo "  Smazáno."; exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
