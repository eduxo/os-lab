#!/bin/bash
# 4/02 — ověření. Části odpovídají krokům zadání 1:1.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/disk-lib.sh"

LAB="$HOME/netlab/raid"
FORMULAR="$LAB/pole.txt"
PRIPOJ="$LAB/data"
NAZEV="RAID-$ZAK2"

zkontroluj_disky 3 || exit 1
DISK_A="${LABOVE_DISKY[1]}"
DISK_B="${LABOVE_DISKY[2]}"

# `mdadm --detail` chce práva správce. Čte se líně a jen jednou.
_det=""; _det_nactena=0
detail() {
  if [ "$_det_nactena" -eq 0 ]; then
    [ -n "$POLE" ] && _det="$(sudo -n mdadm --detail "/dev/$POLE" 2>/dev/null \
      || sudo mdadm --detail "/dev/$POLE" 2>/dev/null)"
    _det_nactena=1
  fi
  printf '%s' "$_det"
}
# Pole se hledá podle toho, že jsou v něm OBA žákovy disky — ne podle jména.
POLE=""
while read -r radek; do
  case " $radek " in
    *" ${DISK_A}["*|*" ${DISK_A} "*)
      case " $radek " in *" ${DISK_B}["*|*" ${DISK_B} "*) POLE="${radek%% *}" ;; esac ;;
  esac
done < <(grep -E '^md[0-9]+ :' /proc/mdstat 2>/dev/null)

krok 1 "Pole existuje"
require_soubor_neprazdny "$FORMULAR" \
  "formulář pole.txt je na místě" \
  "chybí ~/netlab/raid/pole.txt — spusťte ./start.sh"
if [ -n "$POLE" ]; then
  uspech "pole /dev/$POLE je složené z /dev/$DISK_A a /dev/$DISK_B"
else
  chyba "nenašel jsem pole, ve kterém jsou oba vaše disky"
  poznamka "co pole vidí, ukáže: cat /proc/mdstat"
fi
require_zaznam "$FORMULAR" zarizeni "${POLE:-nic}" \
  "ve formuláři je jméno pole"

krok 2 "Úroveň a stav"
UROVEN="$(printf '%s' "$(detail)" | awk -F': *' '/Raid Level/{print $2; exit}' | tr -d ' ')"
case "$UROVEN" in
  raid1) uspech "pole je RAID 1 (zrcadlo)" ;;
  '')    chyba "úroveň pole se nepodařilo přečíst" ;;
  *)     chyba "pole je $UROVEN, zadání chce raid1" ;;
esac
CLENU="$(printf '%s' "$(detail)" | awk -F': *' '/Raid Devices/{print $2; exit}' | tr -d ' ')"
AKTIVNI="$(printf '%s' "$(detail)" | awk -F': *' '/Active Devices/{print $2; exit}' | tr -d ' ')"
if [ "${CLENU:-0}" = "2" ] && [ "${AKTIVNI:-0}" = "2" ]; then
  uspech "v poli jsou dva disky a oba jsou aktivní"
else
  chyba "pole má ${CLENU:-?} členů, aktivních ${AKTIVNI:-?} — mají být dva a dva"
fi
# Dokud se zrcadlo dosynchronizovává, pole funguje, ale ještě nechrání.
if grep -qE 'resync|recovery' /proc/mdstat 2>/dev/null; then
  chyba "pole se ještě synchronizuje — počkejte, než doběhne"
  poznamka "průběh ukáže: cat /proc/mdstat"
else
  uspech "synchronizace je hotová"
fi
require_zaznam "$FORMULAR" uroven "1" "ve formuláři je úroveň RAIDu"
require_zaznam "$FORMULAR" clenu "2" "ve formuláři je počet disků v poli"

krok 3 "Souborový systém na poli"
if [ -n "$POLE" ]; then
  FS="$(lsblk -no FSTYPE "/dev/$POLE" 2>/dev/null | tr -d ' ' | head -1)"
  LBL="$(lsblk -no LABEL "/dev/$POLE" 2>/dev/null | sed 's/ *$//' | head -1)"
  [ "$FS" = "ext4" ] \
    && uspech "na poli je souborový systém ext4" \
    || chyba "na poli je '${FS:-nic}', zadání chce ext4"
  [ "$LBL" = "$NAZEV" ] \
    && uspech "souborový systém má návěští $NAZEV" \
    || chyba "návěští je '${LBL:-žádné}', má být $NAZEV"
fi
require_zaznam "$FORMULAR" navesti "$NAZEV" "ve formuláři je návěští"

krok 4 "Připojení a doklad"
CIL="$(findmnt -no TARGET "/dev/${POLE:-nic}" 2>/dev/null | head -1)"
if [ "$CIL" = "$PRIPOJ" ]; then
  uspech "pole je připojené v $PRIPOJ"
elif [ -n "$CIL" ]; then
  chyba "pole je připojené v $CIL, zadání chce $PRIPOJ"
else
  chyba "pole není nikam připojené"
fi
# Kapacita zrcadla je velikost JEDNOHO disku — to je pointa RAIDu 1
# a ptáme se na ni, protože ji žák musí vidět, ne odhadnout.
KAP="$(lsblk -dno SIZE "/dev/${POLE:-nic}" 2>/dev/null | tr -d ' ')"
if [ -n "$KAP" ]; then
  require_zaznam_tvar "$FORMULAR" kapacita "^${KAP//./\\.}$" \
    "ve formuláři je kapacita pole ($KAP)" \
    "ve formuláři nesedí kapacita pole — podívejte se do lsblk"
else
  require_zaznam_tvar "$FORMULAR" kapacita '^[0-9]+([.,][0-9]+)?[MGT]i?$' \
    "ve formuláři je kapacita pole" "ve formuláři chybí kapacita pole"
fi
UUID="$(lsblk -no UUID "/dev/${POLE:-nic}" 2>/dev/null | tr -d ' ' | head -1)"
if [ -z "$UUID" ]; then
  chyba "souborový systém na poli zatím nemá UUID"
elif [ ! -s "$PRIPOJ/prevzeti.txt" ]; then
  chyba "na poli chybí prevzeti.txt"
elif grep -qF "$UUID" "$PRIPOJ/prevzeti.txt" 2>/dev/null; then
  uspech "v prevzeti.txt je UUID souborového systému na poli"
else
  chyba "v prevzeti.txt není UUID souborového systému na poli"
fi

krok 5 "Jméno pole po restartu"
# Bez záznamu v mdadm.conf jádro pole po restartu pojmenuje podle svého
# (typicky md127) a žák by příští hodinu pracoval s jiným zařízením, než má
# v poznámkách. Hledá se UUID pole, ne jméno — to se právě může změnit.
POLE_UUID="$(printf '%s' "$(detail)" | awk -F': *' '/^ *UUID/{print $2; exit}' | tr -d ' ')"
if [ -z "$POLE_UUID" ]; then
  chyba "UUID pole se nepodařilo přečíst — stojí vůbec pole?"
elif sudo -n grep -qF "$POLE_UUID" /etc/mdadm/mdadm.conf 2>/dev/null \
     || sudo grep -qF "$POLE_UUID" /etc/mdadm/mdadm.conf 2>/dev/null; then
  uspech "pole je zapsané v /etc/mdadm/mdadm.conf"
else
  chyba "pole není zapsané v /etc/mdadm/mdadm.conf — po restartu se přejmenuje"
fi

vypis_souhrn
