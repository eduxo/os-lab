#!/bin/bash
# 2/05 — návrat do výchozího stavu (smaže adresářovou strukturu cvičení)
set -uo pipefail
CESTY="$HOME/netlab/cesty"
echo
echo "  Tím smažete celý adresář $CESTY včetně vyplněných formulářů."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aAyY]) rm -rf "$CESTY"; echo "  Smazáno."; exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
