#!/bin/bash
# 3/11 — návrat do výchozího stavu (smaže server i vaši práci na něm)
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
KONT="provoz-$ZAK2"
echo
# Server provoz-XX je společný pro cvičení 11, 12 a 13.
echo "  Server $KONT je společný pro cvičení 11, 12 a 13."
echo "  Smažete tím i vše, co jste na něm v těch cvičeních udělali."
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
