#!/bin/bash
# 4/04 — LUKS. Prostředí: žákova stanice, ČTVRTÝ labový disk.
#
# Šifrovaný kontejner zakládá ŽÁK, ne tenhle skript — je to celé učivo labu.
# Skript jen připraví prázdný disk, formulář a bod připojení.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/disk-lib.sh"

projekt_pripoj >/dev/null 2>&1 || true

LAB="$HOME/netlab/sejf"
FORMULAR="$LAB/sejf.txt"
PRIPOJ="$LAB/data"
NAZEV="SEJF-$ZAK2"
MAPPER="sejf-$ZAK2"

zkontroluj_disky 4 || exit 1
DISK="$(labovy_disk 4)"
[ -n "$DISK" ] || { echo "  Labový disk se nepodařilo určit."; exit 1; }

mkdir -p "$LAB" "$PRIPOJ"
if [ ! -s "$FORMULAR" ]; then
  cat > "$FORMULAR" <<'FORMULAR_KONEC'
# Šifrovaný svazek — vyplňte hodnoty za dvojtečku.
#
# zarizeni   = disk, na kterém jste sejf založili (např. sdb, bez /dev/)
# verze      = verze formátu LUKS z hlavičky (číslo)
# sifra      = šifra, kterou svazek používá (celý řetězec z hlavičky)
# po_zavreni = co hlásil lsblk -f jako typ na disku, když byl sejf zavřený
zarizeni:
verze:
sifra:
po_zavreni:
FORMULAR_KONEC
fi

# Disk musí být na začátku prázdný — na neprázdném by luksFormat sice taky
# zabral, ale žák by přepsal cizí práci a nepoznal to.
OBSAH="$(lsblk -rno NAME "/dev/$DISK" 2>/dev/null | tail -n +2)"
PODPIS="$(lsblk -dno PTTYPE,FSTYPE "/dev/$DISK" 2>/dev/null | tr -d ' ')"
if [ "$PODPIS" = "crypto_LUKS" ] || [ -b "/dev/mapper/$MAPPER" ]; then
  echo
  echo "  Váš sejf z minula na disku ještě je — nechávám ho být."
  echo "  Otevřete si ho a pokračujte. Chcete začít znovu?  ./reset.sh"
elif [ -n "$OBSAH" ] || [ -n "$PODPIS" ]; then
  echo
  echo "  Na disku /dev/$DISK je zbytek z jiného cvičení:"
  lsblk -o NAME,SIZE,FSTYPE,LABEL "/dev/$DISK" 2>/dev/null | sed 's/^/    /'
  echo
  read -r -p "  Vyčistit ho? [a/N] " ODP
  if [[ "$ODP" =~ ^[aAyY]$ ]]; then
    uvolni_disk "$DISK" || exit 1
    echo "  Hotovo, disk je prázdný."
  else
    echo "  Cvičení potřebuje prázdný disk. Končím."; exit 1
  fi
fi

cat <<EOF

  Připraveno.

    Disk pro sejf:    /dev/$DISK
    Jméno otevřeného: /dev/mapper/$MAPPER
    Formulář:         $FORMULAR
    Kam připojovat:   $PRIPOJ
    Návěští:          $NAZEV

  Heslo k sejfu si zvolíte sami a NIKAM ho neukládáte. Zapamatujte si ho —
  bez něj se k datům nedostane nikdo, ani vyučující.

  Na první tři labové disky dnes nesaháte — leží na nich práce z minula.

  Průběžná kontrola:

    cd ~/os-lab/4-lin/04-luks && ./check.sh --krok 1

EOF
