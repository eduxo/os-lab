#!/bin/bash
# 2/18 — „Proč to nejde otevřít". Prostředí: žákova stanice.
# Postaví adresářovou strukturu se správnými právy a pak do ní zavede tři
# závady. Vlastnictví potřebuje správce, proto se skript sám spustí přes sudo.
set -uo pipefail

# ── režim pod rootem ──────────────────────────────────────────────
# Před načtením knihovny: pod sudo je HOME=/root a knihovna by se ptala
# na číslo žáka podruhé.
if [ "${1:-}" = "--zaved" ]; then
  shift; LAB_KOREN="$1"; shift; LAB_ZALOHY="$1"; shift; LAB_UCET="$1"; shift
  export LAB_KOREN LAB_ZALOHY LAB_UCET
  source "$(dirname "$0")/poruchy.sh"
  if [ -f "$LAB_ZALOHY/zavedeno" ]; then
    echo "  Závady už zavedené jsou. Nejdřív ./stop.sh." >&2; exit 1
  fi
  mkdir -p "$LAB_ZALOHY"
  printf '%s\n' "$@" > "$LAB_ZALOHY/zavedeno"
  chmod 600 "$LAB_ZALOHY/zavedeno"
  rm -f "$LAB_ZALOHY/uklizeno"
  for Z in "$@"; do "zaved_$Z"; done
  exit 0
fi

source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/poruchy.sh"

NALEZY="$LAB_KOREN/nalezy.txt"

if [ -f "$NALEZY" ]; then
  echo
  echo "  Prostředí už existuje v $LAB_KOREN — pokračujte, kde jste skončili."
  echo "  Chcete zavést závady znovu?  ./reset.sh"
  echo
  exit 0
fi

CHYBI=""
for S in vedeni sklad ucetni; do
  getent group "$S" >/dev/null 2>&1 || CHYBI="$CHYBI $S"
done
if [ -n "$CHYBI" ]; then
  echo
  echo "  Na stanici chybí skupiny:$CHYBI"
  echo "  Zakládaly se ve cvičení o uživatelích a skupinách a tohle cvičení"
  echo "  na nich stojí. Doplňte je (sudo groupadd JMENO) a spusťte znovu."
  echo
  exit 1
fi

echo "  Stavím strukturu oddělení…"
mkdir -p "$LAB_KOREN"/{sklad,ucetni,vedeni,verejne,tym,odkladiste}
printf 'Ceník platný od ledna.\n'    > "$LAB_KOREN/sklad/cenik.txt"
printf 'Faktury za listopad.\n'      > "$LAB_KOREN/ucetni/faktury.txt"
printf 'Zápis z porady.\n'           > "$LAB_KOREN/vedeni/porada.txt"
printf 'Oznámení pro všechny.\n'     > "$LAB_KOREN/verejne/oznameni.txt"
printf 'Podklad projektu.\n'         > "$LAB_KOREN/tym/podklad.txt"

# Správný výchozí stav — tenhle stav má žák obnovit.
chmod 644 "$LAB_KOREN"/*/*.txt
chmod 750 "$LAB_KOREN/sklad" "$LAB_KOREN/ucetni" "$LAB_KOREN/vedeni"
chmod 755 "$LAB_KOREN/verejne"
chmod 644 "$LAB_KOREN/verejne/oznameni.txt"
chmod 2770 "$LAB_KOREN/tym"
chmod 1777 "$LAB_KOREN/odkladiste"

cat <<'EOF'

  ┌────────────────────────────────────────────────────────────────┐
  │  Do struktury oddělení se teď zavedou tři závady v právech.    │
  │  Je to schválně — vaším úkolem je je najít a opravit.          │
  │                                                                │
  │  Nic mimo ~/netlab/porucha se to nedotkne.                     │
  └────────────────────────────────────────────────────────────────┘

  Budete potřebovat heslo — vlastnictví nastavuje správce.

EOF
read -r -p "  Pokračovat? [a/N] " o
case "$o" in
  [aA]|[aA][nN][oO]|[yY]|[yY][eE][sS]) ;;
  *) echo "  Zrušeno. Struktura v $LAB_KOREN zůstává postavená a zdravá,"
     echo "  závady se nezavedly. Spusťte znovu, až budete chtít začít."; echo; exit 0 ;;
esac

sudo chown -R "$(id -un)":"$(id -gn)" "$LAB_KOREN" 2>/dev/null
sudo chgrp sklad  "$LAB_KOREN/sklad"  2>/dev/null
sudo chgrp ucetni "$LAB_KOREN/ucetni" 2>/dev/null
sudo chgrp vedeni "$LAB_KOREN/vedeni" "$LAB_KOREN/tym" 2>/dev/null

VYBER=($(lab18_vyber))
echo "  Zavádím závady…"
sudo bash "$0" --zaved "$LAB_KOREN" "$LAB_ZALOHY" "$(id -un)" "${VYBER[@]}" || {
  echo "  Zavedení závad selhalo — řekněte o tom vyučujícímu."; exit 1; }

cat > "$NALEZY" <<'FORMULAR'
# Nálezy — ke každé závadě jeden řádek, vlastními slovy.
# Co bylo špatně a jak jste na to přišli. Ne jak jste to opravili.
zavada-1:
zavada-2:
zavada-3:
FORMULAR

cat <<EOF

  Prostředí je připravené — tedy rozbité.

    Struktura oddělení:  $LAB_KOREN
    Formulář nálezů:     $NALEZY

  Závady jsou tři a každá je z jiné oblasti.

  Průběžnou kontrolu spouštějte odsud:

    cd ~/os-lab/2/18-proc-to-nejde-otevrit && ./check.sh --krok 1

EOF
