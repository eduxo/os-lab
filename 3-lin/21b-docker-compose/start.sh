#!/bin/bash
# 3/21b — Docker Compose. Prostředí: PŘÍMO STANICE, žádný LXD kontejner.
#
# Compose soubor si žák píše sám — je to celé zadání. Prostředí připraví
# jen adresář a podklady webu (kdyby jednadvacítku nedělal).
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/docker-lib.sh"

COMPOSE_DIR="$DOCKER_DIR/compose"
FORMULAR="$COMPOSE_DIR/formular.txt"
WEB="$DOCKER_DIR/web"
PROJEKT="netlab-$ZAK2"

vyrob_formular() {
  mkdir -p "$COMPOSE_DIR"
  cat > "$FORMULAR" <<'FORM_KONEC'
# Formulář — vyplňte hodnoty za dvojtečku.
#
# svazek = celé jméno svazku, jak ho vypíše `docker volume ls`
# id-web = zkrácené ID kontejneru se službou web
svazek:
id-web:
FORM_KONEC
}

overi_docker || exit 1
if ! docker compose version >/dev/null 2>&1; then
  echo
  echo "  Na stanici není plugin 'docker compose'."
  echo "  Řekněte o tom vyučujícímu — balíček docker.io ho neobsahuje,"
  echo "  je zvlášť (docker-compose-v2) a patří do obrazu VM."
  echo
  exit 1
fi
zaridi_obrazy || exit 1
zaridi_kod_docker

mkdir -p "$COMPOSE_DIR" "$WEB/data"
# Nezávislost: kdo nedělal jednadvacítku, nemá co servírovat.
if [ ! -s "$WEB/index.html" ]; then
  cat > "$WEB/index.html" <<HTML
<!doctype html>
<meta charset="utf-8">
<title>NetLab — kontejnery</title>
<h1>Běží to v kontejneru</h1>
<p>Kód stránky: $DOCKER_KOD</p>
HTML
fi

[ -s "$FORMULAR" ] || vyrob_formular

if [ -n "$(docker ps --filter "label=com.docker.compose.project=$PROJEKT" -q 2>/dev/null)" ]; then
  echo
  echo "  Projekt $PROJEKT už běží — pokračujete tam, kde jste skončili."
  echo "  Chcete začít znovu?  ./reset.sh"
fi

cat <<EOF

  Prostředí je připravené. Tenhle lab se dělá PŘÍMO NA STANICI.

    Pracovní adresář: $COMPOSE_DIR
    Podklady webu:    $WEB
    Formulář:         $FORMULAR

  Napište compose soubor, který rozběhne DVĚ služby:

    Jméno projektu:   $PROJEKT
    web         nginx:alpine, port $COMPOSE_PORT na stanici → 80 uvnitř
    zapisovac   alpine:latest, píše čas do sdíleného svazku

  Kontrola:

    cd ~/os-lab/3-lin/21b-docker-compose && ./check.sh --krok 2

  (Kontrola začíná částí 2 — Krok 1 zadání je jen prohlídka.)

EOF
