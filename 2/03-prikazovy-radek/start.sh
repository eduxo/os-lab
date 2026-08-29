#!/bin/bash
# 2/03 — Příkazový řádek I. Prostředí: žákova stanice (bez kontejneru).
# Vytvoří cvičnou strukturu firmy NAKOLENI v domovském adresáři.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

BAZE="$HOME/nakoleni"

if [ -d "$BAZE" ]; then
  echo
  echo "  Prostředí už existuje v $BAZE — pokračujte, kde jste skončili."
  echo "  Chcete začít znovu?  ./reset.sh"
  echo
  exit 0
fi

echo "  Připravuji pracovní adresář firmy NAKOLENI…"

mkdir -p "$BAZE"/{ucetni,sklad,vedeni/porady,archiv/2025/faktury,archiv/2026}

# běžné soubory, mezi kterými se žák pohybuje
printf 'Ceník platný od ledna.\n'            > "$BAZE/sklad/cenik.txt"
printf 'Inventura skladu — nedokončeno.\n'   > "$BAZE/sklad/inventura.txt"
printf 'Mzdy za leden.\n'                    > "$BAZE/ucetni/mzdy-01.txt"
printf 'Zápis z porady 3. 2.\n'              > "$BAZE/vedeni/porady/2026-02-03.txt"
for m in 01 02 03; do printf 'Faktura %s/2025\n' "$m" > "$BAZE/archiv/2025/faktury/f-$m.txt"; done

# Kód odvozený z čísla žáka — chrání proti opisování od souseda.
# NECHRÁNÍ proti vygenerování: tenhle skript je ve veřejném repozitáři, takže
# si kód spočítá každý, kdo ho najde. Hodnocení proto stojí i na poznamky.txt,
# kde žák dokládá cesty a počty, které bez projití struktury nezjistí.
KOD="NAK-$(( (ZAK * 7919) % 9000 + 1000 ))"
printf 'Poznámka pro nového správce.\n\nPřístupový kód pro dnešní cvičení: %s\n' "$KOD" \
     > "$BAZE/archiv/2026/predavaci-protokol.txt"

# nápověda pro krok s man
printf 'Až budete hotovi, zapište sem nalezený kód (jeden řádek).\n' > "$BAZE/odpoved.txt"

cat <<EOF

  Prostředí je připravené.

    Pracovní adresář:  $BAZE
    Vaše číslo:        $ZAK

  Začněte tím, že se do adresáře přepnete:

    cd ~/nakoleni

  Průběžnou kontrolu spustíte odsud:  ./check.sh --krok 1

EOF
