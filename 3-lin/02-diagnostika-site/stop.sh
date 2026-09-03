#!/bin/bash
# 3/02 — zastavení: naslouchač běží na pozadí, tak je co zastavovat
set -uo pipefail
PIDY="$(pgrep -f 'http.server 9[0-9][0-9][0-9]' 2>/dev/null | tr '\n' ' ')"
echo
if [ -z "${PIDY// /}" ]; then
  echo "  Naslouchač neběží — není co zastavovat."
else
  for p in $PIDY; do kill "$p" 2>/dev/null; done
  sleep 1
  for p in $(pgrep -f 'http.server 9[0-9][0-9][0-9]' 2>/dev/null); do kill -9 "$p" 2>/dev/null; done
  echo "  Naslouchač ukončen."
fi
echo "  Formulář v ~/netlab/diagnostika zůstává."
echo
