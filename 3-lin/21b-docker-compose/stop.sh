#!/bin/bash
# 3/21b — konec hodiny: projekt se zastaví, ale nesmaže.
#
# `docker compose stop` nechá kontejnery i svazky být — data v nich
# zůstanou. Na rozdíl od `down`, které kontejnery smaže.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/docker-lib.sh"
COMPOSE_DIR="$DOCKER_DIR/compose"
PROJEKT="netlab-$ZAK2"
echo
if ! command -v docker >/dev/null 2>&1; then
  echo "  Na stanici není Docker. Řekněte o tom vyučujícímu."; echo; exit 1
fi
if [ -z "$(docker ps -a --filter "label=com.docker.compose.project=$PROJEKT" -q 2>/dev/null)" ]; then
  echo "  Projekt $PROJEKT neexistuje, není co zastavovat."
else
  (cd "$COMPOSE_DIR" 2>/dev/null && docker compose stop >/dev/null 2>&1) \
    || docker stop $(docker ps --filter "label=com.docker.compose.project=$PROJEKT" -q) >/dev/null 2>&1
  echo "  Projekt $PROJEKT zastaven. Kontejnery ani svazek se nesmazaly —"
  echo "  příště je nastartujete tak, že se přepnete do adresáře projektu"
  echo "  a spustíte:  cd ~/netlab/docker/compose && docker compose start"
fi
echo
