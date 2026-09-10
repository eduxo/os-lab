#!/bin/bash
# 3/21 — návrat do výchozího stavu
#
# Maže se KONTEJNER, ne obraz. Obrazy jsou v cache stanice a stahovat
# je znovu se nesmí — Docker Hub má limity a třicet žáků naráz je vyčerpá.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/docker-lib.sh"
JMENO="web-$ZAK2"
echo
if ! command -v docker >/dev/null 2>&1; then
  echo "  Na stanici není Docker. Řekněte o tom vyučujícímu."; echo; exit 1
fi
echo "  Tím smažete kontejner $JMENO a začnete od prázdna."
echo "  Podklady webu v ~/netlab/docker/web zůstanou — jsou to vaše data."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aAyY])
    if docker rm -f "$JMENO" >/dev/null 2>&1; then
      echo "  Kontejner smazán."
    else
      echo "  Žádný kontejner $JMENO nebyl, stavím prostředí znovu."
    fi
    exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo."; echo ;;
esac
