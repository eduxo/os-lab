#!/bin/bash
# 2/17 — Rozšířená oprávnění: setgid a sticky. Prostředí: žákova stanice.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

SDILENE="$HOME/netlab/sdilene"
FORMULAR="$SDILENE/zaznam.txt"

# Skupina projektu se u každého žáka liší.
SKUPINY=(vedeni sklad ucetni)
SKUPINA="${SKUPINY[$(( $(lab_vyber 3 1 181) - 1 ))]}"

if [ -f "$FORMULAR" ]; then
  echo
  echo "  Prostředí už existuje v $SDILENE — pokračujte, kde jste skončili."
  echo "  Skupina projektu: $SKUPINA"
  echo
  exit 0
fi

echo "  Připravuji sdílené adresáře…"
mkdir -p "$SDILENE"/{projekt,odkladiste}
printf 'Zadání projektu.\n' > "$SDILENE/projekt/zadani.txt"

cat > "$FORMULAR" <<FORMULAR_KONEC
# Sdílené adresáře — zadání a formulář.
#
# projekt      skupina $SKUPINA, členové smí číst i zapisovat, ostatní nic.
#              Každý nový soubor uvnitř musí patřit skupině $SKUPINA,
#              i když ho vytvoří někdo, kdo má jinou primární skupinu.
#
# odkladiste   sem smí zapisovat kdokoli, ale nikdo nesmí smazat cizí soubor.
#
# Do formuláře zapište hodnoty zjištěné na hotovém systému:
# skupina-souboru = skupina souboru, který v adresáři projekt nově vytvoříte
# prava-projekt   = práva adresáře projekt tak, jak je vypíše ls -ld (deset znaků)
# prava-odkladiste = totéž u adresáře odkladiste
skupina-souboru:
prava-projekt:
prava-odkladiste:
FORMULAR_KONEC

cat <<EOF

  Prostředí je připravené.

    Sdílené adresáře:  $SDILENE
    Zadání a formulář: $FORMULAR
    Skupina projektu:  $SKUPINA

  Průběžnou kontrolu spouštějte odsud:

    cd ~/os-lab/2/17-rozsirena-opravneni && ./check.sh --krok 1

EOF
