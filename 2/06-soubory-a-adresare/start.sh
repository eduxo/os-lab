#!/bin/bash
# 2/06 — Práce se soubory a adresáři. Prostředí: žákova stanice (bez kontejneru).
# Vysype do jednoho adresáře dokumenty, které si žák musí roztřídit. Jméno
# souboru o obsahu nic neříká — oddělení je až na prvním řádku uvnitř.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

UKLID="$HOME/netlab/uklid"
SOUPIS="$UKLID/soupis.txt"

if [ -d "$UKLID" ]; then
  echo
  echo "  Prostředí už existuje v $UKLID — pokračujte, kde jste skončili."
  echo "  Chcete začít znovu?  ./reset.sh"
  echo
  exit 0
fi

echo "  Vysypávám naskenované dokumenty…"
mkdir -p "$UKLID"

ODDELENI=(sklad ucetni vedeni)
POCET=12

# První tři soubory dostanou každý jiné oddělení, aby žádné nezůstalo prázdné.
# Zbytek se losuje. Bez té pojistky by se mohlo stát, že třídění nemá co třídit.
PRVNI=($(lab_vyber 3 3 41))

for i in $(seq 1 "$POCET"); do
  if [ "$i" -le 3 ]; then
    IDX=${PRVNI[$((i-1))]}
  else
    IDX=$(lab_vyber 3 1 $((50 + i)))
  fi
  ODD="${ODDELENI[$((IDX-1))]}"
  ROK=$(( 2024 + (i % 3) ))
  # Jméno je záměrně bezobsažné — kdo netřídí podle obsahu, netřídí správně.
  JMENO="$(printf 'sken-%04d.txt' $(( 100 + i * 7 + ZAK )))"
  cat > "$UKLID/$JMENO" <<DOKUMENT
Oddělení: $ODD
Rok: $ROK

Naskenovaný dokument $i. Papírový originál je v archivu.
DOKUMENT
done

# Prázdný adresář po skenování — smaže se jiným příkazem než soubory.
mkdir -p "$UKLID/sken-docasne"

cat > "$SOUPIS" <<'FORMULAR'
# Soupis po roztřídění — vyplňte hodnoty za dvojtečku.
# Kolik dokumentů skončilo v každém oddělení.
sklad:
ucetni:
vedeni:
FORMULAR

cat <<EOF

  Prostředí je připravené.

    Naskenované dokumenty:  $UKLID
    Formulář soupisu:       $SOUPIS

  Přepněte se do adresáře a rozhlédněte se:

    cd ~/netlab/uklid

  Průběžnou kontrolu spouštějte odsud, ne z ~/netlab/uklid:

    cd ~/os-lab/2/06-soubory-a-adresare && ./check.sh --krok 1

EOF
