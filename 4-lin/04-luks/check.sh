#!/bin/bash
# 4/04 — ověření. Části odpovídají krokům zadání 1:1.
#
# Heslo se nikde neověřuje a ověřovat nejde — skript ho nezná a znát nesmí.
# Důkazem, že ho žák zná, je otevřený svazek: bez hesla se neotevře.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/disk-lib.sh"

LAB="$HOME/netlab/sejf"
FORMULAR="$LAB/sejf.txt"
PRIPOJ="$LAB/data"
NAZEV="SEJF-$ZAK2"
MAPPER="sejf-$ZAK2"

zkontroluj_disky 4 || exit 1
DISK="$(labovy_disk 4)"
[ -n "$DISK" ] || { echo "  Labový disk se nepodařilo určit."; exit 1; }

_dump=""; _dump_nactena=0
dump() {
  if [ "$_dump_nactena" -eq 0 ]; then
    _dump="$(sudo -n cryptsetup luksDump "/dev/$DISK" 2>/dev/null \
      || sudo cryptsetup luksDump "/dev/$DISK" 2>/dev/null)"
    _dump_nactena=1
  fi
  printf '%s' "$_dump"
}

krok 1 "Šifrovaný kontejner"
require_soubor_neprazdny "$FORMULAR" \
  "formulář sejf.txt je na místě" \
  "chybí ~/netlab/sejf/sejf.txt — spusťte ./start.sh"
TYP="$(lsblk -dno FSTYPE "/dev/$DISK" 2>/dev/null | tr -d ' ')"
if [ "$TYP" = "crypto_LUKS" ]; then
  uspech "na /dev/$DISK je šifrovaný kontejner LUKS"
else
  chyba "na /dev/$DISK zatím žádný šifrovaný kontejner není"
  poznamka "co na disku je, ukáže: lsblk -f /dev/$DISK"
fi
require_zaznam "$FORMULAR" zarizeni "$DISK" "ve formuláři je jméno disku"

krok 2 "Otevřený svazek a souborový systém"
if [ -b "/dev/mapper/$MAPPER" ]; then
  uspech "svazek je otevřený jako /dev/mapper/$MAPPER"
  FS="$(lsblk -no FSTYPE "/dev/mapper/$MAPPER" 2>/dev/null | tr -d ' ' | head -1)"
  LBL="$(lsblk -no LABEL "/dev/mapper/$MAPPER" 2>/dev/null | sed 's/ *$//' | head -1)"
  [ "$FS" = "ext4" ] \
    && uspech "ve svazku je souborový systém ext4" \
    || chyba "ve svazku je '${FS:-nic}', zadání chce ext4"
  [ "$LBL" = "$NAZEV" ] \
    && uspech "souborový systém má návěští $NAZEV" \
    || chyba "návěští je '${LBL:-žádné}', má být $NAZEV"
else
  chyba "svazek není otevřený — /dev/mapper/$MAPPER neexistuje"
  poznamka "otevírá se: sudo cryptsetup open /dev/$DISK $MAPPER"
fi

krok 3 "Připojení a doklad"
CIL="$(findmnt -no TARGET "/dev/mapper/$MAPPER" 2>/dev/null | head -1)"
if [ "$CIL" = "$PRIPOJ" ]; then
  uspech "svazek je připojený v $PRIPOJ"
elif [ -n "$CIL" ]; then
  chyba "svazek je připojený v $CIL, zadání chce $PRIPOJ"
else
  chyba "svazek není nikam připojený"
fi
UUID="$(lsblk -no UUID "/dev/mapper/$MAPPER" 2>/dev/null | tr -d ' ' | head -1)"
if [ -z "$UUID" ]; then
  chyba "souborový systém ve svazku zatím nemá UUID"
elif [ ! -s "$PRIPOJ/prevzeti.txt" ]; then
  chyba "ve svazku chybí prevzeti.txt"
elif ! grep -vF "$UUID" "$PRIPOJ/prevzeti.txt" 2>/dev/null | grep -qE '.{20,}'; then
  chyba "v prevzeti.txt je jen UUID — chybí vaše věta"
elif grep -qF "$UUID" "$PRIPOJ/prevzeti.txt" 2>/dev/null; then
  uspech "v prevzeti.txt je UUID souborového systému ze sejfu"
else
  chyba "v prevzeti.txt není UUID souborového systému ze sejfu"
fi

krok 4 "Co je v hlavičce"
# Hodnoty se berou z hlavičky, ne z literálu — kdyby žák zvolil jinou šifru,
# má mít ve formuláři tu svoji.
VERZE="$(printf '%s' "$(dump)" | awk -F': *' '/^Version/{print $2; exit}' | tr -d '[:space:]')"
SIFRA="$(printf '%s' "$(dump)" | awk -F': *' '/cipher:/{print $2; exit}' | tr -d '[:space:]')"
if [ -z "$VERZE" ]; then
  chyba "hlavičku LUKS se nepodařilo přečíst — je na disku sejf?"
else
  require_zaznam "$FORMULAR" verze "$VERZE" "ve formuláři je verze formátu LUKS"
fi
if [ -z "$SIFRA" ]; then
  chyba "šifru se z hlavičky nepodařilo přečíst"
else
  require_zaznam "$FORMULAR" sifra "$SIFRA" "ve formuláři je použitá šifra"
fi
require_zaznam_tvar "$FORMULAR" po_zavreni '^[Cc]rypto_[Ll][Uu][Kk][Ss]$' \
  "ve formuláři je, co po zavření zbylo na disku" \
  "ve formuláři není, co lsblk hlásil po zavření sejfu"

krok 5 "Druhý klíč"
# Sekce Keyslots končí tam, kde začíná další nadpis na začátku řádku
# (Tokens:, Digests:). Bez té podmínky by se počítaly i jejich položky —
# mají stejný tvar „  0: pbkdf2" a každý sejf by hlásil dva sloty.
SLOTU="$(printf '%s' "$(dump)" | awk '
  /^Keyslots:/ { k=1; next }
  k && /^[^[:space:]]/ { k=0 }
  k && /^[[:space:]]+[0-9]+:/ && $0 !~ /unbound/ { n++ }
  END { print n+0 }')"
if [ "${SLOTU:-0}" -ge 2 ]; then
  uspech "v hlavičce jsou obsazené dva klíčové sloty"
elif [ "${SLOTU:-0}" = "1" ]; then
  chyba "v hlavičce je obsazený jen jeden klíčový slot"
  poznamka "druhý klíč přidá: sudo cryptsetup luksAddKey /dev/$DISK"
else
  chyba "klíčové sloty se nepodařilo přečíst"
fi

vypis_souhrn
