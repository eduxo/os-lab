#!/bin/bash
# 3/21 — Docker. Prostředí: PŘÍMO STANICE, žádný LXD kontejner.
#
# Je to jediný lab ročníku, který se nedělá přes SSH. Docker běží ve VM
# žáka a všechno se odehrává v jednom okně — kontrola se pouští tamtéž.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/docker-lib.sh"

FORMULAR="$DOCKER_DIR/formular.txt"
JMENO="web-$ZAK2"
WEB="$DOCKER_DIR/web"

vyrob_formular() {
  mkdir -p "$DOCKER_DIR"
  cat > "$FORMULAR" <<'FORM_KONEC'
# Formulář — vyplňte hodnoty za dvojtečku.
#
# id-kontejneru = zkrácené ID vašeho běžícího kontejneru, jak ho vypíše
#                 `docker ps` ve sloupci CONTAINER ID
# port-uvnitr   = port, na kterém služba poslouchá UVNITŘ kontejneru
#                 (ne ten, který jste zveřejnili na stanici)
id-kontejneru:
port-uvnitr:
FORM_KONEC
}

overi_docker || exit 1
zaridi_obrazy || exit 1
zaridi_kod_docker

# Podklady pro web. Doplňují se po souborech — žák si s adresářem bude
# hrát a nesmí se stát, že mu ho start.sh přepíše nebo naopak nedoplní.
# Adresář `data` musí existovat UŽ NA STANICI. Cvičení 21b do něj montuje
# pojmenovaný svazek — a protože je celý `web/` připojený jen ke čtení,
# Docker by ten přípojný bod uvnitř read-only mountu nevytvořil a kontejner
# by nenaběhl. Se svazkem se obsah tohohle adresáře uvnitř kontejneru
# stejně překryje, takže na stanici zůstane prázdný.
mkdir -p "$WEB/data"
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

if [ -n "$(kontejner_id "$JMENO")" ]; then
  echo
  echo "  Kontejner $JMENO už běží — pokračujete tam, kde jste skončili."
  echo "  Chcete začít znovu?  ./reset.sh"
fi

cat <<EOF

  Prostředí je připravené. Tenhle lab se dělá PŘÍMO NA STANICI —
  nikam se nepřihlašujete a stačí jedno okno.

    Obrazy v cache:   nginx:alpine, alpine:latest
    Podklady webu:    $WEB
    Formulář:         $FORMULAR

  Postavte kontejner s webem:

    Jméno kontejneru:  $JMENO
    Port na stanici:   $DOCKER_PORT
    Port v kontejneru: 80

  Kontrola:

    cd ~/os-lab/3-lin/21-docker && ./check.sh --krok 2

  (Kontrola začíná částí 2 — Krok 1 zadání je jen prohlídka.)

EOF
