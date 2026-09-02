#!/bin/bash
# 2/21 — zastavení. Skripty z tohoto cvičení běží na pozadí, takže je
# na rozdíl od ostatních cvičení opravdu co zastavovat.
# Hledá se podle jména skriptu, ne podle cesty: žák je spouští jako
# ./hlidac-XXX.sh, takže v příkazové řádce žádná cesta není.
set -uo pipefail
VZOR='bash .*(hlidac-[a-z]+|tvrdohlavy)\.sh'

PIDY="$(pgrep -f "$VZOR" 2>/dev/null | tr '\n' ' ')"
echo
if [ -z "${PIDY// /}" ]; then
  echo "  Žádný skript z tohoto cvičení neběží — není co zastavovat."
else
  # Nejdřív slušně, teprve pak natvrdo — přesně jak to učí samo cvičení.
  for p in $PIDY; do kill "$p" 2>/dev/null; done
  sleep 1
  ZBYLE="$(pgrep -f "$VZOR" 2>/dev/null | tr '\n' ' ')"
  for p in $ZBYLE; do kill -9 "$p" 2>/dev/null; done
  echo "  Ukončeno procesů: $(echo "$PIDY" | wc -w | tr -d ' ')."
  if [ -n "${ZBYLE// /}" ]; then
    echo "  Z toho $(echo "$ZBYLE" | wc -w | tr -d ' ') si signál TERM zakázalo — na ty došlo na KILL."
  fi
fi
echo "  Skripty i logy v ~/netlab/procesy zůstávají."
echo
