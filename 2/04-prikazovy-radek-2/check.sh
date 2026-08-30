#!/bin/bash
# 2/04 — ověření
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

PRIJEM="$HOME/netlab/prijem"
SOUPIS="$PRIJEM/soupis.txt"
TRIDENI="$PRIJEM/trideni"

krok 1 "Prostředí"
require_path "$PRIJEM" \
  "adresář ~/netlab/prijem existuje" \
  "chybí ~/netlab/prijem — spusťte ./start.sh"
require_soubor_neprazdny "$SOUPIS" \
  "formulář soupis.txt je na místě" \
  "chybí ~/netlab/prijem/soupis.txt — spusťte ./start.sh"

krok 2 "Soupis přijaté pošty"
# Správné odpovědi se počítají ze skutečného obsahu adresáře, ne z tabulky.
# Kdyby si žák do adresáře něco přidal, kontrola se přizpůsobí — hodnotí se
# to, co v adresáři opravdu je.
if [ -d "$PRIJEM" ]; then
  POCET_PDF=$(ls -1d "$PRIJEM"/*.pdf 2>/dev/null | grep -c '')
  CTYRI=$(cd "$PRIJEM" && ls -1d ???? 2>/dev/null | head -1)
  NEJVETSI=$(cd "$PRIJEM" && ls -S1 2>/dev/null | while read -r f; do
               [ -f "$f" ] && printf '%s\n' "$f"; done | head -1)

  require_zaznam "$SOUPIS" pdf "$POCET_PDF" \
    "v soupisu je správný počet souborů .pdf"
  require_zaznam "$SOUPIS" ctyri "$CTYRI" \
    "v soupisu je soubor se čtyřznakovým jménem"
  require_zaznam "$SOUPIS" nejvetsi "$NEJVETSI" \
    "v soupisu je největší soubor adresáře"
  require_zaznam_tvar "$SOUPIS" prepinac '^(-S|--sort=size)$' \
    "v soupisu je přepínač, kterým se řadí podle velikosti"
fi

# Negativní kontrola: počty se čtou z adresáře, takže „zjednodušit si to"
# smazáním souborů by jinak prošlo. Tyhle soubory má každý žák stejné.
CHYBI=""
for f in smlouva-alfa.txt smlouva-beta.txt poznamka.txt sklad.csv prehled.csv; do
  [ -f "$PRIJEM/$f" ] || CHYBI="$CHYBI $f"
done
if [ -z "$CHYBI" ]; then
  uspech "adresář je nedotčený — nic z původní pošty nechybí"
else
  chyba "z adresáře zmizely soubory:$CHYBI"
  poznamka "počty se čtou ze skutečného obsahu; obnovte ho přes ./reset.sh"
fi

krok 3 "Třídění a historie"
require_path "$TRIDENI/faktury" \
  "podadresář trideni/faktury existuje" \
  "chybí trideni/faktury"
require_path "$TRIDENI/smlouvy" \
  "podadresář trideni/smlouvy existuje" \
  "chybí trideni/smlouvy"
require_path "$TRIDENI/ostatni" \
  "podadresář trideni/ostatni existuje" \
  "chybí trideni/ostatni"

# Počet štítků je číslo žáka. Sousedovo řešení tedy neprojde, i kdyby
# se zkopírovalo celé.
require_pocet_souboru "$TRIDENI" 'stitek-*.txt' "$ZAK" \
  "štítků je přesně $ZAK, tedy vaše číslo z výkazu"
require_path "$TRIDENI/stitek-$ZAK.txt" \
  "poslední štítek se jmenuje stitek-$ZAK.txt" \
  "chybí stitek-$ZAK.txt — poslední štítek má nést vaše číslo"

# Práh je 20, ne 30: shell si historii minulých relací pamatuje, ale žák,
# který terminál během cvičení zavřel, může mít v souboru jen dnešek.
require_min_radku "$PRIJEM/historie.txt" 20 \
  "historie.txt zachycuje aspoň 20 příkazů z vaší práce"
require_soubor_obsahuje "$PRIJEM/historie.txt" 'ls.*\*' \
  "v historii je vidět práce s globem" \
  "v historii není žádné ls s hvězdičkou — soubory jste vypisovali jinak"
require_soubor_obsahuje "$PRIJEM/historie.txt" '(man |--help)' \
  "v historii je vidět, že jste sáhli po nápovědě" \
  "v historii není man ani --help — přepínač jste nikde nehledali"

vypis_souhrn
