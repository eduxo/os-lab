#!/bin/bash
# 2/13 — Rozbitá instalace. Prostředí: žákova stanice.
# Zavede tři závady do správy balíčků. Jako jediné cvičení ročníku sahá
# na systémové soubory, takže si je nejdřív zazálohuje.
set -uo pipefail

# ── režim pod rootem: zálohy a zavedení závad ─────────────────────
# Řeší se PŘED načtením lab-lib.sh. Pod sudo je HOME=/root a knihovna by se
# podruhé ptala na číslo žáka — uprostřed „Zavádím závady…", hned po hesle.
# Ve větvi --zaved se číslo žáka k ničemu nepotřebuje, cíl i výběr přijdou
# jako argumenty.
if [ "${1:-}" = "--zaved" ]; then
  source "$(dirname "$0")/poruchy.sh"
  shift; CIL="$1"; shift

  # Podruhé se nezavádí. Bez téhle pojistky by druhý běh uložil jako
  # „původní stav" ty už rozbité soubory a stanice by se neměla čím vrátit.
  if [ -f "$LAB_ZALOHY/zavedeno" ]; then
    echo "  Závady už na téhle stanici zavedené jsou." >&2
    echo "  Nejdřív ukliďte (./stop.sh), teprve pak zavádějte znovu." >&2
    exit 1
  fi

  if [ ! -f "$LAB_ETC_APT/sources.list.d/ubuntu.sources" ]; then
    echo "  Na téhle stanici chybí $LAB_ETC_APT/sources.list.d/ubuntu.sources." >&2
    echo "  Cvičení počítá s Ubuntu 26.04 — řekněte o tom vyučujícímu." >&2
    exit 1
  fi

  mkdir -p "$LAB_ZALOHY"
  cp -a "$LAB_ETC_APT/sources.list.d/ubuntu.sources" "$LAB_ZALOHY/ubuntu.sources"
  cp -a "$LAB_HOSTS" "$LAB_ZALOHY/hosts" 2>/dev/null
  cp -a "$LAB_ETC_APT/sources.list" "$LAB_ZALOHY/sources.list" 2>/dev/null
  apt-mark showhold > "$LAB_ZALOHY/hold" 2>/dev/null
  printf '%s\n' "$CIL" > "$LAB_ZALOHY/cil"
  # Seznam kódů závad i cílový balíček čte jen root — katalog je veřejný
  # a z kódů by se řešení vyčetlo jedním `cat`.
  printf '%s\n' "$@" > "$LAB_ZALOHY/zavedeno"
  chmod 600 "$LAB_ZALOHY/zavedeno" "$LAB_ZALOHY/cil" 2>/dev/null
  rm -f "$LAB_ZALOHY/uklizeno"
  for Z in "$@"; do "zaved_$Z" "$CIL"; done
  exit 0
fi

source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/poruchy.sh"

INST="$HOME/netlab/instalace"
NALEZY="$INST/nalezy.txt"

# Cíl instalace — jiný balíček než ve cvičení 2/11, aby nebyl už nainstalovaný.
VSE=(tree ncdu figlet sl jq htop)
Z11="${VSE[$(( $(lab_vyber 6 1 111) - 1 ))]}"
ZBYTEK=()
for b in "${VSE[@]}"; do [ "$b" = "$Z11" ] || ZBYTEK+=("$b"); done
CIL="${ZBYTEK[$(( $(lab_vyber 5 1 132) - 1 ))]}"

if [ -f "$NALEZY" ]; then
  echo
  echo "  Prostředí už existuje v $INST — pokračujte, kde jste skončili."
  echo "  Balíček k instalaci: $CIL"
  echo "  Chcete zavést závady znovu?  ./reset.sh"
  echo
  exit 0
fi

VYBER=($(lab13_vyber))

cat <<EOF

  ┌────────────────────────────────────────────────────────────────┐
  │  Tohle cvičení rozbije správu balíčků na téhle stanici.        │
  │  Je to schválně — vaším úkolem je ji zprovoznit.               │
  │                                                                │
  │  Skript si nejdřív zazálohuje systémové soubory, kterých se    │
  │  dotkne. Vrátit je umí ./reset.sh i ./stop.sh.                 │
  └────────────────────────────────────────────────────────────────┘

  Budete potřebovat heslo — zavedení závad běží pod správcem.

EOF
read -r -p "  Pokračovat? [a/N] " o
case "$o" in
  [aA]|[aA][nN][oO]|[yY]|[yY][eE][sS]) ;;
  *) echo "  Zrušeno, nic se nezměnilo."; echo; exit 0 ;;
esac

echo "  Zavádím závady…"
sudo bash "$0" --zaved "$CIL" "${VYBER[@]}" || {
  echo "  Zavedení závad selhalo — řekněte o tom vyučujícímu."; exit 1; }

mkdir -p "$INST"
cat > "$NALEZY" <<FORMULAR
# Nálezy — ke každé závadě jeden řádek, vlastními slovy.
# Popište, CO bylo špatně a JAK jste to našli. Ne jak jste to opravili.
# Vyučující se na ně zeptá.
zavada-1:
zavada-2:
zavada-3:
FORMULAR

cat <<EOF

  Prostředí je připravené — tedy rozbité.

    Formulář nálezů:   $NALEZY
    Balíček k instalaci: $CIL

  Vaším úkolem je zprovoznit správu balíčků a ten balíček nainstalovat.
  Závady jsou tři a každá je z jiné oblasti.

  Průběžnou kontrolu spouštějte odsud:

    cd ~/os-lab/2/13-rozbita-instalace && ./check.sh --krok 1

EOF
