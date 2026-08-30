#!/bin/bash
# 2/04 — Příkazový řádek II. Prostředí: žákova stanice (bez kontejneru).
# Naplní adresář přijaté pošty tak, aby výsledky globů byly u každého jiné.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

PRIJEM="$HOME/netlab/prijem"
SOUPIS="$PRIJEM/soupis.txt"

if [ -d "$PRIJEM" ]; then
  echo
  echo "  Prostředí už existuje v $PRIJEM — pokračujte, kde jste skončili."
  echo "  Chcete začít znovu?  ./reset.sh"
  echo
  exit 0
fi

echo "  Připravuji adresář přijaté pošty…"
mkdir -p "$PRIJEM"
cd "$PRIJEM" || exit 1

# Počet faktur i jména vybraných souborů se odvozují z čísla žáka. Odpovědi
# se tak liší člověk od člověka, i když je postup pro všechny stejný.
POCET_PDF=$(( 4 + ZAK % 5 ))
for i in $(seq 1 "$POCET_PDF"); do
  printf 'Faktura %02d/2026 — částka %d Kč\n' "$i" $(( 1200 + i * 137 )) \
    > "$(printf 'faktura-2026-%02d-%03d.pdf' $(( (i - 1) % 6 + 1 )) $(( 100 + i )))"
done

printf 'Smlouva o dílo, dodatek A.\n'   > smlouva-alfa.txt
printf 'Smlouva o dílo, dodatek B.\n'   > smlouva-beta.txt
printf 'Poznámka k předání agendy.\n'   > poznamka.txt
printf 'polozka;pocet;cena\nsroub;120;2\n' > sklad.csv
printf 'oddeleni;faktur\nsklad;3\n'        > prehled.csv

# Jediný soubor se čtyřznakovým jménem — odpověď na úkol s globem ????
KRATKA=(plan nota sken mapa kopi)
printf 'Ruční poznámka, nemá příponu.\n' > "${KRATKA[$(( ZAK % 5 ))]}"

# Největší soubor v adresáři. Musí být zřetelně největší, aby výsledek
# řazení podle velikosti nezáležel na tom, co si žák do adresáře přidá.
VELKE=(archiv-2025.log ucetni-export.log sklad-export.log prenos-dat.log)
VELKY="${VELKE[$(( ZAK % 4 ))]}"
{ for i in $(seq 1 4000); do printf 'radek %05d oddeleni sklad polozka %04d\n' "$i" $(( i % 97 )); done; } > "$VELKY"

cat > "$SOUPIS" <<'FORMULAR'
# Soupis přijaté pošty — vyplňte hodnoty za dvojtečku.
# Řádky s mřížkou nechte být.
pdf:
ctyri:
nejvetsi:
prepinac:
FORMULAR

cat <<EOF

  Prostředí je připravené.

    Přijatá pošta:     $PRIJEM
    Formulář soupisu:  $SOUPIS
    Vaše číslo (XX):   $ZAK2

  Začněte tím, že se do adresáře přepnete:

    cd ~/netlab/prijem

  Průběžnou kontrolu spouštějte odsud, ne z ~/netlab/prijem:

    cd ~/os-lab/2/04-prikazovy-radek-2 && ./check.sh --krok 1

EOF
