#!/bin/bash
# 3/00 — Rozcvička po prázdninách. Prostředí: žákova stanice.
# Diagnostika, ne písemka: patnáct mikroúkolů z celého 2. ročníku.
# Data se losují z čísla žáka, takže soused má jiné odpovědi.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

ROZ="$HOME/netlab/rozcvicka"
DATA="$ROZ/data"
FORMULAR="$ROZ/odpovedi.txt"

KOD="$(lab_kod ROZ 300)"
POCET=$(( 6 + $(lab_vyber 5 1 301) ))        # kolik položek má data/
PRAVA_FOND=(640 604 660 606 664)
PRAVA="${PRAVA_FOND[$(( $(lab_vyber 5 1 302) - 1 ))]}"
CHYB=$(( 3 + $(lab_vyber 6 1 303) ))         # kolik řádků ERROR je v logu
POCET_USEKU=$(( 2 + $(lab_vyber 3 1 306) ))  # kolik různých úseků log obsahuje
POCET_DOK=$(( 2 + $(lab_vyber 4 1 307) ))    # kolik dokumentů je v archivu

vyrob_formular() {
  cat > "$FORMULAR" <<'FORMULAR_KONEC'
# Rozcvička — vyplňte hodnoty za dvojtečku. NENÍ TO PÍSEMKA.
# Kontrola vám ukáže, které téma vám vypadlo, a kam se pro něj vrátit.
#
# ── pohyb a cesty ──────────────────────────────────────────────
# domov     = absolutní cesta k vašemu domovskému adresáři
# polozek   = kolik položek je v ~/netlab/rozcvicka/data
# symlink   = absolutní cesta, kam vede odkaz ~/netlab/rozcvicka/zkratka
domov:
polozek:
symlink:

# ── soubory a text ─────────────────────────────────────────────
# soubor-kod = jméno souboru (bez cesty), ve kterém je kód ROZ-....
# radku-chyba = kolik řádků logu sluzba.log obsahuje slovo ERROR
# prvni-slovo = první slovo prvního řádku souboru data/prehled.txt
soubor-kod:
radku-chyba:
prvni-slovo:

# ── roury a přesměrování ───────────────────────────────────────
# nejcastejsi = který úsek se v sluzba.log objevuje nejčastěji
# unikatnich  = kolik různých úseků se v sluzba.log objevuje
# (třetí úkol není otázka: uložte chybové řádky do vysledek/chyby.txt)
nejcastejsi:
unikatnich:

# ── práva a účty ───────────────────────────────────────────────
# prava    = práva souboru data/tajne.txt číselně (tři číslice)
# vlastnik = vlastník a skupina souboru data/tajne.txt ve tvaru vlastnik:skupina
# skupin   = do kolika skupin patří váš účet
prava:
vlastnik:
skupin:

# ── software a data ────────────────────────────────────────────
# verze    = verze nainstalovaného balíčku bash
# otisk    = prvních 8 znaků otisku SHA-256 souboru data/prehled.txt
# v-archivu = kolik souborů (ne adresářů) je uvnitř zaloha.tar.gz
verze:
otisk:
v-archivu:
FORMULAR_KONEC
}

# Data ani archiv nenesou žákovu práci, takže se doplňují. Testovat jen
# existenci kořenového adresáře znamená, že částečné smazání je slepá ulička:
# kontrola pošle na start.sh a ten odpoví „už existuje".
CHYBI_DATA=0
[ -d "$DATA" ] && [ -e "$ROZ/zkratka" ] && [ -s "$ROZ/zaloha.tar.gz" ] || CHYBI_DATA=1

if [ -d "$ROZ" ] && [ "$CHYBI_DATA" -eq 0 ]; then
  echo
  if [ -s "$FORMULAR" ]; then
    echo "  Prostředí už existuje v $ROZ — pokračujte, kde jste skončili."
  else
    vyrob_formular
    echo "  Prostředí už existuje v $ROZ. Chyběl formulář, doplnila jsem ho."
  fi
  echo "  Chcete začít úplně znovu?  ./reset.sh"
  echo
  exit 0
fi

if [ -d "$ROZ" ]; then
  echo "  Některá data chyběla — doplňuji je. Vyplněné odpovědi zůstávají."
else
  echo "  Připravuji rozcvičku…"
fi
rm -rf "$DATA" "$ROZ/zkratka" "$ROZ/zaloha.tar.gz"
mkdir -p "$DATA/dokumenty" "$DATA/logy" "$ROZ/vysledek"

# ── data/ — dohromady POCET položek ───────────────────────────────
# Položkou je i adresář. Kromě volných souborů vznikne prehled.txt,
# tajne.txt a dva adresáře, proto POCET-4. Kontrola si stejně počítá
# skutečnost, tohle je jen kvůli tomu, aby proměnná znamenala, co říká.
for i in $(seq 1 $(( POCET - 5 )) ); do
  printf 'Záznam %02d\nÚsek: %s\n' "$i" "sklad" > "$DATA/polozka-$(printf '%02d' "$i").txt"
done
# Číslo schválně NEodpovídá počtu položek v adresáři — jinak by `cat prehled.txt`
# byl celou odpovědí na úkol `polozek` a `ls -A` by si žák nemusel vyzkoušet.
printf 'Přehled skladu\nStav k dnešnímu dni\nKusů na skladě: %d\n' $(( POCET * 37 + 114 )) > "$DATA/prehled.txt"
# Skrytá položka: díky ní má smysl ptát se na `ls -A` místo `ls`.
printf 'Poznámka správce — nemazat.\n' > "$DATA/.poznamka"

# kód schovaný v jednom z dokumentů — hledá se přes grep -r
KDE=$(lab_vyber "$POCET_DOK" 1 304)
for i in $(seq 1 "$POCET_DOK"); do
  if [ "$i" -eq "$KDE" ]; then
    printf 'Dokument %d\nInterní kód: %s\nSchváleno.\n' "$i" "$KOD" \
      > "$DATA/dokumenty/dokument-$i.txt"
  else
    printf 'Dokument %d\nBez zvláštních poznámek.\n' "$i" \
      > "$DATA/dokumenty/dokument-$i.txt"
  fi
done

# ── log: úseky s různou četností, ať má „nejčastější" jednoznačnou odpověď ──
USEKY_FOND=(sklad vratnice kotelna expedice recepce)
USEKY=("${USEKY_FOND[@]:0:POCET_USEKU}")
NEJ=$(lab_vyber "$POCET_USEKU" 1 305)
{
  for u in $(seq 1 "$POCET_USEKU"); do
    OPAK=$(( u == NEJ ? 12 + CHYB : 3 + u ))
    for r in $(seq 1 "$OPAK"); do
      printf '2026-09-%02d 08:%02d INFO %s v poradku\n' \
        $(( r % 28 + 1 )) $(( r % 60 )) "${USEKY[u-1]}"
    done
  done
  # Chyby padají na JINÝ úsek než ten nejčastější. Jinak by `tail -1` prozradil
  # odpověď na `nejcastejsi` a roura, o kterou v okruhu jde, by byla zbytečná.
  CHYBOVY=$(( NEJ % POCET_USEKU + 1 ))
  for r in $(seq 1 "$CHYB"); do
    printf '2026-09-%02d 09:%02d ERROR %s nedostupny\n' \
      $(( r % 28 + 1 )) $(( r % 60 )) "${USEKY[CHYBOVY-1]}"
  done
} > "$DATA/logy/sluzba.log"

# ── symlink, práva, archiv ────────────────────────────────────────
ln -sfn "$DATA/dokumenty" "$ROZ/zkratka"
printf 'Nic tajného, jen cvičná práva.\n' > "$DATA/tajne.txt"
chmod "$PRAVA" "$DATA/tajne.txt"
# Do archivu jde navíc prehled.txt — bez něj by `v-archivu` bylo totéž co
# `ls zkratka | wc -l` a archiv by se nemusel vůbec otevřít.
tar -czf "$ROZ/zaloha.tar.gz" -C "$DATA" dokumenty prehled.txt

[ -s "$FORMULAR" ] || vyrob_formular

cat <<EOF

  Rozcvička je připravená. Je to **diagnostika, ne písemka** —
  kontrola vám ukáže, které téma vám vypadlo, a kam se pro něj vrátit.

    Data:      $DATA
    Formulář:  $FORMULAR

  Přepněte se do adresáře:

    cd ~/netlab/rozcvicka

  Až budete mít vyplněno:

    cd ~/os-lab/3-lin/00-rozcvicka && ./check.sh

EOF
