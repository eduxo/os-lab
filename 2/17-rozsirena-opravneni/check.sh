#!/bin/bash
# 2/17 — ověření
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

SDILENE="$HOME/netlab/sdilene"
FORMULAR="$SDILENE/zaznam.txt"
PROJEKT="$SDILENE/projekt"
ODKLAD="$SDILENE/odkladiste"

SKUPINY=(vedeni sklad ucetni)
SKUPINA="${SKUPINY[$(( $(lab_vyber 3 1 181) - 1 ))]}"

krok 1 "Prostředí"
require_soubor_neprazdny "$FORMULAR" \
  "zadání a formulář jsou na místě" \
  "chybí ~/netlab/sdilene/zaznam.txt — spusťte ./start.sh"
require_group "$SKUPINA"

krok 2 "Adresář projektu"
require_owner "$PROJEKT" "$(id -un):$SKUPINA"
require_setgid "$PROJEKT"
# 2770: setgid + vlastník a skupina všechno, ostatní nic.
require_mode "$PROJEKT" 2770

# Skutečná zkouška: soubor vytvořený uvnitř musí zdědit skupinu adresáře.
# Bez setgid by dostal primární skupinu toho, kdo ho vytvořil.
if [ -d "$PROJEKT" ]; then
  ZKOUSKA="$PROJEKT/.zkouska-$$"
  if touch "$ZKOUSKA" 2>/dev/null; then
    SKUP_NOVEHO="$(stat -c %G "$ZKOUSKA" 2>/dev/null)"
    rm -f "$ZKOUSKA"
    if [ "$SKUP_NOVEHO" = "$SKUPINA" ]; then
      uspech "nový soubor v adresáři projekt dědí skupinu $SKUPINA"
    else
      chyba "nový soubor v adresáři projekt dostal skupinu ${SKUP_NOVEHO:-?}, ne $SKUPINA"
      poznamka "dědičnost skupiny zařídí jeden bit navíc v právech adresáře"
    fi
  fi
fi

krok 3 "Odkladiště"
# 1777: sticky + všichni všechno. Sticky brání mazání cizích souborů.
require_mode "$ODKLAD" 1777
STICKY="$(stat -c %a "$ODKLAD" 2>/dev/null)"
if [ "${#STICKY}" -eq 4 ] && [ "${STICKY:0:1}" = "1" ]; then
  uspech "odkladiste má nastavený sticky bit"
else
  chyba "odkladiste nemá sticky bit"
  poznamka "bez něj smaže kdokoli cizí soubor, protože smí zapisovat do adresáře"
fi

krok 4 "Doložení vlastního běhu"
require_zaznam "$FORMULAR" skupina-souboru "$SKUPINA" \
  "ve formuláři je skupina, kterou dědí nové soubory"
require_zaznam "$FORMULAR" prava-projekt "$(ls -ld "$PROJEKT" 2>/dev/null | cut -c1-10)" \
  "ve formuláři je symbolický zápis práv adresáře projekt"
require_zaznam "$FORMULAR" prava-odkladiste "$(ls -ld "$ODKLAD" 2>/dev/null | cut -c1-10)" \
  "ve formuláři je symbolický zápis práv adresáře odkladiste"

vypis_souhrn
