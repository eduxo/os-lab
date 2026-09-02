#!/bin/bash
# 2/12 — ověření
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

POD="$HOME/netlab/podpisy"
DOD="$POD/dodavatel"
ODPOVEDI="$POD/odpovedi.txt"

# sha256sum je na Ubuntu; shasum je záloha pro prostředí, kde není.
otisk_souboru() {
  if command -v sha256sum >/dev/null; then sha256sum "$1" 2>/dev/null | cut -d' ' -f1
  else shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1; fi
}

# Jazykově nezávislé posouzení podpisu — gpg mluví česky nebo anglicky podle
# nastavení systému, ale --status-fd vypisuje vždy stejné značky.
stav_podpisu() {  # stav_podpisu podpis soubor  → GOODSIG | BADSIG | prázdno
  gpg --status-fd 1 --verify "$1" "$2" 2>/dev/null | grep -oE 'GOODSIG|BADSIG' | head -1
}

krok 1 "Prostředí"
require_path "$DOD" \
  "stažené instalačky a zprávy jsou na místě" \
  "chybí ~/netlab/podpisy/dodavatel — spusťte ./start.sh"
require_gpg_klic "novak$ZAK2@netlab.test" \
  "máte vlastní klíč GPG (novak$ZAK2@netlab.test)"

krok 2 "Kontrolní součty"
OA="$(otisk_souboru "$DOD/instalacka-a.bin")"
OB="$(otisk_souboru "$DOD/instalacka-b.bin")"
PUBLIKOVANY="$(cut -d' ' -f1 "$DOD/SHA256SUMS.txt" 2>/dev/null)"
SPRAVNA="$( [ "$OA" = "$PUBLIKOVANY" ] && echo a || echo b )"

require_zaznam "$ODPOVEDI" otisk-a "$OA" "ve formuláři je otisk instalačky a"
require_zaznam "$ODPOVEDI" otisk-b "$OB" "ve formuláři je otisk instalačky b"
require_zaznam "$ODPOVEDI" dobra "$SPRAVNA" \
  "určili jste, která instalačka sedí s kontrolním součtem"

# Poctivá kopie pod jménem, na které zní kontrolní součet — teprve tak projde
# `sha256sum -c`, což je způsob, jakým se to dělá doopravdy.
if [ -f "$DOD/instalacka.bin" ]; then
  if [ "$(otisk_souboru "$DOD/instalacka.bin")" = "$PUBLIKOVANY" ]; then
    uspech "instalacka.bin je ta poctivá kopie a sedí s SHA256SUMS.txt"
  else
    chyba "instalacka.bin existuje, ale její otisk nesedí s SHA256SUMS.txt"
    poznamka "zkopírovali jste tu změněnou"
  fi
else
  chyba "chybí instalacka.bin — zkopírujte tam poctivou instalačku pod tímhle jménem"
fi

krok 3 "Podpisy"
require_gpg_klic "dodavatel@netlab.test" \
  "v klíčence máte veřejný klíč dodavatele"

# Nezměněná zpráva musí projít, změněná ne. Kontroluje se skutečný stav,
# ne to, co si žák myslí.
S1="$(stav_podpisu "$DOD/oznameni.txt.asc" "$DOD/oznameni.txt")"
S2="$(stav_podpisu "$DOD/oznameni-2.txt.asc" "$DOD/oznameni-2.txt")"
if [ "$S1" = "GOODSIG" ]; then
  uspech "podpis u oznameni.txt jde ověřit (klíč dodavatele je naimportovaný)"
else
  chyba "podpis u oznameni.txt zatím ověřit nejde"
  poznamka "nejdřív musíte naimportovat veřejný klíč dodavatele"
fi
# Bez naimportovaného klíče vrátí stav_podpisu prázdno — a to není totéž
# jako „neplatný podpis". Uznat odpověď v takové chvíli by znamenalo, že
# žák projde, aniž by ověření jednou spustil.
if [ -z "$S2" ]; then
  chyba "podpis u oznameni-2.txt zatím ověřit nejde"
  poznamka "nejdřív naimportujte veřejný klíč dodavatele, teprve pak posuzujte"
else
  OCEKAVANO="$( [ "$S2" = "GOODSIG" ] && echo platny || echo neplatny )"
  require_zaznam "$ODPOVEDI" podpis-2 "$OCEKAVANO" \
    "posoudili jste podpis u oznameni-2.txt"
fi

# Vlastní podpis: musí být platný a musí být od žákova klíče, ne od dodavatele.
MUJ="$POD/moje-hlaseni.txt"
if [ -f "$MUJ.asc" ]; then
  VYSTUP="$(gpg --status-fd 1 --verify "$MUJ.asc" "$MUJ" 2>/dev/null)"
  if printf '%s' "$VYSTUP" | grep -q 'GOODSIG' && \
     printf '%s' "$VYSTUP" | grep -q "novak$ZAK2@netlab.test"; then
    uspech "moje-hlaseni.txt je podepsané vaším klíčem a podpis sedí"
  elif printf '%s' "$VYSTUP" | grep -q 'GOODSIG'; then
    chyba "moje-hlaseni.txt je podepsané, ale ne vaším klíčem"
  else
    chyba "podpis u moje-hlaseni.txt neplatí — změnili jste soubor po podepsání?"
  fi
else
  chyba "chybí ~/netlab/podpisy/moje-hlaseni.txt.asc — soubor jste nepodepsali"
fi

vypis_souhrn
