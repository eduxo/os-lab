#!/bin/bash
# 2/03 — ověření
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

BAZE="$HOME/nakoleni"
KOD="NAK-$(( (ZAK * 7919) % 9000 + 1000 ))"

# Pozn.: test na ~/.bash_history tady nedává smysl — bash ji zapisuje až při
# ukončení shellu, takže by kontrola žáka neprávem odmítla. Orientaci ověřuje
# až část 3, kde žák dokládá cesty a počty, které bez procházení nezjistí.
krok 1 "Prostředí"
require_path "$BAZE" "pracovní adresář ~/nakoleni existuje"

krok 2 "Nalezení předávacího protokolu"
if [ -f "$BAZE/odpoved.txt" ] && grep -qF "$KOD" "$BAZE/odpoved.txt"; then
  uspech "našli jste přístupový kód a zapsali ho do odpoved.txt"
else
  chyba "v ~/nakoleni/odpoved.txt zatím není správný kód"
  poznamka "kód je v jednom ze souborů uvnitř ~/nakoleni — projděte adresáře"
fi

krok 3 "Vlastní složka a poznámky"
require_path "$BAZE/prevzato" "vytvořili jste adresář ~/nakoleni/prevzato"

POZN="$BAZE/prevzato/poznamky.txt"
if [ -f "$POZN" ] && [ -s "$POZN" ]; then
  uspech "poznamky.txt existuje a není prázdný"
else
  chyba "chybí ~/nakoleni/prevzato/poznamky.txt s vašimi odpověďmi"
fi

# Tohle je jádro hodnocení: cestu a počty nezjistí nikdo, kdo strukturu
# neprošel — ani `grep -r`, ani rada zvenčí.
if [ -f "$POZN" ] && grep -qE 'archiv/2026' "$POZN"; then
  uspech "uvedli jste cestu k předávacímu protokolu"
else
  chyba "v poznámkách chybí plná cesta k protokolu (otázka 1)"
fi
if [ -f "$POZN" ] && grep -qE '(^|[^0-9])2([^0-9]|$)' "$POZN" && grep -qE '(^|[^0-9])1([^0-9]|$)' "$POZN"; then
  uspech "uvedli jste počty souborů v odděleních"
else
  chyba "v poznámkách chybí počty souborů ve sklad a ucetni (otázka 2)"
fi

vypis_souhrn
