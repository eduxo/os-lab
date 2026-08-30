#!/bin/bash
# 2/06 — ověření
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

UKLID="$HOME/netlab/uklid"
SOUPIS="$UKLID/soupis.txt"

krok 1 "Prostředí"
require_path "$UKLID" \
  "adresář ~/netlab/uklid existuje" \
  "chybí ~/netlab/uklid — spusťte ./start.sh"

krok 2 "Roztřídění dokumentů"
for D in sklad ucetni vedeni; do
  require_path "$UKLID/$D" "adresář $D existuje" "chybí adresář $D"
done

# Správné umístění se čte z obsahu souboru, ne ze seznamu v tomhle skriptu.
# Kdo dokument nepřečetl, netrefí se — jméno o oddělení nic neříká.
SPATNE=0; ZKONTROLOVANO=0
# Hledá se do hloubky, ne jen o patro níž. Rozšíření nabízí roztřídit doklady
# ještě podle roku do podadresářů — a to by při plochém globu shodilo všechny
# kontroly za práci, kterou žák udělal navíc a správně.
for D in sklad ucetni vedeni; do
  [ -d "$UKLID/$D" ] || continue
  while IFS= read -r F; do
    [ -f "$F" ] || continue
    ZKONTROLOVANO=$((ZKONTROLOVANO + 1))
    ODD="$(sed -n 's/^Oddělení: *//p' "$F" | head -1)"
    [ "$ODD" = "$D" ] || SPATNE=$((SPATNE + 1))
  done <<< "$(find "$UKLID/$D" -name 'sken-*.txt' 2>/dev/null)"
done
if [ "$ZKONTROLOVANO" -eq 0 ]; then
  chyba "v odděleních zatím není žádný dokument"
elif [ "$SPATNE" -eq 0 ]; then
  uspech "všech $ZKONTROLOVANO roztříděných dokumentů leží ve správném oddělení"
else
  chyba "$SPATNE z $ZKONTROLOVANO dokumentů leží ve špatném oddělení"
  poznamka "oddělení je na prvním řádku uvnitř souboru, ne v jeho jménu"
fi

# Netříděné zbytky. Bez tohohle by stačilo přesunout jeden soubor.
# Jen dokumenty, ne každé .txt. Kdo si při nácviku v Kroku 2 založí soubory
# omylem o adresář výš, nesmí kvůli tomu dostat FAIL za roztřídění.
ZBYVA=$(find "$UKLID" -maxdepth 1 -name 'sken-*.txt' 2>/dev/null | grep -c '')
if [ "${ZBYVA:-0}" -eq 0 ]; then
  uspech "v ~/netlab/uklid už nezůstal žádný neroztříděný dokument"
else
  chyba "v ~/netlab/uklid zbývá $ZBYVA neroztříděných dokumentů"
fi

# Negativní kontrola: dokumentů musí být pořád dvanáct. Kdo si třídění
# zjednodušil mazáním, dostane to sem, ne do lepší známky.
# Záloha se nepočítá — jsou to tytéž dokumenty podruhé, ne nové.
CELKEM=$(find "$UKLID" -name 'sken-*.txt' -not -path "$UKLID/vedeni-zaloha/*" 2>/dev/null | grep -c '')
# Hlídá se jen ztráta. Rovnost by potrestala žáka, který si udělal kopii navíc
# nebo zkusil rozšíření — přidáním si nic nezjednoduší.
if [ "${CELKEM:-0}" -ge 12 ]; then
  uspech "žádný dokument se neztratil"
else
  chyba "dokumentů je ${CELKEM:-0}, má jich být aspoň dvanáct — nějaký chybí"
  poznamka "vrátí je ./reset.sh, ale přijdete o roztřídění"
fi

krok 3 "Záloha, úklid a soupis"
require_path "$UKLID/vedeni-zaloha" \
  "existuje kopie adresáře vedeni" \
  "chybí ~/netlab/uklid/vedeni-zaloha"
POCET_V=$(find "$UKLID/vedeni" -name 'sken-*.txt' 2>/dev/null | grep -c '')
POCET_Z=$(find "$UKLID/vedeni-zaloha" -name 'sken-*.txt' 2>/dev/null | grep -c '')
if [ "${POCET_Z:-0}" -gt 0 ] && [ "${POCET_Z:-0}" -eq "${POCET_V:-0}" ]; then
  uspech "kopie obsahuje stejný počet dokumentů jako originál"
else
  chyba "kopie neobsahuje totéž co adresář vedeni"
  poznamka "adresář se kopíruje i s obsahem, na to je u cp potřeba přepínač"
fi

if [ -d "$UKLID/sken-docasne" ]; then
  chyba "prázdný adresář sken-docasne pořád existuje"
else
  uspech "prázdný adresář sken-docasne je smazaný"
fi

# Počty se čtou ze skutečného stavu — soupis musí sedět na to, co žák udělal.
for D in sklad ucetni vedeni; do
  N=$(find "$UKLID/$D" -name 'sken-*.txt' 2>/dev/null | grep -c '')
  require_zaznam "$SOUPIS" "$D" "$N" "v soupisu sedí počet dokumentů v oddělení $D"
done

vypis_souhrn
