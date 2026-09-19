#!/bin/bash
# 4/05 — LVM nad šifrovaným svazkem. Prostředí: žákova stanice, ČTVRTÝ labový
# disk — tentýž kontejner LUKS, který vznikl ve cvičení 4/04.
#
# Kontejner skript NEZAKLÁDÁ a otevřít ho neumí: heslo zná jen žák a do
# repozitáře nepatří. Když sejf na disku není (žák minule chyběl), skript
# to řekne a žák si ho založí sám — je to jeden příkaz z minulé hodiny.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/disk-lib.sh"

projekt_pripoj >/dev/null 2>&1 || true

LAB="$HOME/netlab/lvm"
FORMULAR="$LAB/svazky.txt"
PRIPOJ="$LAB/data"
SKUPINA="data-$ZAK2"
SVAZEK="archiv"
NAZEV="ARCHIV-$ZAK2"
MAPPER="sejf-$ZAK2"

zkontroluj_disky 4 || exit 1
DISK="$(labovy_disk 4)"
[ -n "$DISK" ] || { echo "  Labový disk se nepodařilo určit."; exit 1; }

mkdir -p "$LAB" "$PRIPOJ"
if [ ! -s "$FORMULAR" ]; then
  cat > "$FORMULAR" <<'FORMULAR_KONEC'
# Logické svazky — vyplňte hodnoty za dvojtečku.
#
# fyzicky   = zařízení, ze kterého jste udělali fyzický svazek (celá cesta)
# skupina   = jméno skupiny svazků
# svazek    = jméno logického svazku
# pred      = kolik místa hlásil df PŘED rozšířením (i s jednotkou)
# po        = kolik místa hlásil df PO rozšíření (i s jednotkou)
fyzicky:
skupina:
svazek:
pred:
po:
FORMULAR_KONEC
fi

TYP="$(lsblk -dno FSTYPE "/dev/$DISK" 2>/dev/null | tr -d ' ')"

echo
if [ "$TYP" = "crypto_LUKS" ]; then
  echo "  Váš sejf z minulé hodiny je na /dev/$DISK."
  if [ -b "/dev/mapper/$MAPPER" ]; then
    echo "  A je i otevřený — můžete rovnou pokračovat."
  else
    echo "  Otevřete si ho:  sudo cryptsetup open /dev/$DISK $MAPPER"
  fi
else
  echo "  Na /dev/$DISK žádný sejf není — heslo k němu znáte jen vy, takže"
  echo "  ho za vás nezaložím. Než budete pokračovat, udělejte to jako minule:"
  echo
  echo "    sudo cryptsetup luksFormat /dev/$DISK"
  echo "    sudo cryptsetup open /dev/$DISK $MAPPER"
  echo
fi

cat <<EOF
  Připraveno.

    Disk se sejfem:   /dev/$DISK
    Otevřený svazek:  /dev/mapper/$MAPPER
    Skupina svazků:   $SKUPINA
    Logický svazek:   $SVAZEK
    Formulář:         $FORMULAR
    Kam připojovat:   $PRIPOJ
    Návěští:          $NAZEV

  Na první tři labové disky dnes nesaháte.

  Průběžná kontrola:

    cd ~/os-lab/4-lin/05-lvm && ./check.sh --krok 1

EOF
