#!/bin/bash
# 3/00 — vyhodnocení rozcvičky.
# NEHODNOTÍ. Ukazuje, které téma vypadlo a kam se pro něj vrátit.
#
# Části odpovídají krokům zadání 1:1 (Krok 1 = --krok 1). Kontrola prostředí
# je součástí části 1, aby číslování sedělo — žák, který po Kroku 3 napíše
# --krok 3, musí dostat kontrolu Kroku 3.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

ROZ="$HOME/netlab/rozcvicka"
DATA="$ROZ/data"
LOG="$DATA/logy/sluzba.log"
FORMULAR="$ROZ/odpovedi.txt"
KOD="$(lab_kod ROZ 300)"

# Rozpad podle témat. Kromě splněných se počítají i NEVYPLNĚNÉ odpovědi —
# bez toho by rozcvička hlásila díru i tomu, kdo na okruh jen nedošel,
# a poslala ho opakovat něco, co umí.
TEMATA=(); VYSLEDKY=(); ODKAZY=(); NEVYPLNENO=()
_pred=0
prazdnych() { local n=0 k; for k in "$@"; do [ -z "$(_zaznam "$FORMULAR" "$k")" ] && n=$((n+1)); done; echo "$n"; }
tema_start() { _pred=$_pass; }
tema_konec() {  # tema_konec "název" počet "odkaz" klíč...
  local nazev="$1" pocet="$2" odkaz="$3"; shift 3
  TEMATA+=("$nazev"); VYSLEDKY+=("$(( _pass - _pred ))/$pocet")
  ODKAZY+=("$odkaz"); NEVYPLNENO+=("$(prazdnych "$@")")
}

# Prostředí se nekontroluje jako úkol — patnáct úkolů má být patnáct.
# Když chybí, není co diagnostikovat.
if [ ! -d "$DATA" ] || [ ! -s "$FORMULAR" ]; then
  echo
  echo "  Prostředí rozcvičky není kompletní. Spusťte ./start.sh — doplní,"
  echo "  co chybí, a vyplněné odpovědi vám nechá."
  echo
  exit 1
fi

krok 1 "Pohyb a cesty"
tema_start
require_zaznam "$FORMULAR" domov "$HOME" \
  "domov: absolutní cesta k domovskému adresáři"
require_zaznam "$FORMULAR" polozek "$(ls -A "$DATA" 2>/dev/null | grep -c '')" \
  "polozek: počet položek v data"
require_zaznam "$FORMULAR" symlink "$(readlink "$ROZ/zkratka" 2>/dev/null)" \
  "symlink: kam vede odkaz zkratka"
tema_konec "pohyb a cesty" 3 "2/05 Souborový systém a cesty" domov polozek symlink

krok 2 "Soubory a text"
tema_start
SOUBOR_KOD="$(grep -rl "$KOD" "$DATA" 2>/dev/null | head -1)"
require_zaznam "$FORMULAR" soubor-kod "$(basename "${SOUBOR_KOD:-}")" \
  "soubor-kod: ve kterém souboru je interní kód"
require_zaznam "$FORMULAR" radku-chyba "$(grep -c 'ERROR' "$LOG" 2>/dev/null)" \
  "radku-chyba: kolik řádků logu obsahuje ERROR"
require_zaznam "$FORMULAR" prvni-slovo "$(head -1 "$DATA/prehled.txt" 2>/dev/null | awk '{print $1}')" \
  "prvni-slovo: první slovo prvního řádku prehled.txt"
tema_konec "soubory a text" 3 "2/06 Práce se soubory · 2/08 Hledání" \
  soubor-kod radku-chyba prvni-slovo

krok 3 "Roury a přesměrování"
tema_start
require_zaznam "$FORMULAR" nejcastejsi \
  "$(awk '{print $4}' "$LOG" 2>/dev/null | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')" \
  "nejcastejsi: který úsek je v logu nejčastěji"
require_zaznam "$FORMULAR" unikatnich \
  "$(awk '{print $4}' "$LOG" 2>/dev/null | sort -u | grep -c '')" \
  "unikatnich: kolik různých úseků log obsahuje"
# Třetí úkol se nezapisuje do formuláře — dokládá se souborem.
CHYBY="$ROZ/vysledek/chyby.txt"
# Počty se musí normalizovat: u chybějícího souboru vrací grep -c prázdno
# a `[ -eq ]` pak spadne syrovou hláškou bashe do výstupu žákovi.
N_CHYB="$(grep -c 'ERROR' "$LOG" 2>/dev/null)"; N_CHYB="${N_CHYB:-0}"
N_ULOZ="$(grep -c '' "$CHYBY" 2>/dev/null)"; N_ULOZ="${N_ULOZ:-0}"
if [ -f "$CHYBY" ] && [ "$N_ULOZ" -eq "$N_CHYB" ] && [ "$N_CHYB" -gt 0 ] \
   && ! grep -qv 'ERROR' "$CHYBY"; then
  uspech "chyby.txt obsahuje právě chybové řádky z logu"
else
  chyba "ve vysledek/chyby.txt nejsou právě chybové řádky z logu"
fi
tema_konec "roury a přesměrování" 3 "2/09 Přesměrování a roury" nejcastejsi unikatnich

krok 4 "Práva a účty"
tema_start
require_zaznam "$FORMULAR" prava "$(stat -c %a "$DATA/tajne.txt" 2>/dev/null)" \
  "prava: práva souboru tajne.txt číselně"
require_zaznam "$FORMULAR" vlastnik \
  "$(stat -c '%U:%G' "$DATA/tajne.txt" 2>/dev/null)" \
  "vlastnik: vlastník a skupina souboru tajne.txt"
require_zaznam "$FORMULAR" skupin "$(id -nG | wc -w | tr -d ' ')" \
  "skupin: do kolika skupin patří váš účet"
tema_konec "práva a účty" 3 "2/15 Uživatelé a skupiny · 2/16 Oprávnění" prava vlastnik skupin

krok 5 "Software a data"
tema_start
require_zaznam "$FORMULAR" verze \
  "$(dpkg-query -W -f='${Version}' bash 2>/dev/null)" \
  "verze: verze nainstalovaného balíčku bash"
# Přesměrování z neexistujícího souboru hlásí chybu sám shell a `2>/dev/null`
# na příkazu ji nezachytí — proto se existence testuje předem.
require_zaznam "$FORMULAR" otisk \
  "$( [ -f "$DATA/prehled.txt" ] && _hash < "$DATA/prehled.txt" | cut -c1-8 )" \
  "otisk: prvních osm znaků otisku prehled.txt"
require_zaznam "$FORMULAR" v-archivu \
  "$(tar -tzf "$ROZ/zaloha.tar.gz" 2>/dev/null | grep -c '[^/]$')" \
  "v-archivu: kolik souborů je uvnitř archivu"
tema_konec "software a data" 3 "2/11 Instalace softwaru · 2/12 Hash · 2/19 Archivace" \
  verze otisk v-archivu

vypis_souhrn; _rc=$?

# ── rozpad místo známky ───────────────────────────────────────────
# Musí být AŽ ZA souhrnem: jinak by po větě „tohle se neznámkuje" hned
# následovalo „Splněno X z Y" a popřelo ji.
if [ -z "$_krok_filtr" ]; then
  printf "  ${_B}Co vám sedí a co ne${_0}\n\n"
  for i in "${!TEMATA[@]}"; do
    STAV="${VYSLEDKY[i]}"; PRAZ="${NEVYPLNENO[i]}"
    # Počet je vpředu schválně: má pevnou šířku, takže sloupec sedí bez
    # dopočítávání mezer. Zarovnávat podle názvu tématu nejde — `printf %-Ns`
    # počítá bajty a `${#…}` znaky jen v UTF-8 locale, na kterou se nedá
    # spolehnout. České názvy by se rozjely.
    if [ "${STAV%%/*}" = "${STAV##*/}" ]; then
      printf "    ${_Z}%-5s %s${_0}\n" "$STAV" "${TEMATA[i]}"
    elif [ "${PRAZ:-0}" -gt 0 ]; then
      # Nevyplněné ≠ neuměl. Odkaz sem nepatří, žák sem prostě nedošel.
      printf "    %-5s %s  — %s nevyplněno, doplňte a spusťte znovu\n" \
        "$STAV" "${TEMATA[i]}" "$PRAZ"
    else
      printf "    ${_M}%-5s %s${_0}  → %s\n" "$STAV" "${TEMATA[i]}" "${ODKAZY[i]}"
    fi
  done
  echo
  echo "  Tohle se neznámkuje. Šipka vpravo říká, kam se vrátit."
  echo
fi

exit "$_rc"
