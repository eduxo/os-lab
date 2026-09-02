#!/bin/bash
# 2/10 — ověření
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

AUDIT="$HOME/netlab/audit"
VYSLEDEK="$AUDIT/vysledek"
ODPOVEDI="$AUDIT/odpovedi.txt"

krok 1 "Prostředí"
require_path "$AUDIT" \
  "archiv k auditu je rozbalený" \
  "chybí ~/netlab/audit — spusťte ./start.sh"

krok 2 "Roztřídění podle roku"
for R in 2024 2025 2026; do
  require_path "$VYSLEDEK/$R" "adresář vysledek/$R existuje" "chybí vysledek/$R"
done

# Rok se čte z obsahu dokladu, ne ze jména. Kdo netřídil podle obsahu,
# se sem netrefí ani náhodou.
SPATNE=0; TRIDENO=0
for R in 2024 2025 2026; do
  [ -d "$VYSLEDEK/$R" ] || continue
  # Do hloubky — rozšíření nabízí roztřídit doklady ještě podle typu.
  while IFS= read -r F; do
    [ -f "$F" ] || continue
    TRIDENO=$((TRIDENO + 1))
    ROK="$(sed -n 's/^Rok: *//p' "$F" | head -1)"
    [ "$ROK" = "$R" ] || SPATNE=$((SPATNE + 1))
  done <<< "$(find "$VYSLEDEK/$R" -name 'doklad-*.txt' 2>/dev/null)"
done
if [ "$TRIDENO" -eq 15 ] && [ "$SPATNE" -eq 0 ]; then
  uspech "všech 15 dokladů leží v adresáři svého roku"
elif [ "$SPATNE" -gt 0 ]; then
  # Počet se u ověřovacího cvičení nehlásí. S ním by šlo doklady dotřídit
  # metodou pokus-omyl podle toho, jestli číslo kleslo — bez jediného pohledu
  # dovnitř dokladu, což je právě ta dovednost, kterou lab měří.
  chyba "ne všechny doklady leží v adresáři svého roku"
else
  chyba "roztříděno je $TRIDENO dokladů z 15"
fi

# Přehled musí sedět na skutečné počty — a je to výstup roury, ne ruční zápis.
PREHLED="$VYSLEDEK/prehled.txt"
if [ -f "$PREHLED" ]; then
  SEDI=1
  for R in 2024 2025 2026; do
    N=$(find "$VYSLEDEK/$R" -name 'doklad-*.txt' 2>/dev/null | grep -c '')
    grep -qE "(^|[^0-9])$N[^0-9]+$R" "$PREHLED" || SEDI=0
  done
  if [ "$SEDI" -eq 1 ]; then
    uspech "prehled.txt uvádí u každého roku správný počet dokladů"
  else
    chyba "prehled.txt neuvádí u každého roku správný počet"
    poznamka "má vzniknout rourou, tedy ve tvaru „počet rok\" na řádek"
  fi
else
  chyba "chybí vysledek/prehled.txt"
fi

krok 3 "Nálezy a výpis chyb"
VELKY=$(find "$AUDIT" -type f -size +100k 2>/dev/null | head -1)
VELKY="${VELKY#"$AUDIT"/}"
# Hledáme jen v dokladech. Bez omezení by grep našel sám sebe: úkol E ukládá
# do vysledek/postup.txt historii příkazů a v ní je nutně `grep -rn "Auditní
# kód" .` — pořadí výpisu dává readdir, takže se postup.txt může dostat před
# skutečný doklad a správnému žákovi to překlopí dva PASSy na FAIL.
NALEZ=$(grep -rn --include='doklad-*.txt' 'Auditní kód' "$AUDIT" 2>/dev/null | head -1)
KOD_SOUBOR="${NALEZ%%:*}"; KOD_SOUBOR="${KOD_SOUBOR#"$AUDIT"/}"
ZBYTEK="${NALEZ#*:}"; KOD_RADEK="${ZBYTEK%%:*}"

require_zaznam_cesta "$ODPOVEDI" velky-soubor "$VELKY" "$AUDIT" \
  "v odpovědích je cesta k souboru většímu než 100 kB"
require_zaznam "$ODPOVEDI" kod "$(lab_kod AUDIT 10)" \
  "v odpovědích je auditní kód"
# Pozor: doklad s kódem se během třídění přesune. Kontrola hledá, kde je
# soubor teď — proto se zapisuje cesta podle konečného stavu.
_PRED=$_fail
require_zaznam_cesta "$ODPOVEDI" kod-soubor "$KOD_SOUBOR" "$AUDIT" \
  "v odpovědích je doklad, ve kterém kód leží"
# Nápověda jen tehdy, když kontrola opravdu selhala — po PASS je matoucí.
[ "$_fail" -gt "$_PRED" ] && \
  poznamka "cesta k dokladu se zapisuje podle stavu po roztřídění, ne před ním"
require_zaznam "$ODPOVEDI" kod-radek "$KOD_RADEK" \
  "v odpovědích je řádek, na kterém kód je"

# Výpis chyb: musí obsahovat všechny chybové řádky a nic jiného.
CHYBY="$VYSLEDEK/chyby.txt"
# Pozor na `|| echo 0`: když soubor existuje a vzor v něm není, grep vypíše
# 0 a skončí kódem 1 — echo pak přidá druhou nulu a hodnota má dva řádky.
POCET_CHYB=$(grep -c 'ERROR' "$AUDIT/zaloha.log" 2>/dev/null); POCET_CHYB="${POCET_CHYB:-0}"
if [ -f "$CHYBY" ]; then
  MA=$(grep -c '' "$CHYBY")
  MA_JINE=$(grep -vc 'ERROR' "$CHYBY")
  if [ "$MA" -eq "$POCET_CHYB" ] && [ "$MA_JINE" -eq 0 ]; then
    uspech "chyby.txt obsahuje právě chybové řádky ze zaloha.log"
  else
    chyba "chyby.txt neobsahuje právě chybové řádky (má $MA řádků, z toho $MA_JINE jiných)"
  fi
else
  chyba "chybí vysledek/chyby.txt"
fi

# Postup je podklad pro obhajobu — vyučující si z něj vybere příkazy.
require_min_radku "$VYSLEDEK/postup.txt" 15 \
  "postup.txt zachycuje aspoň patnáct příkazů z vaší práce" \
  "ve vysledek/postup.txt zatím není patnáct příkazů z vaší práce"

# Negativní kontrola: doklady se nesmí ztratit ani přibýt.
# Hlídá se jen ztráta. Rovnost by potrestala i žáka, který si udělal kopii
# navíc nebo si zkusil rozšíření — přidat si nic nezjednodušuje.
CELKEM=$(find "$AUDIT" -name 'doklad-*.txt' 2>/dev/null | grep -c '')
if [ "${CELKEM:-0}" -ge 15 ]; then
  uspech "žádný doklad se neztratil"
else
  chyba "dokladů je ${CELKEM:-0}, má jich být aspoň patnáct — nějaký chybí"
fi

vypis_souhrn
