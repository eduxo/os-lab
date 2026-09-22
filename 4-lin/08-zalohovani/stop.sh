#!/bin/bash
# 4/08 — úklid. Odpojí oddíl se zálohami a zastaví kontejner.
# Repozitář ani data se nemažou — lab má dva bloky a druhý na nich staví.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
SERVER_KONT="zaloha-$ZAK2"   # až ZA lab-lib.sh: ZAK2 vzniká teprve tam
source "$(dirname "$0")/../../lib/server-lib.sh"
REPO="$HOME/netlab/zalohy/repo"
echo
if mountpoint -q "$REPO" 2>/dev/null; then
  sudo umount "$REPO" && echo "  Odpojeno: $REPO"
else
  echo "  Nic připojeného, není co odpojovat."
fi
if lxc info "$SERVER_KONT" >/dev/null 2>&1 && server_bezi; then
  lxc stop "$SERVER_KONT" >/dev/null 2>&1 && echo "  Kontejner $SERVER_KONT zastaven."
fi
echo "  Zálohy zůstávají na disku i v kontejneru."
echo
