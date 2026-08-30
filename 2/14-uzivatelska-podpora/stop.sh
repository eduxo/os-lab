#!/bin/bash
# 2/14 — úklid: kontejner se zastaví, ale nemaže. Data v GLPI zůstávají.
set -uo pipefail
KONTEJNER="glpi"
if command -v lxc >/dev/null 2>&1 && \
   [ "$(lxc list "^$KONTEJNER\$" -c s --format csv 2>/dev/null | head -1)" = "RUNNING" ]; then
  echo; echo "  Zastavuji kontejner s GLPI…"
  lxc stop "$KONTEJNER" >/dev/null 2>&1
  echo "  Zastaveno. Tikety, které jste založili, v něm zůstávají."
else
  echo; echo "  Kontejner s GLPI neběží — není co zastavovat."
fi
echo
