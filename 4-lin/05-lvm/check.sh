#!/bin/bash
# 4/05 — ověření. Části odpovídají krokům zadání 1:1.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/disk-lib.sh"

LAB="$HOME/netlab/lvm"
FORMULAR="$LAB/svazky.txt"
PRIPOJ="$LAB/data"
SKUPINA="data-$ZAK2"
SVAZEK="archiv"
NAZEV="ARCHIV-$ZAK2"
MAPPER="sejf-$ZAK2"
CESTA_LV="/dev/$SKUPINA/$SVAZEK"
MIN_MIB=1300          # po rozšíření; zadání přidává 600 MiB k 800 MiB

zkontroluj_disky 4 || exit 1
DISK="$(labovy_disk 4)"
[ -n "$DISK" ] || { echo "  Labový disk se nepodařilo určit."; exit 1; }

lvm_dotaz() {  # lvm_dotaz PŘÍKAZ SLOUPCE [cíl] → řádek bez okolních mezer
  local p="$1" s="$2"
  local -a cil=(); [ -n "${3:-}" ] && cil=("$3")
  { sudo -n "$p" --noheadings --units m --nosuffix -o "$s" "${cil[@]}" 2>/dev/null \
    || sudo "$p" --noheadings --units m --nosuffix -o "$s" "${cil[@]}" 2>/dev/null; } \
    | sed 's/^ *//; s/ *$//'
}

krok 1 "Otevřený sejf"
require_soubor_neprazdny "$FORMULAR" \
  "formulář svazky.txt je na místě" \
  "chybí ~/netlab/lvm/svazky.txt — spusťte ./start.sh"
TYP="$(lsblk -dno FSTYPE "/dev/$DISK" 2>/dev/null | tr -d ' ')"
[ "$TYP" = "crypto_LUKS" ] \
  && uspech "na /dev/$DISK je šifrovaný kontejner" \
  || chyba "na /dev/$DISK není šifrovaný kontejner — založte ho jako ve cvičení 4"
if [ -b "/dev/mapper/$MAPPER" ]; then
  uspech "svazek je otevřený jako /dev/mapper/$MAPPER"
else
  chyba "svazek není otevřený — /dev/mapper/$MAPPER neexistuje"
  poznamka "otevírá se: sudo cryptsetup open /dev/$DISK $MAPPER"
fi

krok 2 "Fyzický svazek a skupina"
# LVM leží UVNITŘ sejfu. Kdyby si ho žák udělal rovnou na disku, šifrování
# by nechránilo nic — proto se ptáme na konkrétní zařízení, ne jen na to,
# že nějaké PV existuje.
PV="$(lvm_dotaz pvs pv_name "/dev/mapper/$MAPPER")"
PV_VG="$(lvm_dotaz pvs vg_name "/dev/mapper/$MAPPER")"
if [ -n "$PV" ]; then
  uspech "fyzický svazek je na /dev/mapper/$MAPPER, tedy uvnitř sejfu"
  [ -n "$PV_VG" ] && poznamka "patří do skupiny $PV_VG"
else
  chyba "na /dev/mapper/$MAPPER není fyzický svazek"
  poznamka "co LVM vidí, ukáže: sudo pvs"
fi
if [ -n "$(lvm_dotaz vgs vg_name "$SKUPINA")" ]; then
  uspech "skupina svazků $SKUPINA existuje"
else
  chyba "skupina svazků $SKUPINA neexistuje"
fi
require_zaznam "$FORMULAR" fyzicky "/dev/mapper/$MAPPER" "ve formuláři je fyzický svazek"
require_zaznam "$FORMULAR" skupina "$SKUPINA" "ve formuláři je jméno skupiny"

krok 3 "Logický svazek se souborovým systémem"
LV_MIB="$(lvm_dotaz lvs lv_size "$CESTA_LV" | cut -d. -f1)"
if [ -n "$LV_MIB" ]; then
  uspech "logický svazek $SVAZEK ve skupině $SKUPINA existuje"
else
  chyba "logický svazek $SVAZEK ve skupině $SKUPINA neexistuje"
fi
FS="$(lsblk -no FSTYPE "$CESTA_LV" 2>/dev/null | tr -d ' ' | head -1)"
LBL="$(lsblk -no LABEL "$CESTA_LV" 2>/dev/null | sed 's/ *$//' | head -1)"
[ "$FS" = "ext4" ] \
  && uspech "na svazku je souborový systém ext4" \
  || chyba "na svazku je '${FS:-nic}', zadání chce ext4"
[ "$LBL" = "$NAZEV" ] \
  && uspech "souborový systém má návěští $NAZEV" \
  || chyba "návěští je '${LBL:-žádné}', má být $NAZEV"
CIL="$(findmnt -no TARGET "$CESTA_LV" 2>/dev/null | head -1)"
[ "$CIL" = "$PRIPOJ" ] \
  && uspech "svazek je připojený v $PRIPOJ" \
  || chyba "svazek není připojený v $PRIPOJ"
require_zaznam "$FORMULAR" svazek "$SVAZEK" "ve formuláři je jméno logického svazku"

krok 4 "Rozšíření za provozu"
if [ -z "$LV_MIB" ]; then
  chyba "velikost svazku se nepodařilo zjistit"
elif [ "$LV_MIB" -ge "$MIN_MIB" ]; then
  uspech "logický svazek je rozšířený (${LV_MIB} MiB)"
else
  chyba "logický svazek má ${LV_MIB} MiB — po rozšíření jich má být aspoň $MIN_MIB"
fi
# Tohle je jádro celého kroku: `lvextend` BEZ -r zvětší svazek, ale souborový
# systém uvnitř zůstane malý a místa nepřibude. Porovnáváme proto skutečnou
# velikost souborového systému s velikostí svazku, ne svazek sám se sebou.
if mountpoint -q "$PRIPOJ" 2>/dev/null && [ -n "$LV_MIB" ]; then
  FS_MIB="$(df -BM --output=size "$PRIPOJ" 2>/dev/null | tail -1 | tr -dc '0-9')"
  if [ -n "$FS_MIB" ] && [ "$FS_MIB" -ge $(( LV_MIB * 90 / 100 )) ]; then
    uspech "souborový systém zabírá celý svazek (${FS_MIB} MiB)"
  else
    chyba "souborový systém má jen ${FS_MIB:-?} MiB, svazek ${LV_MIB} MiB — nerostl s ním"
    poznamka "svazek se rozšiřuje i se souborovým systémem: lvextend -r"
  fi
fi
require_zaznam_tvar "$FORMULAR" pred '^[0-9]+([.,][0-9]+)? *[KMGT]i?B?$' \
  "ve formuláři je volné místo před rozšířením" \
  "ve formuláři chybí volné místo před rozšířením i s jednotkou"
require_zaznam_tvar "$FORMULAR" po '^[0-9]+([.,][0-9]+)? *[KMGT]i?B?$' \
  "ve formuláři je volné místo po rozšíření" \
  "ve formuláři chybí volné místo po rozšíření i s jednotkou"

krok 5 "Doklad"
UUID="$(lsblk -no UUID "$CESTA_LV" 2>/dev/null | tr -d ' ' | head -1)"
if [ -z "$UUID" ]; then
  chyba "souborový systém na svazku zatím nemá UUID"
elif [ ! -s "$PRIPOJ/prevzeti.txt" ]; then
  chyba "na svazku chybí prevzeti.txt"
elif ! grep -vF "$UUID" "$PRIPOJ/prevzeti.txt" 2>/dev/null | grep -qE '.{20,}'; then
  chyba "v prevzeti.txt je jen UUID — chybí vaše věta"
elif grep -qF "$UUID" "$PRIPOJ/prevzeti.txt" 2>/dev/null; then
  uspech "v prevzeti.txt je UUID souborového systému ze svazku"
else
  chyba "v prevzeti.txt není UUID souborového systému ze svazku"
fi

vypis_souhrn
