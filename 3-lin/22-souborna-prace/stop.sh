#!/bin/bash
# 3/22 — zastavení serveru (práce na něm zůstává)
#
# POZOR: u souborné práce se mezi bloky NEMÁ spouštět. Timer z úkolu D
# by přestal střílet a druhý blok by začal tím, že kontrola hlásí
# nečerstvou stavovou stránku. Zadání to říká; tenhle skript to
# připomene ještě jednou.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
KONT="intraweb-$ZAK2"
echo
if ! command -v lxc >/dev/null 2>&1; then
  echo "  Na stanici není LXD. Řekněte o tom vyučujícímu."; echo; exit 1
fi
if [ -z "$(lxc list "^${KONT}$" -c s --format csv 2>/dev/null)" ]; then
  echo "  Server $KONT neexistuje, není co zastavovat."; echo; exit 0
fi
echo "  Tohle je souborná práce na dva bloky."
echo "  Mezi prvním a druhým blokem server zastavovat NEMUSÍTE — a je"
echo "  lepší to neudělat: timer z úkolu D by přestal běžet a druhý blok"
echo "  byste začínali čekáním, než se stavová stránka zase obnoví."
read -r -p "  Opravdu zastavit? [a/N] " o
case "$o" in
  [aAyY])
    lxc stop "$KONT" >/dev/null 2>&1
    echo "  Server $KONT zastaven. Vaše práce na něm zůstala."
    echo "  Příště ho nastartuje ./start.sh" ;;
  *) echo "  Zrušeno, server běží dál." ;;
esac
echo
