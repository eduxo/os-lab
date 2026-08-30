#!/bin/bash
# 2/02 — ověření
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

HYG="$HOME/dokumentace/hygiena"
POSTA="$HYG/posta"
ODPOVEDI="$HYG/verdikty.txt"
TREZOR="$HYG/hesla-$ZAK2.kdbx"

krok 1 "Prostředí"
require_path "$POSTA" \
  "služební pošta je připravená v ~/dokumentace/hygiena/posta" \
  "chybí ~/dokumentace/hygiena/posta — spusťte ./start.sh"
require_pocet_souboru "$POSTA" '*.txt' 3 "ve schránce jsou tři zprávy"
require_prikaz keepassxc "správce hesel KeePassXC je na stanici k dispozici"
require_prikaz gpg "nástroj gpg je na stanici k dispozici"

krok 2 "Správce hesel a jednorázové kódy"
# Databáze je zašifrovaná, takže se do ní nedíváme. Ověřujeme, že je to
# opravdu soubor KeePassXC, a ne prázdný soubor se správným jménem.
require_soubor_magie "$TREZOR" 03d9a29a \
  "databáze hesla-$ZAK2.kdbx existuje a je to databáze KeePassXC"
require_zaznam_tvar "$ODPOVEDI" zaznamu '^([5-9]|[1-9][0-9]+)$' \
  "v databázi máte aspoň pět záznamů"
require_zaznam_tvar "$ODPOVEDI" mfa-kod '^[0-9]{6}$' \
  "zapsali jste jednorázový kód (šest číslic)"
require_zaznam_tvar "$ODPOVEDI" mfa-cas '^([01]?[0-9]|2[0-3]):[0-5][0-9]$' \
  "zapsali jste čas, kdy kód platil"

krok 3 "Vlastní klíč GPG"
require_gpg_klic "novak$ZAK2@netlab.test" \
  "v klíčence máte klíč pro novak$ZAK2@netlab.test"

krok 4 "Rozbor služební pošty"
if [ -f "$HYG/.zadani" ]; then
  while read -r POZICE OTISK; do
    [ -n "$POZICE" ] || continue
    require_zaznam_hash "$ODPOVEDI" "posta-$POZICE" "$OTISK" \
      "zpráva $POZICE je posouzená správně"
  done < "$HYG/.zadani"
else
  chyba "chybí zadání pošty — spusťte ./start.sh"
fi
require_min_radku "$HYG/rozbor.txt" 6 \
  "v rozbor.txt máte aspoň šest řádků odůvodnění"

vypis_souhrn
