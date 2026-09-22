#!/bin/bash
# 4/06 — Souborové systémy a fstab. Prostředí: žákova stanice.
#
# Tohle cvičení NEPRACUJE s labovými disky — pracuje s /etc/fstab a s diskem
# ročníkového projektu, který si žák dnes připojí natrvalo (slib ze 4/00).
# Skript proto na žádný disk nesahá; jen si zazálohuje fstab, aby měl reset
# kam se vrátit.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/disk-lib.sh"

LAB="$HOME/netlab/fstab"
FORMULAR="$LAB/zaznam.txt"
ZALOHA="$LAB/fstab.pred-cvicenim"
PROJ_DOK="$PROJEKT_PRIPOJ/dokumentace"

# Projekt musí být připojený, aby do něj šlo psát milník. Dnes naposled
# ho připojuje prostředí — od konce hodiny si ho připojuje fstab.
projekt_pripoj >/dev/null 2>&1 || true

ZAR="$(blkid -L "$PROJEKT_NAZEV" 2>/dev/null)"
if [ -z "$ZAR" ]; then
  echo
  echo "  Disk ročníkového projektu (návěští $PROJEKT_NAZEV) na stanici nenajdu."
  echo "  Bez něj tohle cvičení nedává smysl — řekněte o tom vyučujícímu."
  echo
  exit 1
fi
UUID="$(lsblk -no UUID "$ZAR" 2>/dev/null | tr -d ' ' | head -1)"

mkdir -p "$LAB"
# Dokumentaci projektu zakládá 4/00; kdo minule chyběl, ji nemá — a nano
# by mu soubor odmítlo uložit až při ukládání.
projekt_pripojen && mkdir -p "$PROJ_DOK"
[ -s "$ZALOHA" ] || sudo cp /etc/fstab "$ZALOHA" 2>/dev/null
sudo chown "$(id -un):$(id -gn)" "$ZALOHA" 2>/dev/null

if [ ! -s "$FORMULAR" ]; then
  cat > "$FORMULAR" <<'FORMULAR_KONEC'
# Trvalé připojení — vyplňte hodnoty za dvojtečku.
#
# identifikator = čím v fstab označujete projektový disk (celý zápis,
#                 například UUID=... nebo LABEL=...)
# volby         = volby připojení, které jste použili (čtvrtý sloupec fstab)
# pass          = šesté pole řádku, tedy pořadí kontroly při startu (číslo)
# typ           = souborový systém na projektovém disku
identifikator:
volby:
pass:
typ:
FORMULAR_KONEC
fi

cat <<EOF

  Připraveno.

    Disk projektu:    $ZAR   (návěští $PROJEKT_NAZEV)
    Jeho UUID:        ${UUID:-nepodařilo se přečíst}
    Kam se připojuje: $PROJEKT_PRIPOJ
    Formulář:         $FORMULAR
    Dokumentace:      $PROJ_DOK
    Záloha fstab:     $ZALOHA

  Dnes si projektový disk připojíte natrvalo a odevzdáte první milník
  projektu — rozvržení disků.

  Průběžná kontrola:

    cd ~/os-lab/4-lin/06-fstab && ./check.sh --krok 1

EOF
