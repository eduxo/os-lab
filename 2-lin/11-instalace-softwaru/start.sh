#!/bin/bash
# 2/11 — Instalace softwaru a zdroje balíčků. Prostředí: žákova stanice.
# Nic neinstaluje — jen přidělí balíček a připraví formulář. Instalace je učivo.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

SOFT="$HOME/netlab/software"
PREHLED="$SOFT/prehled.txt"

# Malé balíčky bez velkých závislostí. Třicet žáků je stahuje naráz přes
# síťový disk, takže nic velkého. Do šablony VM se předinstalovat NESMÍ —
# instalace je tady učivem, ne přípravou.
BALICKY=(tree ncdu figlet sl jq htop)
MUJ="${BALICKY[$(( $(lab_vyber 6 1 111) - 1 ))]}"

if [ -f "$PREHLED" ]; then
  echo
  echo "  Prostředí už existuje v $SOFT — pokračujte, kde jste skončili."
  echo "  Váš balíček: $MUJ"
  echo "  Chcete začít znovu?  ./reset.sh"
  echo
  exit 0
fi

# Balíček nesmí být v obrazu předinstalovaný — instalace je tady učivem.
if dpkg -s "$MUJ" >/dev/null 2>&1; then
  echo
  echo "  POZOR: balíček $MUJ je na téhle stanici už nainstalovaný."
  echo "  Instalace je přitom dnešní učivo. Řekněte o tom vyučujícímu —"
  echo "  do obrazu VM tenhle balíček nepatří."
  echo
fi

mkdir -p "$SOFT"

cat > "$PREHLED" <<FORMULAR
# Přehled instalace — vyplňte hodnoty za dvojtečku.
# balicek  = který balíček jste instalovali (je přidělený, viz níže)
# verze    = verze, kterou nainstaloval váš systém
# souboru  = kolik souborů balíček do systému přinesl
# zdroj    = adresa, ze které se balíčky stahují
balicek: $MUJ
verze:
souboru:
zdroj:
FORMULAR

cat <<EOF

  Prostředí je připravené.

    Formulář:        $PREHLED
    Váš balíček:     $MUJ
    Vaše číslo (XX): $ZAK2

  Balíček je přidělený podle vašeho čísla — soused má jiný.

  Průběžnou kontrolu spouštějte odsud:

    cd ~/os-lab/2/11-instalace-softwaru && ./check.sh --krok 1

EOF
