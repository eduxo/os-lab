#!/bin/bash
# 3/21b — návrat do výchozího stavu
#
# `down -v` smaže i pojmenovaný svazek, tedy záznamy zapisovače. Obrazy
# zůstávají v cache stanice — stahovat je znovu se nesmí.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/docker-lib.sh"
COMPOSE_DIR="$DOCKER_DIR/compose"
PROJEKT="netlab-$ZAK2"
echo
if ! command -v docker >/dev/null 2>&1; then
  echo "  Na stanici není Docker. Řekněte o tom vyučujícímu."; echo; exit 1
fi
echo "  Tím smažete kontejnery projektu $PROJEKT i jejich sdílený svazek."
echo "  Váš compose soubor i podklady webu zůstanou — jsou to vaše data."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aAyY])
    (cd "$COMPOSE_DIR" 2>/dev/null && docker compose down -v >/dev/null 2>&1)
    # Když compose soubor chybí nebo je rozbitý, `down` nemá podle čeho
    # uklidit — dobereme to podle značek.
    ZBYTKY="$(docker ps -a --filter "label=com.docker.compose.project=$PROJEKT" -q 2>/dev/null)"
    [ -n "$ZBYTKY" ] && docker rm -f $ZBYTKY >/dev/null 2>&1
    for V in $(docker volume ls --filter "label=com.docker.compose.project=$PROJEKT" -q 2>/dev/null); do
      docker volume rm "$V" >/dev/null 2>&1
    done
    echo "  Uklizeno."
    exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo."; echo ;;
esac
