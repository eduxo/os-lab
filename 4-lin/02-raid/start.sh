#!/bin/bash
# 4/02 — RAID 1. Prostředí: žákova stanice, DRUHÝ a TŘETÍ labový disk.
#
# Proč druhý a třetí: na prvním leží práce ze cvičení 4/01 a laby si nemají
# navzájem mazat výsledky. Každý lab 4. ročníku si proto bere vlastní disky
# podle pořadí — viz karta bloku A.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/disk-lib.sh"

# Projekt musí být připojený v KAŽDÉ hodině, ne jen v té, ve které vznikl.
# Trvalý zápis do fstab je učivo cvičení 4/06; do té doby ho připojuje
# prostředí. Bez toho by ~/projekt byl po restartu prázdný adresář na
# systémovém disku a žák by do něj ukládal maturitní práci naslepo.
projekt_pripoj >/dev/null 2>&1 || true

LAB="$HOME/netlab/raid"
FORMULAR="$LAB/pole.txt"
PRIPOJ="$LAB/data"
NAZEV="RAID-$ZAK2"

zkontroluj_disky 3 || exit 1
DISK_A="${LABOVE_DISKY[1]}"
DISK_B="${LABOVE_DISKY[2]}"

mkdir -p "$LAB" "$PRIPOJ"
if [ ! -s "$FORMULAR" ]; then
  cat > "$FORMULAR" <<'FORMULAR_KONEC'
# Pole RAID — vyplňte hodnoty za dvojtečku.
#
# zarizeni  = jméno pole, které jste vytvořili (např. md0), bez /dev/
# uroven    = úroveň RAIDu, kterou jste použili (číslo)
# clenu     = kolik disků je v poli
# kapacita  = kolik místa pole nabízí (z výpisu lsblk, i s jednotkou)
# navesti   = návěští souborového systému na poli
zarizeni:
uroven:
clenu:
kapacita:
navesti:
FORMULAR_KONEC
fi

# Disky musí být na začátku prázdné — jinak mdadm najde cizí superblok
# a pole se poskládá jinak, než žák čeká.
NECISTE=""
for D in "$DISK_A" "$DISK_B"; do
  OBSAH="$(lsblk -rno NAME "/dev/$D" 2>/dev/null | tail -n +2)"
  PODPIS="$(lsblk -dno PTTYPE,FSTYPE "/dev/$D" 2>/dev/null | tr -d ' ')"
  if [ -n "$OBSAH" ] || [ -n "$PODPIS" ]; then NECISTE="$NECISTE $D"; fi
done
if [ -n "$(grep -oE '^md[0-9]+' /proc/mdstat 2>/dev/null | head -1)" ] \
   && [ -n "$(blkid -L "$NAZEV" 2>/dev/null)" ]; then
  echo
  echo "  Vaše pole z minule ještě stojí — nechávám ho být."
  echo "  Chcete začít znovu?  ./reset.sh"
elif [ -n "$NECISTE" ]; then
  echo
  echo "  Na discích$NECISTE je zbytek z jiného cvičení:"
  for D in $NECISTE; do lsblk -o NAME,SIZE,FSTYPE,LABEL "/dev/$D" 2>/dev/null | sed 's/^/    /'; done
  echo
  read -r -p "  Vyčistit je? [a/N] " ODP
  if [[ "$ODP" =~ ^[aAyY]$ ]]; then
    for D in $NECISTE; do uvolni_disk "$D" || exit 1; done
    echo "  Hotovo, disky jsou prázdné."
  else
    echo "  Cvičení potřebuje dva prázdné disky. Končím."; exit 1
  fi
fi

cat <<EOF

  Připraveno.

    Disky pro pole:   /dev/$DISK_A  a  /dev/$DISK_B
    Formulář:         $FORMULAR
    Kam připojovat:   $PRIPOJ
    Návěští:          $NAZEV

  Na první labový disk (/dev/${LABOVE_DISKY[0]}) dnes nesaháte — je na něm
  práce z minulé hodiny.

  Průběžná kontrola:

    cd ~/os-lab/4-lin/02-raid && ./check.sh --krok 1

EOF
