#!/bin/bash
# 4/06 — ověření. Části odpovídají krokům zadání 1:1.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/disk-lib.sh"

LAB="$HOME/netlab/fstab"
FORMULAR="$LAB/zaznam.txt"
PROJ_DOK="$PROJEKT_PRIPOJ/dokumentace"
MILNIK="$PROJ_DOK/rozvrzeni-disku.md"
RAZITKO="$LAB/.proslo-startem"

ZAR="$(blkid -L "$PROJEKT_NAZEV" 2>/dev/null)"
UUID="$(lsblk -no UUID "${ZAR:-/nic}" 2>/dev/null | tr -d ' ' | head -1)"

# Řádek fstab pro projektový disk. Hledá se podle bodu připojení, ne podle
# zařízení — právě to, čím je zařízení označené, je dnešní učivo.
RADEK="$(grep -vE '^[[:space:]]*(#|$)' /etc/fstab 2>/dev/null \
  | awk -v c="$PROJEKT_PRIPOJ" '$2==c {print; exit}')"

krok 1 "Co je na stanici připojené"
require_soubor_neprazdny "$FORMULAR" \
  "formulář zaznam.txt je na místě" \
  "chybí ~/netlab/fstab/zaznam.txt — spusťte ./start.sh"
if [ -n "$ZAR" ]; then
  uspech "disk ročníkového projektu je na stanici ($ZAR)"
else
  chyba "disk ročníkového projektu nenajdu"
fi
TYP="$(lsblk -no FSTYPE "${ZAR:-/nic}" 2>/dev/null | tr -d ' ' | head -1)"
if [ -n "$TYP" ]; then
  require_zaznam "$FORMULAR" typ "$TYP" "ve formuláři je souborový systém projektového disku"
else
  chyba "souborový systém projektového disku se nepodařilo přečíst"
fi

krok 2 "Trvalý záznam ve fstab"
if [ -z "$RADEK" ]; then
  chyba "v /etc/fstab není řádek, který by připojoval $PROJEKT_PRIPOJ"
  poznamka "co tam je, ukáže: grep -v '^#' /etc/fstab"
else
  uspech "v /etc/fstab je řádek pro $PROJEKT_PRIPOJ"
  ZDROJ_F="$(printf '%s' "$RADEK" | awk '{print $1}')"
  # Jádro celého cvičení: jméno /dev/sdX se mezi starty posouvá. Záznam,
  # který na něm stojí, jednou připojí cizí disk — nebo nepřipojí nic.
  case "$ZDROJ_F" in
    UUID=*)  [ -n "$UUID" ] && [ "$ZDROJ_F" = "UUID=$UUID" ] \
               && uspech "disk je označený svým UUID" \
               || chyba "UUID v záznamu neodpovídá projektovému disku" ;;
    LABEL=*) [ "$ZDROJ_F" = "LABEL=$PROJEKT_NAZEV" ] \
               && uspech "disk je označený svým návěštím" \
               || chyba "návěští v záznamu neodpovídá projektovému disku" ;;
    /dev/*)  chyba "záznam stojí na jméně zařízení, které se může změnit" ;;
    *)       chyba "první pole záznamu nepoznávám" ;;
  esac
  VOLBY="$(printf '%s' "$RADEK" | awk '{print $4}')"
  case ",$VOLBY," in
    *,nofail,*) uspech "záznam má volbu, která nezablokuje start stanice" ;;
    *)          chyba "záznam nemá volbu, která by ochránila start stanice" ;;
  esac
  PASS="$(printf '%s' "$RADEK" | awk '{print $6}')"
  # Vynechané šesté pole znamená implicitní 0 — je to platný zápis,
  # jen zadání chce všech šest polí vypsaných.
  case "${PASS:-0}" in
    0) uspech "kontrola při startu je u tohohle disku vypnutá (pass 0)" ;;
    *) chyba "šesté pole je '$PASS'; u disku, který nemusí být vždy připojený, patří 0" ;;
  esac
fi
require_zaznam_tvar "$FORMULAR" identifikator '^(UUID|LABEL)=.+' \
  "ve formuláři je identifikátor disku" \
  "ve formuláři chybí identifikátor tak, jak je zapsaný ve fstab"
require_zaznam_tvar "$FORMULAR" volby '.{3,}' \
  "ve formuláři jsou volby připojení" \
  "ve formuláři chybí volby připojení"
require_zaznam "$FORMULAR" pass "0" "ve formuláři je pořadí kontroly"

krok 3 "Připojeno a ověřeno bez restartu"
# Projekt připojuje i start.sh, takže „je připojený" samo o sobě není
# důkaz ničeho. Ptáme se, jestli ho připojuje ZÁZNAM VE FSTAB — tedy to,
# co je dnešní učivo.
Z_FSTAB="$(findmnt --fstab -no SOURCE "$PROJEKT_PRIPOJ" 2>/dev/null | head -1)"
CIL="$(findmnt -no SOURCE "$PROJEKT_PRIPOJ" 2>/dev/null | head -1)"
if [ -z "$Z_FSTAB" ]; then
  chyba "připojení $PROJEKT_PRIPOJ zatím není zapsané ve /etc/fstab"
elif [ -n "$ZAR" ] && [ "$CIL" = "$ZAR" ]; then
  uspech "projekt je připojený z $ZAR a je to zapsané natrvalo"
else
  chyba "v $PROJEKT_PRIPOJ není připojený projektový disk"
fi
# findmnt --verify čte fstab a řekne, co by se při startu nepovedlo —
# je to jediný způsob, jak si chybu najít DŘÍV, než kvůli ní stanice
# nenaběhne. Vrací nenulový kód i u pouhých varování, proto se ptáme
# na slovo „error" ve výstupu.
VYSTUP="$(sudo -n findmnt --verify 2>&1 || findmnt --verify 2>&1)"
if printf '%s' "$VYSTUP" | grep -qF '[E]'; then
  chyba "findmnt --verify hlásí v /etc/fstab chybu"
  poznamka "spusťte: findmnt --verify"
else
  uspech "findmnt --verify na /etc/fstab nic nenamítá"
fi

krok 4 "Restart a milník projektu"
# Doklad, že stanice od úpravy fstab opravdu nastartovala: čas startu
# systému musí být novější než čas poslední změny fstab. Jinak by šlo
# „ověřit trvalost" bez jediného restartu.
FSTAB_CAS="$(stat -c %Y /etc/fstab 2>/dev/null)"
# Bez parsování textu: čas teď minus doba běhu. `date -d "$(uptime -s)"`
# spoléhá na volný textový vstup, který rust-coreutils zaručený nemá.
BOOT_CAS=$(( $(date +%s) - $(cut -d. -f1 /proc/uptime 2>/dev/null || echo 0) ))
if [ -f "$RAZITKO" ]; then
  uspech "stanice od úpravy fstab nastartovala — připojení je opravdu trvalé"
elif [ -n "$FSTAB_CAS" ] && [ -n "$BOOT_CAS" ] && [ "$BOOT_CAS" -gt "$FSTAB_CAS" ]; then
  # Jednou splněno = splněno. Rozšíření zapisuje do fstab další řádky
  # a nesmí tím shodit hotový krok.
  date '+%Y-%m-%d %H:%M' > "$RAZITKO"
  uspech "stanice od úpravy fstab nastartovala — připojení je opravdu trvalé"
else
  chyba "stanice od poslední úpravy fstab ještě nestartovala"
  poznamka "restartujte ji: sudo reboot"
fi
require_soubor_neprazdny "$MILNIK" \
  "milník leží v dokumentaci projektu" \
  "chybí $MILNIK"
require_min_radku "$MILNIK" 10 \
  "rozvržení disků je rozepsané" \
  "rozvržení disků je zatím moc stručné"
# Milník má popisovat TUHLE stanici, ne obecný server — proto se ptáme
# na hodnoty, které jinde než na ní nezjistí.
if [ -n "$UUID" ] && grep -qF "$UUID" "$MILNIK" 2>/dev/null; then
  uspech "v rozvržení je UUID projektového disku"
else
  chyba "v rozvržení chybí UUID projektového disku"
fi
if grep -qE 'raid|RAID|[zZ]rcadl' "$MILNIK" 2>/dev/null \
   && grep -qE 'luks|LUKS|[šŠ]ifr|[sS]ifr' "$MILNIK" 2>/dev/null; then
  uspech "rozvržení zmiňuje pole i šifrovaný svazek"
else
  chyba "v rozvržení chybí některá z vrstev, které jste letos postavili"
fi
# Návěští jsou vaše — v cizím rozvržení by nedávala smysl.
if grep -qF "RAID-$ZAK2" "$MILNIK" 2>/dev/null \
   && grep -qF "SEJF-$ZAK2" "$MILNIK" 2>/dev/null; then
  uspech "v rozvržení jsou návěští vašich svazků"
else
  chyba "v rozvržení chybí návěští svazků, které jste letos vyrobili"
fi

vypis_souhrn
