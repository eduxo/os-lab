#!/bin/bash
# 2/03 — ověření
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

BAZE="$HOME/netlab"
KOD="$(lab_kod NET)"

# Pozn.: test na ~/.bash_history tady nedává smysl — bash ji zapisuje až při
# ukončení shellu, takže by kontrola žáka neprávem odmítla. Orientaci ověřuje
# až část 3, kde žák dokládá cesty a počty, které bez procházení nezjistí.
krok 1 "Prostředí"
require_path "$BAZE" "pracovní adresář ~/netlab existuje" "chybí ~/netlab — spusťte ./start.sh"

krok 2 "Nalezení předávacího protokolu"
if [ -f "$BAZE/odpoved.txt" ] && grep -qF "$KOD" "$BAZE/odpoved.txt"; then
  uspech "našli jste přístupový kód a zapsali ho do odpoved.txt"
else
  chyba "v ~/netlab/odpoved.txt zatím není správný kód"
  poznamka "kód je v jednom ze souborů uvnitř ~/netlab — projděte adresáře"
fi

krok 3 "Vlastní složka a poznámky"
require_path "$BAZE/prevzato" "vytvořili jste adresář ~/netlab/prevzato" "chybí adresář ~/netlab/prevzato"

POZN="$BAZE/prevzato/poznamky.txt"
if [ -f "$POZN" ] && [ -s "$POZN" ]; then
  uspech "poznamky.txt existuje a není prázdný"
else
  chyba "chybí ~/netlab/prevzato/poznamky.txt s vašimi odpověďmi"
fi

# Tohle je jádro hodnocení: cestu a počty nezjistí nikdo, kdo strukturu
# neprošel — ani `grep -r`, ani rada zvenčí.
if [ -f "$POZN" ] && grep -qE 'archiv/2026' "$POZN"; then
  uspech "uvedli jste cestu k předávacímu protokolu"
else
  chyba "v poznámkách chybí plná cesta k protokolu (otázka 1)"
fi
# Kotvíme na tvar „sklad: 2" — pouhá číslovaná odpověď (1. 2. 3.) neprojde.
if [ -f "$POZN" ] && grep -qiE 'sklad[^0-9]{0,4}2' "$POZN" && grep -qiE '(ucetni|účetní)[^0-9]{0,4}1' "$POZN"; then
  uspech "uvedli jste počty souborů v odděleních"
else
  chyba "v poznámkách chybí počty souborů (otázka 2) — pište ve tvaru 'sklad: 2'"
fi

vypis_souhrn
