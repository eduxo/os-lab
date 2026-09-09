#!/bin/bash
# 3/14 — návrat do výchozího stavu (smaže server i vaši práci na něm)
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
KONT="netlab-$ZAK2"
KLIENT="klient-$ZAK2"
echo
if ! command -v lxc >/dev/null 2>&1; then
  echo "  Na stanici není LXD. Řekněte o tom vyučujícímu."; echo; exit 1
fi
echo "  Server $KONT je společný pro cvičení 14 a 15."
echo "  Smažete tím i konfiguraci DHCP, pokud jste ji už dělali."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aAyY])
    lxc delete -f "$KLIENT" >/dev/null 2>&1
    if lxc delete -f "$KONT" >/dev/null 2>&1; then
      echo "  Smazáno."; exec "$(dirname "$0")/start.sh"
    else
      echo "  Server se nepodařilo smazat — zavolejte vyučujícího."; exit 1
    fi ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
