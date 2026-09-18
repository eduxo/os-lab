#!/bin/bash
# 4/01 — Disky a oddíly. Prostředí: žákova stanice, labové disky.
#
# Skript disk NEDĚLÍ — to je učivo. Jen vybere, na kterém se bude pracovat,
# a postará se, aby byl na začátku prázdný.
#
# Proč se na neprázdný disk PTÁ místo tichého smazání: pravidlo o nezávislosti
# labů říká, že start.sh postaví výchozí stav. U kontejneru to nikoho nebolí,
# u disku by tiché smazání sebralo práci, kterou tam žák může mít rozdělanou
# z minulé hodiny. Zeptat se stojí jednu klávesu.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/disk-lib.sh"

# Projekt musí být připojený v KAŽDÉ hodině, ne jen v té, ve které vznikl.
# Trvalý zápis do fstab je učivo cvičení 4/06; do té doby ho připojuje
# prostředí. Bez toho by ~/projekt byl po restartu prázdný adresář na
# systémovém disku a žák by do něj ukládal maturitní práci naslepo.
projekt_pripoj >/dev/null 2>&1 || true

LAB="$HOME/netlab/disky"
FORMULAR="$LAB/rozvrzeni.txt"
NAZEV="DATA-$ZAK2"                                  # návěští souborového systému
PRIPOJ="$HOME/netlab/disky/data"
# Velikost je v MiB, ne v MB. Důvod: parted se zadává v MiB, oddíl pak sedne
# na hranici zarovnání (jinak varuje) a kontrola měří v týchž jednotkách.
# Porovnávat MiB s MB znamená 4,6 % rozdíl — tolerance 20 by neprošla nikdy.
VELIKOST=$(( 400 + 50 * $(lab_vyber 9 1 410) ))     # MiB prvního oddílu: 450–850
KONEC=$(( VELIKOST + 1 ))                           # oddíl začíná na 1MiB

zkontroluj_disky 1 || exit 1
DISK="${LABOVE_DISKY[0]}"

mkdir -p "$LAB" "$PRIPOJ"

if [ ! -s "$FORMULAR" ]; then
  cat > "$FORMULAR" <<FORMULAR_KONEC
# Rozvržení disku — vyplňte hodnoty za dvojtečku.
#
# disk      = jméno zařízení labového disku (např. sdb), bez /dev/
# tabulka   = typ tabulky oddílů, kterou jste na disk zapsali
# oddilu    = kolik oddílů jste na disku vytvořili
# navesti   = návěští (label) souborového systému na prvním oddílu
# pripojeno = absolutní cesta, kam je první oddíl připojený
disk:
tabulka:
oddilu:
navesti:
pripojeno:
FORMULAR_KONEC
fi

# Je disk prázdný? Neprázdný = má oddíly, tabulku nebo podpis souborového systému.
# Čte se bez sudo: lsblk sám vidí i tabulku a souborový systém, takže se
# skript při každém spuštění zbytečně neptá na heslo.
OBSAH="$(lsblk -rno NAME "/dev/$DISK" 2>/dev/null | tail -n +2)"
PODPIS="$(lsblk -dno PTTYPE,FSTYPE "/dev/$DISK" 2>/dev/null | tr -d ' ')"
if [ -n "$OBSAH" ] || [ -n "$PODPIS" ]; then
  # Rozdělaná práce z téhle hodiny se pozná podle návěští a nechá se být.
  if [ -n "$(blkid -L "$NAZEV" 2>/dev/null)" ]; then
    echo
    echo "  Na /dev/$DISK už je vaše práce z minule ($NAZEV) — nechávám ji být."
    echo "  Chcete začít znovu?  ./reset.sh"
  else
    echo
    echo "  Labový disk /dev/$DISK není prázdný — je na něm zbytek z jiného cvičení:"
    lsblk -o NAME,SIZE,FSTYPE,LABEL "/dev/$DISK" 2>/dev/null | sed 's/^/    /'
    echo
    echo "  Dnešní cvičení začíná na prázdném disku."
    read -r -p "  Vyčistit /dev/$DISK? [a/N] " ODP
    if [[ "$ODP" =~ ^[aAyY]$ ]]; then
      uvolni_disk "$DISK" && echo "  Hotovo, /dev/$DISK je prázdný." \
        || { echo "  Disk se nepodařilo uvolnit — řekněte o tom vyučujícímu."; exit 1; }
    else
      echo "  Nechávám ho být. Cvičení ale potřebuje prázdný disk."
      exit 1
    fi
  fi
fi

cat <<EOF

  Připraveno.

    Váš labový disk:  /dev/$DISK
    Formulář:         $FORMULAR
    Kam připojovat:   $PRIPOJ

    První oddíl má mít velikost:  $VELIKOST MiB
    (v příkazu parted tedy:        1MiB  až  ${KONEC}MiB)
    Návěští souborového systému:  $NAZEV

EOF
# Vypsat i ostatní disky, ať je vidět rozdíl mezi „smí" a „nesmí".
echo "  Pro pořádek, co na téhle stanici je:"
printf '    %-8s %-8s %s\n' "ZAŘÍZENÍ" "VELIKOST" "K ČEMU"
SYS="$(systemovy_disk)"; PRO="$(projektovy_disk)"
while read -r jm vel _; do
  case "$jm" in
    "$SYS") k="systém — NESAHAT" ;;
    "$PRO") k="ročníkový projekt — NESAHAT" ;;
    *)      k="labový disk" ;;
  esac
  printf '    %-8s %-8s %s\n' "$jm" "$vel" "$k"
done < <(lsblk -dn -o NAME,SIZE,TYPE 2>/dev/null | awk '$3=="disk" && $1 !~ /^loop/')
cat <<EOF

  Průběžná kontrola:

    cd ~/os-lab/4-lin/01-disky-a-oddily && ./check.sh --krok 1

EOF
