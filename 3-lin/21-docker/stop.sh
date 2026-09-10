#!/bin/bash
# 3/21 — konec hodiny: kontejner se zastaví, ale nesmaže.
#
# Bez LXD: zastavuje se kontejner Dockeru přímo na stanici.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/docker-lib.sh"
JMENO="web-$ZAK2"
echo
if ! command -v docker >/dev/null 2>&1; then
  echo "  Na stanici není Docker. Řekněte o tom vyučujícímu."; echo; exit 1
fi
if [ -z "$(docker ps -a --filter "name=^${JMENO}$" --format '{{.ID}}' 2>/dev/null)" ]; then
  echo "  Kontejner $JMENO neexistuje, není co zastavovat."
else
  docker stop "$JMENO" >/dev/null 2>&1
  echo "  Kontejner $JMENO zastaven. Nesmazal se — příště ho nastartujete"
  echo "  příkazem  docker start $JMENO"
fi
echo
