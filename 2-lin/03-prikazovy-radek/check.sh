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

# Jádro hodnocení: cestu ani počty nezjistí nikdo, kdo strukturu neprošel.
# Dřív se tu hledaly podřetězce, což bylo příliš měkké — poznámky, které
# neodpovídaly na nic, procházely na plný počet. Teď se čte hodnota za
# klíčem a počty se berou ze skutečného stromu, ne z pevného čísla.
require_zaznam_tvar "$POZN" protokol 'archiv/2026/predavaci-protokol\.txt$' \
  "uvedli jste cestu k předávacímu protokolu"

POCET_SKLAD=$(ls -1 "$BAZE/sklad" 2>/dev/null | grep -c '')
POCET_UCETNI=$(ls -1 "$BAZE/ucetni" 2>/dev/null | grep -c '')
require_zaznam "$POZN" sklad  "$POCET_SKLAD"  "uvedli jste počet souborů ve skladu"
require_zaznam "$POZN" ucetni "$POCET_UCETNI" "uvedli jste počet souborů v účetní"

# Třetí otázka: který adresář zůstal prázdný. Zadání ji vyžaduje, kontrola
# ji dřív vůbec nesledovala.
PRAZDNY=$(cd "$BAZE" 2>/dev/null && for d in */; do
            [ -z "$(ls -A "$d" 2>/dev/null)" ] && printf '%s\n' "${d%/}"; done | head -1)
require_zaznam "$POZN" prazdny "$PRAZDNY" "uvedli jste, který adresář je prázdný"

vypis_souhrn
