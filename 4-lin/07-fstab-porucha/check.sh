#!/bin/bash
# 4/07 — ověření. Části odpovídají krokům zadání 1:1.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/disk-lib.sh"

LAB="$HOME/netlab/emergency"
FORMULAR="$LAB/hlaseni.txt"
ZNACKA="$LAB/.zavada"

ZAR="$(blkid -L "$PROJEKT_NAZEV" 2>/dev/null)"
UUID="$(lsblk -no UUID "${ZAR:-/nic}" 2>/dev/null | tr -d ' ' | head -1)"
TYP="$(lsblk -no FSTYPE "${ZAR:-/nic}" 2>/dev/null | tr -d ' ' | head -1)"

# Které pole bylo rozbité — týž výpočet jako ve start.sh.
# Mapování scénář → vadné pole. Musí sedět se start.sh: 1 = zařízení,
# 2 = volby (čtvrté pole), 3 = typ souborového systému.
case "$(lab_cislo 1 3 fstab-porucha)" in
  1) POLE=1 ;; 2) POLE=4 ;; *) POLE=3 ;;
esac
RAZITKO="$LAB/.proslo-startem"

RADEK="$(grep -vE '^[[:space:]]*(#|$)' /etc/fstab 2>/dev/null \
  | awk -v c="$PROJEKT_PRIPOJ" '$2==c {print; exit}')"

krok 1 "Diagnóza a oprava"
# Bez tohohle by žák, který start.sh nikdy nespustil, prošel skoro celou
# částí: fstab má v pořádku ze cvičení 6 a stanice mezitím startovala.
if [ ! -f "$ZNACKA" ]; then
  chyba "dnešní závada nebyla na téhle stanici nikdy nasazená"
  poznamka "spusťte ./start.sh"
fi
require_soubor_neprazdny "$FORMULAR" \
  "hlášení je na místě" \
  "chybí ~/netlab/emergency/hlaseni.txt — spusťte ./start.sh"
# Hláška nesmí pojmenovat pole ani naznačit, které to je — je to celá úloha.
require_zaznam "$FORMULAR" chyba_v_poli "$POLE" \
  "v hlášení je správně určené vadné pole" \
  "v hlášení nesedí číslo vadného pole"
JEDNOTKA="$(systemd-escape -p --suffix=mount "$PROJEKT_PRIPOJ" 2>/dev/null)"
if [ -n "$JEDNOTKA" ]; then
  require_zaznam_jmeno "$FORMULAR" jednotka "$JEDNOTKA" \
    "v hlášení je jednotka, která selhala" \
    "v hlášení nesedí jméno selhané jednotky"
fi
require_zaznam_tvar "$FORMULAR" projev '^.{30,}$' \
  "v hlášení je popsané, co stanice při startu udělala" \
  "v hlášení chybí popis toho, jak se závada projevila"

# (pokračování části 1 — oprava se pozná až tím, že stanice nastartovala)
if [ -z "$RADEK" ]; then
  chyba "v /etc/fstab není řádek, který by připojoval $PROJEKT_PRIPOJ"
  poznamka "řešením není řádek smazat — projekt se má připojovat sám"
else
  uspech "v /etc/fstab je řádek pro $PROJEKT_PRIPOJ"
  # JEDNA neutrální hláška. Rozepsané verdikty po polích („první pole
  # neukazuje…", „třetí pole neodpovídá…") byly přímo ta odpověď, kterou
  # má žák najít — stačilo pustit check.sh před opravou.
  Z="$(printf '%s' "$RADEK" | awk '{print $1}')"
  T="$(printf '%s' "$RADEK" | awk '{print $3}')"
  ZAR_OK=0
  case "$Z" in
    UUID=*)  [ -n "$UUID" ] && [ "$Z" = "UUID=$UUID" ] && ZAR_OK=1 ;;
    LABEL=*) [ "$Z" = "LABEL=$PROJEKT_NAZEV" ] && ZAR_OK=1 ;;
  esac
  VOLBY_OK=0
  printf '%s' "$RADEK" | awk '{print $4}' | grep -qE '^[a-zA-Z0-9_,=.-]+$' && VOLBY_OK=1
  if [ "$ZAR_OK" = "1" ] && [ -n "$TYP" ] && [ "$T" = "$TYP" ] && [ "$VOLBY_OK" = "1" ]; then
    uspech "řádek odpovídá projektovému disku"
  else
    chyba "řádek pro $PROJEKT_PRIPOJ zatím neodpovídá projektovému disku"
    poznamka "co na disku doopravdy je, ukáže: blkid, lsblk -f"
  fi
fi
VYSTUP="$(sudo -n findmnt --verify 2>&1 || findmnt --verify 2>&1)"
if printf '%s' "$VYSTUP" | grep -qF '[E]'; then
  chyba "findmnt --verify hlásí v /etc/fstab chybu"
else
  uspech "findmnt --verify na /etc/fstab nic nenamítá"
fi
CIL="$(findmnt -no SOURCE "$PROJEKT_PRIPOJ" 2>/dev/null | head -1)"
[ -n "$ZAR" ] && [ "$CIL" = "$ZAR" ] \
  && uspech "projekt je připojený z $ZAR" \
  || chyba "v $PROJEKT_PRIPOJ není připojený projektový disk"
# Doklad, že oprava prošla skutečným startem, ne jen příkazem mount -a.
FSTAB_CAS="$(stat -c %Y /etc/fstab 2>/dev/null)"
# Bez parsování textu: čas teď minus doba běhu. `date -d "$(uptime -s)"`
# spoléhá na volný textový vstup, který rust-coreutils zaručený nemá.
BOOT_CAS=$(( $(date +%s) - $(cut -d. -f1 /proc/uptime 2>/dev/null || echo 0) ))
if [ -f "$RAZITKO" ]; then
  uspech "stanice po opravě nastartovala"
elif [ -n "$FSTAB_CAS" ] && [ -n "$BOOT_CAS" ] && [ "$BOOT_CAS" -gt "$FSTAB_CAS" ]; then
  # Jednou splněno = splněno. Pozdější úprava fstab (doplnění pojistky
  # v Úkolu 4) už nesmí tuhle část shodit.
  date '+%Y-%m-%d %H:%M' > "$RAZITKO"
  uspech "stanice po opravě nastartovala"
else
  chyba "stanice od poslední úpravy fstab ještě nestartovala"
  poznamka "oprava se považuje za hotovou, až projde startem: sudo reboot"
fi

krok 2 "Aby to příště server nezastavilo"
if [ -n "$RADEK" ]; then
  V="$(printf '%s' "$RADEK" | awk '{print $4}')"
  case ",$V," in
    *,nofail,*) uspech "řádek je doplněný o volbu, která ochrání start stanice" ;;
    *)          chyba "na řádku chybí opatření, které by start stanice ochránilo" ;;
  esac
fi
require_zaznam_tvar "$FORMULAR" prevence 'nofail' \
  "v hlášení je pojmenované opatření" \
  "v hlášení chybí opatření, které tomu příště zabrání"

krok 3 "Hlášení pro vedení"
require_zaznam_tvar "$FORMULAR" postup '^.{40,}$' \
  "v hlášení je popsaný postup opravy" \
  "v hlášení chybí postup, jak jste se k souboru dostali a co jste udělali"

vypis_souhrn
