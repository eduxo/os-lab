#!/bin/bash
# 4/00 — vyhodnocení rozcvičky po 3. ročníku.
# NEHODNOTÍ. Ukazuje, které téma vypadlo a kam se pro něj vrátit.
# Části odpovídají krokům zadání 1:1 (Krok 1 = --krok 1).
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/disk-lib.sh"

ROZ="$HOME/netlab/rozcvicka4"
PODKLADY="$ROZ/podklady"
FORMULAR="$ROZ/odpovedi.txt"

# Losované hodnoty musí sedět se start.sh — proto tytéž soli.
OKTET="$(lab_cislo 20 79 400)"
PORT_WEB="$(lab_cislo 8000 8899 401)"
INTERVAL="$(lab_cislo 5 24 402)"
CHYB="$(lab_cislo 4 9 403)"
PORTU="$(lab_cislo 3 6 404)"
WEB_VEN="$(lab_cislo 0 1 406)"

TEMATA=(); VYSLEDKY=(); ODKAZY=(); NEVYPLNENO=()
_pred=0
prazdnych() { local n=0 k; for k in "$@"; do [ -z "$(_zaznam "$FORMULAR" "$k")" ] && n=$((n+1)); done; echo "$n"; }
tema_start() { _pred=$_pass; }
tema_konec() {  # tema_konec "název" počet "odkaz" klíč…
  local nazev="$1" pocet="$2" odkaz="$3"; shift 3
  TEMATA+=("$nazev"); VYSLEDKY+=("$(( _pass - _pred ))/$pocet")
  ODKAZY+=("$odkaz"); NEVYPLNENO+=("$(prazdnych "$@")")
}

if [ ! -d "$PODKLADY" ] || [ ! -s "$FORMULAR" ]; then
  echo
  echo "  Prostředí rozcvičky není kompletní. Spusťte ./start.sh — doplní,"
  echo "  co chybí, a vyplněné odpovědi vám nechá."
  echo
  exit 1
fi

krok 1 "Síť"
tema_start
require_zaznam "$FORMULAR" adresa "10.40.$OKTET.12/24" \
  "adresa: IP adresa serveru i s prefixem"
require_zaznam "$FORMULAR" brana "10.40.$OKTET.1" \
  "brana: adresa výchozí brány"
# V souboru žádný renderer není — platí výchozí networkd. Přesně tenhle
# úsudek učí cvičení 3/01, tak se tu ptáme na něj.
require_zaznam_tvar "$FORMULAR" renderer '^(systemd-)?networkd$' \
  "renderer: kdo podle toho souboru řídí síť" \
  "renderer: řádek renderer v souboru není — co potom platí?"
tema_konec "síť a netplan" 3 "3/01 Síťová konfigurace" adresa brana renderer

krok 2 "systemd"
tema_start
require_zaznam "$FORMULAR" interval "$INTERVAL" \
  "interval: jak často se sklizeň opakuje (minuty)"
require_zaznam "$FORMULAR" ucet "cidla" \
  "ucet: pod kterým účtem služba běží"
require_zaznam "$FORMULAR" cil "timers.target" \
  "cil: do kterého cíle se timer instaluje"
tema_konec "služby a časovače" 3 "3/07 systemd — služby · 3/08 timery" \
  interval ucet cil

krok 3 "Logy"
tema_start
require_zaznam "$FORMULAR" chyb "$CHYB" \
  "chyb: kolik řádků logu obsahuje ERROR"
require_zaznam "$FORMULAR" mereni "48" \
  "mereni: kolik měření sklizeň zapsala"
require_zaznam "$FORMULAR" posledni "08:12:03" \
  "posledni: čas posledního řádku logu"
tema_konec "logy" 3 "3/09 Logy — journalctl" chyb mereni posledni

krok 4 "Firewall"
tema_start
require_zaznam "$FORMULAR" pravidel "$PORTU" \
  "pravidel: kolik pravidel firewall vypisuje"
require_zaznam "$FORMULAR" ssh-odkud "10.40.$OKTET.0/24" \
  "ssh-odkud: z jakého rozsahu smí přijít SSH"
if [ "$WEB_VEN" = "1" ] && [ "$PORTU" -ge 2 ]; then OCEK_WEB=ano; else OCEK_WEB=ne; fi
require_zaznam "$FORMULAR" web "$OCEK_WEB" \
  "web: pustí firewall port 80 odkudkoli?"
tema_konec "firewall" 3 "3/13 Firewall" pravidel ssh-odkud web

krok 5 "Kontejnery"
tema_start
require_zaznam "$FORMULAR" port "$PORT_WEB" \
  "port: na kterém portu stanice web zveřejňuje"
require_zaznam "$FORMULAR" obraz "nginx:alpine" \
  "obraz: jméno obrazu i se značkou"
require_zaznam "$FORMULAR" svazek "ro" \
  "svazek: jak je připojený obsah"
tema_konec "kontejnery" 3 "3/21 Docker · 3/21b Docker Compose" port obraz svazek

krok 6 "Ročníkový projekt"
# Tohle není úkol rozcvičky — disk zakládá prostředí. Hlásí se proto jako
# stav prostředí, ne jako splněný úkol.
if [ -n "$(blkid -L "$PROJEKT_NAZEV" 2>/dev/null)" ]; then
  uspech "disk pro ročníkový projekt je založený ($PROJEKT_NAZEV)"
else
  chyba "disk pro ročníkový projekt chybí — spusťte ./start.sh"
fi
if projekt_pripojen; then
  uspech "projekt je připojený v $PROJEKT_PRIPOJ"
else
  chyba "projekt není připojený — spusťte ./start.sh"
fi
require_soubor_neprazdny "$PROJEKT_PRIPOJ/zadani.txt" \
  "zadání projektu je na disku" \
  "chybí zadani.txt na projektovém disku — spusťte ./start.sh"
# Deník je první vlastní práce žáka na projektu. Jméno souboru si volí sám,
# proto se hledá jakýkoli neprázdný soubor v dokumentaci — ne konkrétní název.
if [ -n "$(find "$PROJEKT_PRIPOJ/dokumentace" -maxdepth 1 -type f -size +0 2>/dev/null | head -1)" ]; then
  uspech "v dokumentaci projektu je založený deník"
else
  chyba "v ~/projekt/dokumentace zatím nic není — založte si deník projektu"
fi

vypis_souhrn; _rc=$?

# ── rozpad místo známky ───────────────────────────────────────────
# Až ZA souhrnem: jinak by po větě „tohle se neznámkuje" hned následovalo
# „Splněno X z Y" a popřelo ji.
if [ -z "$_krok_filtr" ]; then
  printf "  ${_B}Co vám sedí a co ne${_0}\n\n"
  for i in "${!TEMATA[@]}"; do
    STAV="${VYSLEDKY[i]}"; PRAZ="${NEVYPLNENO[i]}"
    if [ "${STAV%%/*}" = "${STAV##*/}" ]; then
      printf "    ${_Z}%-5s %s${_0}\n" "$STAV" "${TEMATA[i]}"
    else
      # Odkaz patří i k okruhu, ke kterému žák vůbec nedošel — právě ten
      # potřebuje nejvíc vědět, kam se vrátit. Nevyplněno je doplněk,
      # ne náhrada odkazu.
      DOPL=""; [ "${PRAZ:-0}" -gt 0 ] && DOPL="  (${PRAZ} nevyplněno)"
      printf "    ${_M}%-5s %s${_0}  → %s%s\n" "$STAV" "${TEMATA[i]}" "${ODKAZY[i]}" "$DOPL"
    fi
  done
  echo
  echo "  Tohle se neznámkuje. Šipka vpravo říká, kam se vrátit."
  echo
fi

exit "$_rc"
