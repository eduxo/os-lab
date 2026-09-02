#!/bin/bash
# 2/01 — Laboratoř a první start. Prostředí: žákova stanice (bez kontejneru).
# Založí adresář služební dokumentace a v něm formulář s přehledem stanice.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

DOKU="$HOME/dokumentace"
PREHLED="$DOKU/stanice.txt"

if [ -f "$PREHLED" ]; then
  echo
  echo "  Formulář už existuje v $PREHLED — pokračujte, kde jste skončili."
  echo "  Jméno, které má mít vaše stanice:  stanice-$ZAK2"
  echo "  Chcete začít znovu?  ./reset.sh"
  echo
  exit 0
fi

echo "  Zakládám adresář služební dokumentace…"
mkdir -p "$DOKU"

# Formulář zakládá skript proto, aby se klíče na levé straně psaly všem
# stejně. Kontrola je čte doslova — vlastní jména by neprošla.
cat > "$PREHLED" <<'FORMULAR'
# Přehled pracovní stanice — vyplňte hodnoty za dvojtečku.
# Řádky začínající mřížkou nechte být.
hostname:
jadro:
pamet:
disk:
snapshot:
FORMULAR

cat <<EOF

  Prostředí je připravené.

    Formulář k vyplnění:  $PREHLED
    Vaše číslo (XX):      $ZAK2
    Jméno vaší stanice:   stanice-$ZAK2
    Jméno snímku:         cisty-system-$ZAK2

  Průběžnou kontrolu spouštějte odsud:

    cd ~/os-lab/2/01-laborator && ./check.sh --krok 1

EOF
