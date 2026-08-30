#!/bin/bash
# 2/07 — Textové editory a personalizace. Prostředí: žákova stanice.
# Připraví rozházený postup, který žák v editoru srovná, a formulář.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

EDITOR_DIR="$HOME/netlab/editor"
POSTUP="$EDITOR_DIR/postup.txt"

if [ -d "$EDITOR_DIR" ]; then
  echo
  echo "  Prostředí už existuje v $EDITOR_DIR — pokračujte, kde jste skončili."
  echo "  Chcete začít znovu?  ./reset.sh"
  echo
  exit 0
fi

echo "  Připravuji rozházený postup…"
mkdir -p "$EDITOR_DIR"

# Šest kroků servisního postupu. Do souboru se zapíšou v pořadí, které
# se u každého žáka liší — srovnat je je úkol pro editor, ne pro hlavu.
KROK1="1. Zeptejte se uživatele, co přesně nefunguje a odkdy."
KROK2="2. Ověřte, že je zařízení zapnuté a připojené do sítě."
KROK3="3. Zkuste závadu zopakovat u sebe."
KROK4="4. Podívejte se, jestli tentýž problém nehlásil někdo další."
KROK5="5. Navrhněte řešení a domluvte s uživatelem termín."
KROK6="6. Po opravě si od uživatele nechte potvrdit, že to funguje."

{
  echo "# Servisní postup — kroky se rozsypaly. Srovnejte je do pořadí 1 až 6."
  echo "# Řádek s mřížkou nechte být."
  for i in $(lab_vyber 6 6 71); do
    eval "printf '%s\n' \"\$KROK$i\""
  done
} > "$POSTUP"

cat > "$EDITOR_DIR/hlaseni.txt" <<'FORMULAR'
# Poznámka k personalizaci — vyplňte hodnotu za dvojtečku.
# editor = který editor jste použili na srovnání postupu (nano nebo vim)
editor:
FORMULAR

cat <<EOF

  Prostředí je připravené.

    Rozházený postup:  $POSTUP
    Formulář:          $EDITOR_DIR/hlaseni.txt
    Vaše číslo (XX):   $ZAK2

  Dnes budete upravovat i dva systémové soubory:

    /etc/motd          uvítací hláška při textovém přihlášení
    ~/.bashrc          nastavení vašeho shellu

  Průběžnou kontrolu spouštějte odsud:

    cd ~/os-lab/2/07-editory-personalizace && ./check.sh --krok 1

EOF
