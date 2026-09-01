#!/bin/bash
# 2/22 — zastavení. Kolegův proces běží na pozadí, takže je co zastavovat.
# Ukončit ho ale měl žák sám (úkol E) — proto si to skript poznamená
# a kontrola to pozná. Dřív se tvrdilo, že to kontrola pozná podle
# chybějícího PID; nepoznala, PID zůstává v logu.
set -uo pipefail
PREV="$HOME/netlab/prevzeti"
VZOR='bash .*sber-[a-z]+\.sh'
PIDY="$(pgrep -f "$VZOR" 2>/dev/null | tr '\n' ' ')"
echo
if [ -z "${PIDY// /}" ]; then
  echo "  Kolegův sběrný skript neběží — buď jste ho ukončili, nebo nikdy nestartoval."
else
  for p in $PIDY; do kill "$p" 2>/dev/null; done
  sleep 1
  for p in $(pgrep -f "$VZOR" 2>/dev/null); do kill -9 "$p" 2>/dev/null; done
  [ -d "$PREV" ] && date +%F > "$PREV/.stop-pouzit"
  echo "  Kolegův sběrný skript ukončen."
  echo "  Pozor: ukončit ho měl úkol E. Kontrola to od teď hlásí jako nesplněné —"
  echo "  jestli jste ho ještě neřešili, spusťte ./reset.sh a začněte znovu."
fi
echo "  Účet, skupina i výsledky vaší práce zůstávají."
echo
