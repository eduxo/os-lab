#!/bin/bash
# 2/20 — ověření
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

ZAL="$HOME/netlab/zalohy"
DATA="$ZAL/data"
CENIK="$DATA/cenik.txt"
OBNOVENO="$ZAL/obnoveno"
FORMULAR="$ZAL/obnova.txt"
TIKET="$ZAL/tiket.txt"
OTISKY="$ZAL/.otisky-zaloh"

# Musí souhlasit se start.sh — stejné vzorce, stejná sůl.
KOD="$(lab_kod SFP 20)"
CENA=$(( 1200 + ZAK * 13 ))
KTERA=$(lab_vyber 3 1 220)
DNY=(2026-12-05 2026-12-08 2026-12-11)
SPRAVNA="zaloha-${DNY[KTERA-1]}.tar.gz"
DNESNI="SKU-1010"

krok 1 "Prostředí"
require_soubor_neprazdny "$CENIK" \
  "dnešní ceník je na místě" \
  "chybí ~/netlab/zalohy/data/cenik.txt — spusťte ./start.sh"
require_soubor_neprazdny "$TIKET" \
  "tiket je na místě" \
  "chybí ~/netlab/zalohy/tiket.txt — spusťte ./start.sh, doplní ho"
# Zálohy se ověřují jmenovitě, ne počtem: žák si v Rozšíření vyrábí vlastní
# archivy a počítání by ho za to trestalo.
CHYBI=""
for d in "${DNY[@]}"; do
  [ -f "$ZAL/zaloha-$d.tar.gz" ] || CHYBI="$CHYBI zaloha-$d.tar.gz"
done
if [ -z "$CHYBI" ]; then uspech "všechny tři zálohy skladu jsou na místě"
else chyba "chybí záloha:$CHYBI — obnovíte ji přes ./reset.sh"; fi
require_soubor_neprazdny "$FORMULAR" \
  "formulář je na místě" \
  "chybí ~/netlab/zalohy/obnova.txt — spusťte ./start.sh, doplní ho"

krok 2 "Záloha před zásahem a obnovený soubor"
# Než se sáhne do ostrých dat, dělá se záloha. Že vznikla opravdu PŘED
# zásahem, se pozná podle toho, že v ní doplněná položka ještě není.
PRED="$(ls -1 "$ZAL"/pred-zasahem-*.tar.gz 2>/dev/null | head -n1)"
if [ -z "$PRED" ]; then
  chyba "chybí záloha dnešního stavu (pred-zasahem-RRRR-MM-DD.tar.gz)"
  poznamka "datum do jména nepište ručně — nechte si ho doplnit příkazem date"
elif ! printf '%s' "$(basename "$PRED")" | grep -qE '^pred-zasahem-[0-9]{4}-[0-9]{2}-[0-9]{2}\.tar\.gz$'; then
  chyba "jméno zálohy dnešního stavu neodpovídá tvaru pred-zasahem-RRRR-MM-DD.tar.gz"
else
  require_soubor_magie "$PRED" "1f8b" \
    "záloha dnešního stavu je komprimovaný archiv"
  OBSAH_PRED="$(tar -xzOf "$PRED" data/cenik.txt 2>/dev/null)"
  if [ -z "$OBSAH_PRED" ]; then
    chyba "v záloze dnešního stavu není ceník"
    poznamka "balí se celý adresář data, ne jednotlivé soubory"
  elif printf '%s' "$OBSAH_PRED" | grep -q "^$KOD;"; then
    chyba "záloha dnešního stavu vznikla až po zásahu do ceníku"
    poznamka "záloha se dělá dřív, než se do dat sáhne — tahle už opravu obsahuje"
  else
    uspech "záloha dnešního stavu vznikla před zásahem do ceníku"
  fi
fi

# Zálohy skladu se při obnově nemění. Kdo je přepsal, obnovoval z něčeho
# jiného, než dostal — a v ostrém provozu by přišel o jedinou kopii dat.
if [ ! -f "$OTISKY" ]; then
  chyba "chybí kontrolní otisky záloh — obnovíte je přes ./reset.sh"
else
  ZMENENE=""
  while read -r o jmeno; do
    [ -n "${jmeno:-}" ] || continue
    if [ ! -f "$ZAL/$jmeno" ]; then ZMENENE="$ZMENENE $jmeno(chybí)"
    elif [ "$(_hash < "$ZAL/$jmeno")" != "$o" ]; then ZMENENE="$ZMENENE $jmeno"; fi
  done < "$OTISKY"
  if [ -z "$ZMENENE" ]; then
    uspech "zálohy skladu zůstaly nedotčené"
  else
    chyba "záloha skladu se změnila:$ZMENENE"
    poznamka "ze zálohy se jen čte — obnovujte stranou, do adresáře obnoveno"
  fi
fi

require_path "$OBNOVENO" \
  "adresář obnoveno existuje" \
  "chybí ~/netlab/zalohy/obnoveno — rozbalte obnovený soubor stranou"
if [ -d "$OBNOVENO" ]; then
  POCET=$(find "$OBNOVENO" -type f 2>/dev/null | grep -c '')
  if [ "$POCET" -eq 1 ]; then
    uspech "v adresáři obnoveno je jediný soubor"
  elif [ "$POCET" -eq 0 ]; then
    chyba "adresář obnoveno je prázdný"
  else
    chyba "v adresáři obnoveno není jediný soubor (napočítáno: $POCET)"
    poznamka "obnovuje se jeden soubor, ne celá záloha — jméno souboru se uvádí za jménem archivu"
  fi

  OBN="$(find "$OBNOVENO" -type f -name 'cenik.txt' 2>/dev/null | head -n1)"
  if [ -n "$OBN" ]; then
    if grep -q "^$KOD;" "$OBN"; then
      uspech "obnovený ceník obsahuje hledanou položku"
    else
      chyba "v obnoveném ceníku hledaná položka není"
      poznamka "položka je jen v jedné ze tří záloh — prohlédněte si všechny tři"
    fi
    # Bajt po bajtu proti archivu. Bez toho projde i ceník, který si žák
    # napsal ručně — kód i cenu si dopočítá ze start.sh, repozitář je veřejný.
    if tar -xzOf "$ZAL/$SPRAVNA" data/cenik.txt 2>/dev/null | cmp -s - "$OBN"; then
      uspech "obnovený soubor je přesná kopie ceníku ze zálohy"
    else
      chyba "obnovený soubor se od ceníku v žádné záloze liší"
      poznamka "ceník se ze zálohy rozbaluje, neopisuje ani neupravuje"
    fi
  else
    chyba "v adresáři obnoveno není soubor cenik.txt"
  fi
fi

krok 3 "Nasazení a formulář"
if [ -f "$CENIK" ]; then
  if grep -q "^$KOD;Redukce SFP na RJ45;$CENA\$" "$CENIK"; then
    uspech "položka je zpátky v dnešním ceníku i se správnou cenou"
  else
    chyba "v dnešním ceníku hledaná položka chybí, nebo má jinou cenu"
  fi
  if grep -q "^$DNESNI;" "$CENIK"; then
    uspech "dnešní ceník si zachoval položky přidané dnes"
  else
    chyba "z dnešního ceníku zmizely položky přidané dnes"
    poznamka "starý ceník se přes dnešní nekopíruje — doplňuje se z něj jen chybějící řádek"
  fi
fi

# Hodnoty z vlastního běhu. Počet řádků se čte ze samotné zálohy, takže
# se nemůže rozejít s tím, co start.sh vyrobil.
RADKU="$(tar -xzOf "$ZAL/$SPRAVNA" data/cenik.txt 2>/dev/null | grep -c '')"
require_zaznam "$FORMULAR" zaloha "$SPRAVNA" \
  "ve formuláři je záloha, ve které položka byla"
require_zaznam "$FORMULAR" cena "$CENA" \
  "ve formuláři je cena položky ze zálohy"
if [ "${RADKU:-0}" -gt 0 ]; then
  require_zaznam "$FORMULAR" radku "$RADKU" \
    "ve formuláři je počet řádků ceníku v té záloze"
fi

vypis_souhrn
