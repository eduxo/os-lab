#!/bin/bash
# 2/19 — ověření
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

ARCH="$HOME/netlab/archiv"
DATA="$ARCH/data"
TAR="$ARCH/zaloha.tar"
TGZ="$ARCH/zaloha.tar.gz"
OBNOVENO="$ARCH/obnoveno"
FORMULAR="$ARCH/prehled.txt"

# Seznam souborů v archivu, bez adresářů a bez vedoucího ./ — aby se dal
# porovnat s tím, co leží na disku.
seznam_v_archivu() {  # seznam_v_archivu archiv [přepínač]
  tar -t${2:-}f "$1" 2>/dev/null | grep '[^/]$' | sed 's|^\./||' | sort
}

krok 1 "Prostředí"
require_path "$DATA" \
  "data k zálohování jsou na místě" \
  "chybí ~/netlab/archiv/data — spusťte ./start.sh"
require_soubor_neprazdny "$FORMULAR" \
  "formulář je na místě" \
  "chybí ~/netlab/archiv/prehled.txt — spusťte ./start.sh"

# Kolik souborů má archiv obsahovat — počítá se ze skutečných dat.
POCET_DAT=$(find "$DATA" -type f 2>/dev/null | grep -c '')

krok 2 "Archiv"
require_soubor_neprazdny "$TAR" \
  "archiv zaloha.tar existuje" \
  "chybí ~/netlab/archiv/zaloha.tar"
if [ -f "$TAR" ]; then
  # Hláška úmyslně bez čísel: počet souborů je jedna z odpovědí do formuláře
  # a průběžná kontrola není nápověda.
  if [ "$(seznam_v_archivu "$TAR" | grep -c '')" -eq "$POCET_DAT" ]; then
    uspech "archiv obsahuje všechna data"
  else
    chyba "archiv neobsahuje všechna data z adresáře data"
    poznamka "zabalit se má celý adresář data, ne jen jeho část"
  fi
  # Kontrola musí být pozitivní. Test na vedoucí lomítko by se nikdy netrefil:
  # tar ho při balení sám odstraní a jen na to upozorní. Archiv zabalený
  # absolutní cestou proto obsahuje home/…/data/…, ne /home/…/data/….
  if tar -tf "$TAR" 2>/dev/null | grep -qvE '^(\./)?data/'; then
    chyba "v archivu jsou cesty mimo adresář data"
    poznamka "balte z adresáře ~/netlab/archiv příkazem na adresář data, ne na /home/..."
  else
    uspech "archiv má relativní cesty"
  fi
fi

require_soubor_neprazdny "$TGZ" \
  "komprimovaný archiv zaloha.tar.gz existuje" \
  "chybí ~/netlab/archiv/zaloha.tar.gz"
if [ -f "$TGZ" ]; then
  # Bez téhle kontroly projde i soubor, do kterého žák jen něco zapsal —
  # menší než .tar je pak triviálně.
  require_soubor_magie "$TGZ" "1f8b" \
    "zaloha.tar.gz je opravdu komprimovaný archiv"
  if [ "$(seznam_v_archivu "$TGZ" z | grep -c '')" -eq "$POCET_DAT" ]; then
    uspech "komprimovaný archiv obsahuje tatáž data"
  else
    chyba "komprimovaný archiv neobsahuje tatáž data jako nekomprimovaný"
  fi
fi
if [ -f "$TAR" ] && [ -f "$TGZ" ]; then
  VT=$(wc -c < "$TAR" | tr -d ' ')
  VG=$(wc -c < "$TGZ" | tr -d ' ')
  if [ "$VG" -lt "$VT" ]; then
    uspech "komprimovaný archiv je menší než nekomprimovaný"
  else
    chyba "komprimovaný archiv není menší — zkontrolujte, čím jste ho vyrobili"
  fi
fi

krok 3 "Obnovení a přehled"
require_path "$OBNOVENO/data" \
  "archiv je rozbalený v adresáři obnoveno" \
  "chybí ~/netlab/archiv/obnoveno/data — rozbalte archiv do zvoleného adresáře"
if [ -d "$OBNOVENO/data" ] && [ -f "$TGZ" ]; then
  NA_DISKU="$( (cd "$OBNOVENO" && find . -type f 2>/dev/null | sed 's|^\./||' | sort) )"
  V_ARCHIVU="$(seznam_v_archivu "$TGZ" z)"
  if [ -n "$V_ARCHIVU" ] && [ "$NA_DISKU" = "$V_ARCHIVU" ]; then
    uspech "rozbalená data odpovídají obsahu archivu"
  else
    chyba "rozbalená data neodpovídají obsahu archivu"
    poznamka "do adresáře obnoveno patří celý archiv, nic víc a nic míň"
  fi

  # Rozbalený soubor si nese čas z archivu, kdežto kopie vzniká teď. Kdo
  # data místo rozbalení zkopíroval, cvičení neudělal.
  VZOREK="$(seznam_v_archivu "$TGZ" z | head -n1)"
  if [ -n "$VZOREK" ] && [ -f "$OBNOVENO/$VZOREK" ]; then
    if tar -xzOf "$TGZ" "$VZOREK" 2>/dev/null | cmp -s - "$OBNOVENO/$VZOREK"; then
      uspech "obsah rozbalených souborů souhlasí s archivem"
    else
      chyba "obsah rozbalených souborů se od archivu liší"
    fi
    if [ "$OBNOVENO/$VZOREK" -nt "$DATA/${VZOREK#data/}" ]; then
      chyba "obnovená data nevznikla rozbalením archivu"
      poznamka "rozbalený soubor si nese čas z archivu; tyhle mají čas kopírování"
    else
      uspech "data byla opravdu rozbalena z archivu"
    fi
  fi
fi

# Hodnoty z vlastního běhu — u každého žáka jiné.
if [ -f "$TAR" ]; then
  require_zaznam "$FORMULAR" souboru "$POCET_DAT" \
    "ve formuláři je počet souborů v archivu"
  require_zaznam "$FORMULAR" velikost-tar "$(wc -c < "$TAR" | tr -d ' ')" \
    "ve formuláři je velikost nekomprimovaného archivu"
fi
if [ -f "$TGZ" ]; then
  require_zaznam "$FORMULAR" velikost-tgz "$(wc -c < "$TGZ" | tr -d ' ')" \
    "ve formuláři je velikost komprimovaného archivu"
fi
# Velká i malá písmena projdou — odpověď je slovo, ne jméno souboru.
require_zaznam_tvar "$FORMULAR" mensi '^[Tt][Gg][Zz]$' \
  "ve formuláři je, který archiv je menší" \
  "ve formuláři chybí odpověď, který archiv je menší"

vypis_souhrn
