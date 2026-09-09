#!/bin/bash
# 3/09 — návrat do výchozího stavu (smaže server i vaši práci na něm)
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
KONT="sluzby-$ZAK2"
echo
# Server sluzby-XX je společný pro cvičení 7 až 10, takže smazat ho znamená
# přijít i o práci z ostatních tří. Ve varování to musí být jmenovitě.
echo "  Server $KONT je společný pro cvičení 7, 8, 9 a 10."
echo "  Smažete tím i hlídače, zálohovací timer a skript s podmínkou."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aAyY])
    if lxc delete -f "$KONT" >/dev/null 2>&1; then
      echo "  Smazáno."; exec "$(dirname "$0")/start.sh"
    else
      echo "  Server se nepodařilo smazat — zavolejte vyučujícího."; exit 1
    fi ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
