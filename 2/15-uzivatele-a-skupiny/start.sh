#!/bin/bash
# 2/15 — Uživatelé a skupiny. Prostředí: žákova stanice.
# Nic nevytváří — zakládání účtů je učivo. Připraví jen zadání a formulář.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

UCTY="$HOME/netlab/ucty"
ZADANI="$UCTY/zadani.txt"

# Jména z původních cvičení autora. Každý žák dostane tři z osmi a jiné
# rozdělení do oddělení — sousedovo řešení tedy neprojde.
JMENA=(jnovak jhrabal pkusek smala tsimakova apolaskova pmezek dhlavata)
CELA=("Jan Novák" "Jakub Hrabal" "Petr Kusek" "Simona Malá" \
      "Tereza Šimáková" "Anna Polášková" "Pavel Mezek" "Dana Hlavatá")
ODDELENI=(sklad ucetni vedeni)

VYBER=($(lab_vyber 8 3 151))

if [ -f "$ZADANI" ]; then
  echo
  echo "  Prostředí už existuje v $UCTY — pokračujte, kde jste skončili."
  echo "  Zadání máte v $ZADANI"
  echo
  exit 0
fi

mkdir -p "$UCTY"
{
  echo "# Zadání — účty, které máte na stanici založit."
  echo "#"
  echo "# Uživatel        Celé jméno            Skupina"
  I=1
  for N in "${VYBER[@]}"; do
    SKUP="${ODDELENI[$(( $(lab_vyber 3 1 $((160 + I))) - 1 ))]}"
    printf '# %-15s %-21s %s\n' "${JMENA[$((N-1))]}" "${CELA[$((N-1))]}" "$SKUP"
    I=$((I+1))
  done
  cat <<'PRAVIDLA'
#
# Skupiny založte všechny tři — sklad, ucetni i vedeni — i když do některé
# nikdo z vašeho seznamu nepatří. Navazuje na ně cvičení o oprávněních.
#
# U všech tří účtů navíc nastavte:
#   platnost účtu končí        31. 12. 2027
#   heslo platí nejvýš         90 dnů
#   heslo lze změnit nejdřív   po 5 dnech
#   upozornit na změnu hesla   14 dní předem
#
# Do formuláře níže zapište hodnoty, které si ověříte na hotovém systému.
# uid-prvni   = číselné UID prvního účtu ze seznamu
# skupin      = kolik skupin má váš vlastní účet (sysadmin)
PRAVIDLA
  echo "uid-prvni:"
  echo "skupin:"
} > "$ZADANI"

cat <<EOF

  Prostředí je připravené.

    Zadání a formulář:  $ZADANI

  Účty i skupiny zakládáte sami — je to dnešní učivo.
  Seznam účtů je v souboru, každý žák má jiný.

  Průběžnou kontrolu spouštějte odsud:

    cd ~/os-lab/2/15-uzivatele-a-skupiny && ./check.sh --krok 1

EOF
