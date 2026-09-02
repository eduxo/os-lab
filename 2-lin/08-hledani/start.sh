#!/bin/bash
# 2/08 — Hledání: find a grep. Prostředí: žákova stanice.
# Postaví kupku záloh, ve které je schovaný jeden klíč. Kde leží a jak zní,
# se odvozuje z čísla žáka.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

HLEDANI="$HOME/netlab/hledani"
NALEZY="$HLEDANI/nalezy.txt"

if [ -d "$HLEDANI" ]; then
  echo
  echo "  Prostředí už existuje v $HLEDANI — pokračujte, kde jste skončili."
  echo "  Chcete začít znovu?  ./reset.sh"
  echo
  exit 0
fi

echo "  Rozbaluji zálohu ze serveru…"
mkdir -p "$HLEDANI"/{zalohy/2025,zalohy/2026,konfigurace,logy,archiv,zalohy/2026/sluzby}

# Konfigurační soubory — jejich počet se liší, aby se počet nedal opsat.
POCET_CONF=$(( 3 + $(lab_vyber 4 1 81) ))
JMENA_CONF=(sit tisk posta zaloha dohled sklad web)
for i in $(seq 1 "$POCET_CONF"); do
  J="${JMENA_CONF[$(( (i - 1) % 7 ))]}"
  case $(( i % 3 )) in
    0) C="$HLEDANI/konfigurace/$J.conf" ;;
    1) C="$HLEDANI/zalohy/2025/$J.conf" ;;
    *) C="$HLEDANI/zalohy/2026/sluzby/$J.conf" ;;
  esac
  printf '# konfigurace sluzby %s\nport = %d\nzapnuto = ano\n' "$J" $(( 8000 + i )) > "$C"
done

# Běžné soubory, mezi kterými se hledá.
printf 'Zápis z porady.\n'        > "$HLEDANI/zalohy/2025/porada.txt"
printf 'Seznam zařízení.\n'       > "$HLEDANI/zalohy/2026/inventar.txt"
printf 'Poznámky správce.\n'      > "$HLEDANI/konfigurace/poznamky.txt"

# Log s chybami — počet řádků ERROR se odvozuje z čísla žáka.
POCET_CHYB=$(( 2 + $(lab_vyber 5 1 82) ))
{
  for i in $(seq 1 20); do
    printf '2026-09-%02d 08:%02d INFO  sluzba bezi\n' $(( i % 28 + 1 )) $(( i % 60 ))
  done
  for i in $(seq 1 "$POCET_CHYB"); do
    printf '2026-09-%02d 09:%02d ERROR spojeni odmitnuto\n' $(( i % 28 + 1 )) $(( i % 60 ))
  done
} > "$HLEDANI/logy/system.log"
printf '2026-09-01 07:00 INFO prihlaseni novak\n' > "$HLEDANI/logy/pristup.log"

# Jeden velký soubor — hledá se podle velikosti, ne podle jména.
{ for i in $(seq 1 3500); do printf 'export radek %05d oddeleni sklad\n' "$i"; done; } \
  > "$HLEDANI/archiv/export-skladu.dat"

# Klíč. Leží v jednom z osmi souborů a jeho hodnota se liší žák od žáka.
# Chrání to proti opsání od souseda, ne proti modelu — tenhle skript je ve
# veřejném repozitáři, takže kdo ho najde, spočítá si klíč i bez hledání.
MOZNOSTI=(
  "zalohy/2025/porada.txt"
  "zalohy/2026/inventar.txt"
  "konfigurace/poznamky.txt"
  "zalohy/2025/predani.txt"
  "zalohy/2026/sluzby/prehled.txt"
  "archiv/protokol.txt"
  "logy/instalace.log"
  "zalohy/2026/smlouva.txt"
)
# Všech osm kandidátů musí existovat a vypadat obyčejně. Kdyby vznikl jen
# ten jeden, prozradil by se stářím i tím, že je v adresáři sám.
for i in "${!MOZNOSTI[@]}"; do
  M="$HLEDANI/${MOZNOSTI[$i]}"
  mkdir -p "$(dirname "$M")"
  [ -f "$M" ] || {
    printf 'Předávací poznámka\n\n'
    printf 'Tenhle soubor si nechal předchozí správce.\n'
    for r in $(seq 1 $(( 1 + i % 4 ))); do
      printf 'Poznámka %d: nic zvláštního.\n' "$r"
    done
  } > "$M"
done

CIL="${MOZNOSTI[$(( $(lab_vyber 8 1 83) - 1 ))]}"
KLIC="$(lab_kod KLIC 8)"
printf 'Servisní klíč: %s\n' "$KLIC" >> "$HLEDANI/$CIL"

cat > "$NALEZY" <<'FORMULAR'
# Nálezy — vyplňte hodnoty za dvojtečku.
# cesty pište tak, jak je vypsal find, tedy od tečky: ./logy/system.log
konfiguraci:
velky-soubor:
klic:
klic-soubor:
klic-radek:
chyby:
FORMULAR

cat <<EOF

  Prostředí je připravené.

    Rozbalená záloha:  $HLEDANI
    Formulář nálezů:   $NALEZY

  Přepněte se do adresáře:

    cd ~/netlab/hledani

  Průběžnou kontrolu spouštějte odsud:

    cd ~/os-lab/2/08-hledani && ./check.sh --krok 1

EOF
