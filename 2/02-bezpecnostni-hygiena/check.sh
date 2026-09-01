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
# Rovnost počtu by potrestala i žáka, který si do schránky přidal vlastní
# poznámku. Kontrolujeme proto ty tři konkrétní zprávy.
for Z in 1 2 3; do
  require_path "$POSTA/$Z.txt" "zpráva $Z je ve schránce" "chybí zpráva $Z — spusťte ./start.sh"
done
require_prikaz keepassxc "správce hesel KeePassXC je na stanici k dispozici"
require_prikaz gpg "nástroj gpg je na stanici k dispozici"

krok 2 "Správce hesel a jednorázové kódy"
# Databáze je zašifrovaná, takže se do ní nedíváme. Ověřujeme, že je to
# opravdu soubor KeePassXC, a ne prázdný soubor se správným jménem.
require_soubor_magie "$TREZOR" 03d9a29a \
  "databáze hesla-$ZAK2.kdbx existuje a je to databáze KeePassXC"
# Samotnou hlavičku KDBX lze napsat ručně osmi bajty. Prázdná databáze má
# přes 1 kB, s pěti záznamy víc — práh je nízko schválně, hlídá podvrh,
# ne počet záznamů.
require_soubor_min_velikost "$TREZOR" 1000 \
  "databáze má obsah, ne jen hlavičku"
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
# Správnost verdiktu tady stroj neposuzuje — viz komentář ve start.sh.
# Kontroluje se, že je odpověď zapsaná v dohodnutém tvaru, aby se s ní dalo
# při obhajobě pracovat: buď `ok`, nebo `phishing` a doména odesílatele.
for Z in 1 2 3; do
  require_zaznam_tvar "$ODPOVEDI" "posta-$Z" \
    '^(ok|OK|[Pp]hishing +[A-Za-z0-9.-]+\.test)$' \
    "zpráva $Z má zapsaný verdikt v dohodnutém tvaru"
done
require_min_radku "$HYG/rozbor.txt" 6 \
  "v rozbor.txt máte aspoň šest řádků odůvodnění" \
  "v rozbor.txt zatím není šest řádků odůvodnění"
poznamka "verdikty si projde vyučující — samotný tvar odpovědi nic neříká o tom,"
poznamka "jestli je posouzení správné"

vypis_souhrn
