#!/bin/bash
# 3/11 — Kapacita a výkon. Prostředí: server provoz-XX přes SSH.
#
# Staví server, na kterém něco žere procesor a něco žere místo. Obojí musí
# žák najít vlastníma rukama: jméno „žrouta" i jeho velikost se losují
# z čísla žáka, takže se odpověď nedá opsat ani od souseda, ani z modelu.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
SERVER_KONT="provoz-$ZAK2"
source "$(dirname "$0")/../../lib/server-lib.sh"
source "$(dirname "$0")/../../lib/provoz-lib.sh"

PROVOZ="$HOME/netlab/provoz"
FORMULAR="$PROVOZ/formular.txt"

vyrob_formular() {
  mkdir -p "$PROVOZ"
  cat > "$FORMULAR" <<'FORM_KONEC'
# Formulář — vyplňte hodnoty za dvojtečku.
# Formulář je na STANICI, práce je na serveru.
#
# zrout    = cesta k největšímu souboru v /srv/archiv, BEZ /srv/archiv na
#            začátku (například 2024/fotky/export.dat)
# velikost = jeho velikost v celých MB (číslo, bez jednotky)
zrout:
velikost:
FORM_KONEC
}

postav_server || exit 1
if nasad_klic_ze_stanice; then
  PRIHLASENI="klíčem (bez hesla)"
else
  PRIHLASENI="heslem: $SERVER_HESLO"
fi

postav_zpracovani
postav_archiv

[ -s "$FORMULAR" ] || vyrob_formular

if [ "$SERVER_NOVY" -eq 0 ]; then
  echo
  echo "  Server $SERVER_KONT už existuje — pokračujete tam, kde jste skončili."
  echo "  Chcete začít znovu?  ./reset.sh"
fi

cat <<EOF

  Server běží.

    Připojení:  ssh $SERVER_UCET@$SERVER_IP
    Přihlášení: $PRIHLASENI

    Archiv:     /srv/archiv
    Formulář:   $FORMULAR   (na stanici)

  Na serveru něco žere procesor a v archivu leží jeden nápadně velký
  soubor. Najděte obojí.

  Kontrola běží na stanici:

    cd ~/os-lab/3-lin/11-kapacita-vykon && ./check.sh --krok 1

EOF
