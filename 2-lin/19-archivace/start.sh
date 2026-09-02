#!/bin/bash
# 2/19 — Archivace a komprese. Prostředí: žákova stanice.
# Připraví data k zabalení. Archivy nedělá — to je učivo.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

ARCH="$HOME/netlab/archiv"
DATA="$ARCH/data"
FORMULAR="$ARCH/prehled.txt"

vyrob_formular() {
  cat > "$FORMULAR" <<'FORMULAR_KONEC'
# Přehled archivace — vyplňte hodnoty za dvojtečku.
# souboru      = kolik souborů je uvnitř archivu zaloha.tar
# velikost-tar = velikost zaloha.tar v bajtech
# velikost-tgz = velikost zaloha.tar.gz v bajtech
# mensi        = který archiv je menší (tar nebo tgz)
souboru:
velikost-tar:
velikost-tgz:
mensi:
FORMULAR_KONEC
}

# Prostředí, které už stojí, se nepřestavuje — jen se doplní formulář,
# pokud si ho žák smazal. Bez toho ho kontrola posílá na ./start.sh,
# ten odpoví „už existuje", a žák se z té smyčky nedostane.
if [ -d "$ARCH" ]; then
  echo
  if [ -f "$FORMULAR" ]; then
    echo "  Prostředí už existuje v $ARCH — pokračujte, kde jste skončili."
  else
    vyrob_formular
    echo "  Prostředí už existuje v $ARCH. Chyběl formulář, doplnila jsem ho."
  fi
  echo "  Chcete začít úplně znovu?  ./reset.sh"
  echo
  exit 0
fi

echo "  Připravuji data k zálohování…"
mkdir -p "$DATA"/{dokumenty,logy}

# Počet souborů se liší podle čísla žáka, takže se liší i velikosti.
POCET_DOK=$(( 3 + $(lab_vyber 4 1 211) ))
for i in $(seq 1 "$POCET_DOK"); do
  printf 'Dokument %02d oddělení skladu.\nPoložka: %s\nMnožství: %d ks\n' \
    "$i" "$(printf 'SKU-%04d' $(( 1000 + i * 7 + ZAK )))" $(( 10 + i * 3 )) \
    > "$DATA/dokumenty/doklad-$(printf '%02d' "$i").txt"
done

# Logy jsou schválně hodně opakující se — na nich je vidět, co komprese umí.
POCET_LOG=$(( 2 + $(lab_vyber 3 1 212) ))
for i in $(seq 1 "$POCET_LOG"); do
  { for r in $(seq 1 400); do
      printf '2026-12-%02d 08:%02d INFO zaloha probehla v poradku\n' \
        $(( r % 28 + 1 )) $(( r % 60 ))
    done; } > "$DATA/logy/sluzba-$i.log"
done

vyrob_formular

cat <<EOF

  Prostředí je připravené.

    Data k zálohování:  $DATA
    Formulář:           $FORMULAR

  Přepněte se do adresáře:

    cd ~/netlab/archiv

  Průběžnou kontrolu spouštějte odsud:

    cd ~/os-lab/2/19-archivace && ./check.sh --krok 1

EOF
