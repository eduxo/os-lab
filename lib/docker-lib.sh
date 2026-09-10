#!/bin/bash
# docker-lib.sh — společné pro blok H (3/21 Docker, 3/21b Compose).
#
# JEDINÝ BLOK ROČNÍKU BEZ LXD KONTEJNERU. Docker běží přímo ve VM žáka
# (rozhodnutí z plánu: v LXD kontejneru by šel, ale nemá to smysl —
# kontejner v kontejneru je zbytečná vrstva a učivem jsou obrazy, porty
# a svazky, ne vnořená virtualizace).
#
# Důsledky, na které je potřeba myslet:
#   · není `postav_server`, `na_serveru` ani `LAB_KONTEJNER`
#   · všechno se kontroluje na stanici, `v_cili` běží lokálně
#   · žák je na svém stroji root přes sudo, takže „schovat" před ním
#     nejde nic — kotvy musí být ŽIVÉ HODNOTY Z JEHO BĚHU
#
# Sourcuje se AŽ PO lab-lib.sh.

DOCKER_DIR="$HOME/netlab/docker"
DOCKER_OBRAZY=/opt/os-lab/obrazy
DOCKER_POTREBNE=(nginx:alpine alpine:latest)

# Port se odvozuje z čísla žáka, aby si dva žáci na jedné stanici
# (a při ladění i jeden žák ve dvou labech) nekolidovali.
DOCKER_PORT=$(( 8000 + ZAK ))
COMPOSE_PORT=$(( 8100 + ZAK ))

# Kód, který má být vidět na stránce. Leží v souboru, který žák
# připojuje do kontejneru — vidět ho tedy může, o to nejde. Jde o to,
# že se přes HTTP objeví jedině tehdy, když port i svazek opravdu fungují.
DOCKER_KOD_SOUBOR="$HOME/.os-lab-docker-kod"

# GENERUJE SE JEN VE start.sh. Kdyby kód uměla vyrobit i kontrola,
# stačilo by soubor smazat: kontrola by si vyrobila nový, na stránce
# by zůstal starý a start.sh by to nespravil (index.html přepisuje jen
# když chybí). Vznikla by slepá ulička, ze které vede jen reset.
zaridi_kod_docker() {
  if [ ! -s "$DOCKER_KOD_SOUBOR" ]; then
    install -m 600 /dev/null "$DOCKER_KOD_SOUBOR"
    printf 'WEB-%s\n' "$(LC_ALL=C tr -dc 'A-Z0-9' </dev/urandom | head -c5)" \
      > "$DOCKER_KOD_SOUBOR"
  fi
  DOCKER_KOD="$(cat "$DOCKER_KOD_SOUBOR" | tr -d '\r\n')"
}

# Kontrola kód jen ČTE. Když chybí, není co porovnávat a je to chyba
# prostředí, ne žáka.
precti_kod_docker() {
  DOCKER_KOD="$(cat "$DOCKER_KOD_SOUBOR" 2>/dev/null | tr -d '\r\n')"
  [ -n "$DOCKER_KOD" ]
}

# Prostředí Dockeru. Vrací nenulu s ČITELNOU hláškou — bez Dockeru
# nebo bez členství ve skupině nemá smysl pokračovat.
overi_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo
    echo "  Na téhle stanici není Docker."
    echo "  Řekněte o tom vyučujícímu — patří do obrazu VM."
    echo
    return 1
  fi
  # `docker info` je jediný spolehlivý test: příkaz může existovat,
  # démon neběžet, a členství ve skupině se projeví až po přihlášení.
  if ! docker info >/dev/null 2>&1; then
    # Příčinu se ptáme, ne hádáme. Poslat žáka „odhlaste se a přihlaste",
    # když ve skutečnosti neběží démon, znamená, že to udělá a nic
    # se nezmění.
    echo
    echo "  Docker je nainstalovaný, ale nedá se s ním mluvit."
    if ! id -nG 2>/dev/null | tr ' ' '\n' | grep -qx docker; then
      echo "  Nejste ve skupině 'docker'. Odhlaste se a přihlaste znovu —"
      echo "  členství se projeví až v nové relaci."
    elif ! systemctl is-active --quiet docker 2>/dev/null; then
      echo "  Služba dockeru neběží. Zkuste:  sudo systemctl start docker"
      echo "  Když nenaběhne, řekněte o tom vyučujícímu."
    else
      echo "  Ve skupině jste a služba běží, takže je to něco jiného."
      echo "  Řekněte o tom vyučujícímu a ukažte mu výstup:  docker info"
    fi
    echo
    return 1
  fi
  return 0
}

# Obrazy se NIKDY nestahují z internetu. Docker Hub má limity pro
# anonymní stahování z jedné adresy a třicet žáků za jedním NATem je
# spolehlivě trefí — uprostřed hodiny a všem naráz.
zaridi_obrazy() {
  local obraz soubor chybi=0
  for obraz in "${DOCKER_POTREBNE[@]}"; do
    docker image inspect "$obraz" >/dev/null 2>&1 && continue
    soubor="$DOCKER_OBRAZY/$(printf '%s' "$obraz" | tr ':/' '--').tar"
    if [ -f "$soubor" ]; then
      docker load -i "$soubor" >/dev/null 2>&1
      # `docker load` obnovuje jméno a značku ULOŽENOU V ARCHIVU, ne tu,
      # o kterou jsme žádali. Přejmenovaný nebo omylem přeuložený .tar
      # se načte pod jiným jménem, load vrátí nulu — a první `docker run`
      # by pak sáhl na Docker Hub, tedy přesně to, co je zakázané.
      docker image inspect "$obraz" >/dev/null 2>&1 || chybi=1
    else
      chybi=1
    fi
  done
  if [ "$chybi" -ne 0 ]; then
    echo
    echo "  Na stanici chybí obrazy, které cvičení potřebuje, a stahovat"
    echo "  je z internetu se nesmí — Docker Hub má limity a třicet žáků"
    echo "  naráz je vyčerpá."
    echo "  Řekněte o tom vyučujícímu: patří do obrazu VM, doplní je"
    echo "  skript nastroje/priprava-stanice.sh."
    echo
    return 1
  fi
  return 0
}

# Běžící kontejner podle jména → jeho ID (prázdné, když neběží).
kontejner_id() {  # kontejner_id JMÉNO
  docker ps --filter "name=^${1}$" --format '{{.ID}}' 2>/dev/null | head -1
}
