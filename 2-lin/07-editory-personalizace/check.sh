#!/bin/bash
# 2/07 — ověření
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

EDITOR_DIR="$HOME/netlab/editor"
POSTUP="$EDITOR_DIR/postup.txt"
HLASENI="$EDITOR_DIR/hlaseni.txt"

krok 1 "Prostředí"
require_path "$EDITOR_DIR" \
  "adresář ~/netlab/editor existuje" \
  "chybí ~/netlab/editor — spusťte ./start.sh"
require_prikaz nano "editor nano je na stanici k dispozici"
# vim se doinstalovat nedá — apt je učivem až ve cvičení 11. Když na obrazu
# chybí, je to vada šablony VM, ne žáka: nehodnotíme, jen upozorníme.
if command -v vim >/dev/null 2>&1; then
  uspech "editor vim je na stanici k dispozici"
else
  poznamka "${_M}pozor:${_0} vim na téhle stanici není — Krok 2 udělejte v nano"
  poznamka "     a řekněte o tom vyučujícímu, patří do obrazu"
fi

krok 2 "Srovnaný postup"
require_soubor_neprazdny "$POSTUP" \
  "soubor postup.txt existuje" \
  "chybí ~/netlab/editor/postup.txt — spusťte ./start.sh"

# Čte se jen číslo na začátku řádku; komentáře a prázdné řádky se přeskočí.
CISLA="$(grep -oE '^[0-9]+\.' "$POSTUP" 2>/dev/null | tr -d '.' | tr '\n' ' ')"
if [ "$CISLA" = "1 2 3 4 5 6 " ]; then
  uspech "postup je srovnaný od prvního kroku k šestému"
elif [ -z "$CISLA" ]; then
  chyba "v postup.txt nejsou očíslované kroky — nemažte je"
else
  chyba "kroky zatím nejsou ve správném pořadí (máte $CISLA)"
  poznamka "všech šest kroků musí zůstat, jen se přeskládají"
fi

require_zaznam_tvar "$HLASENI" editor '^(nano|vim)$' \
  "v hlaseni.txt je uvedený editor, kterým jste postup srovnali"

krok 3 "Personalizace"
# Uvítací hláška: musí obsahovat jméno téhle stanice, ne cizí.
require_soubor_obsahuje /etc/motd "stanice-$ZAK2" \
  "v /etc/motd je uvítací hláška se jménem vaší stanice" \
  "v /etc/motd chybí jméno vaší stanice (stanice-$ZAK2)"
require_soubor_obsahuje /etc/motd "novak$ZAK2" \
  "v /etc/motd je uvedený správce stanice" \
  "v /etc/motd chybí, kdo stanici spravuje (novak$ZAK2)"

# Výzva shellu. Hledáme přiřazení do PS1 s vlastním jménem — barvy ani
# přesná podoba nás nezajímají, ta je věcí vkusu.
if grep -qE "^[[:space:]]*PS1=.*novak$ZAK2" "$HOME/.bashrc" 2>/dev/null; then
  uspech "v ~/.bashrc je vlastní výzva shellu se jménem novak$ZAK2"
else
  chyba "v ~/.bashrc není výzva shellu s vaším jménem"
  poznamka "řádek musí začínat PS1= a obsahovat novak$ZAK2"
fi

# Negativní kontrola: rozbitý .bashrc se pozná až při dalším přihlášení,
# a to už u toho vyučující nesedí.
if [ ! -f "$HOME/.bashrc" ]; then
  chyba "~/.bashrc vůbec neexistuje — to je nezvyklé, řekněte o tom vyučujícímu"
elif bash -n "$HOME/.bashrc" 2>/dev/null; then
  uspech "~/.bashrc je syntakticky v pořádku"
else
  chyba "~/.bashrc má syntaktickou chybu — příští terminál se nemusí otevřít"
  poznamka "opravte ho hned, dokud máte otevřené funkční okno"
fi

vypis_souhrn
