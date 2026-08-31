#!/bin/bash
# 2/16 — Oprávnění (chmod, chown). Prostředí: žákova stanice.
# Postaví adresáře oddělení a tabulku požadovaných práv. Práva nenastavuje —
# to je učivo.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

PRAVA="$HOME/netlab/prava"
TABULKA="$PRAVA/tabulka.txt"

ADRESARE=(vedeni sklad ucetni verejne)
SKUPINY=(vedeni sklad ucetni "$(id -gn)")
# Požadovaná práva se u každého žáka liší. Kombinace jsou vybrané tak,
# aby dávaly smysl: sdílené adresáře oddělení, veřejný jen ke čtení.
# Skupina musí na svůj adresář vždycky aspoň dosáhnout — 700 by znamenalo,
# že oddělení nevidí do vlastní složky, což je zadání bez smyslu.
# Jen 770 a 750. S 775 by do složky oddělení viděl celý svět — a přesně
# proti tomu je tiket, kvůli kterému se cvičení dělá.
MOZNE=(770 750)

prava_pro() {  # index adresáře → oktalová práva
  case "$1" in
    3) echo 755 ;;                                   # verejne je vždy veřejný
    *) echo "${MOZNE[$(( $(lab_vyber 2 1 $((170 + $1))) - 1 ))]}" ;;
  esac
}

if [ -f "$TABULKA" ]; then
  echo
  echo "  Prostředí už existuje v $PRAVA — pokračujte, kde jste skončili."
  echo "  Zadání máte v $TABULKA"
  echo
  exit 0
fi

# Skupiny z předchozího cvičení jsou předpokladem — bez nich se práva
# nepřidělí. Neopravujeme to za žáka, jen na to upozorníme.
CHYBI=""
for S in vedeni sklad ucetni; do
  getent group "$S" >/dev/null 2>&1 || CHYBI="$CHYBI $S"
done

echo "  Připravuji adresáře oddělení…"
mkdir -p "$PRAVA"
for A in "${ADRESARE[@]}"; do
  mkdir -p "$PRAVA/$A"
  printf 'Pracovní dokument oddělení %s.\n' "$A" > "$PRAVA/$A/dokument.txt"
done

{
  echo "# Zadání — nastavte na adresářích tato práva a vlastnictví."
  echo "#"
  echo "# Adresář          Vlastník    Skupina     Práva"
  for i in 0 1 2 3; do
    printf '# %-16s %-11s %-11s %s\n' "${ADRESARE[$i]}" "$(id -un)" "${SKUPINY[$i]}" "$(prava_pro $i)"
  done
  cat <<'PRAVIDLA'
#
# Práva jsou v osmičkovém zápisu: vlastník, skupina, ostatní.
# Soubory dokument.txt uvnitř nechte být — mění se práva adresářů.
#
# Do formuláře zapište hodnoty zjištěné na hotovém systému:
# umask       = výchozí maska vašeho účtu (příkaz bez parametrů)
# symbolicky  = práva adresáře verejne tak, jak je vypíše ls -ld (deset znaků)
PRAVIDLA
  echo "umask:"
  echo "symbolicky:"
} > "$TABULKA"

cat <<EOF

  Prostředí je připravené.

    Adresáře oddělení:  $PRAVA
    Zadání a formulář:  $TABULKA
EOF
[ -n "$CHYBI" ] && cat <<EOF

  POZOR: na stanici chybí skupiny:$CHYBI
  Zakládaly se ve cvičení o uživatelích a skupinách. Bez nich se
  vlastnictví nastavit nedá — doplňte je (sudo groupadd JMENO).
EOF
cat <<EOF

  Průběžnou kontrolu spouštějte odsud:

    cd ~/os-lab/2/16-opravneni && ./check.sh --krok 1

EOF
