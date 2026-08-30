#!/bin/bash
# 2/01 — ověření
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

DOKU="$HOME/dokumentace"
PREHLED="$DOKU/stanice.txt"
JMENO="stanice-$ZAK2"

krok 1 "Prostředí"
require_path "$HOME/os-lab/.git" \
  "repozitář os-lab je naklonovaný v ~/os-lab" \
  "chybí ~/os-lab — naklonujte repozitář podle zadání"
require_path "$DOKU" \
  "adresář ~/dokumentace existuje" \
  "chybí ~/dokumentace — spusťte ./start.sh"
require_prikaz git "nástroj git je nainstalovaný"

krok 2 "Jméno stanice"
require_hostname "$JMENO"
require_soubor_obsahuje /etc/hosts "$JMENO" \
  "nové jméno je i v /etc/hosts" \
  "v /etc/hosts chybí $JMENO — sudo bude při každém spuštění hlásit chybu"

krok 3 "Přehled stanice"
require_soubor_neprazdny "$PREHLED" \
  "formulář ~/dokumentace/stanice.txt existuje" \
  "chybí ~/dokumentace/stanice.txt — spusťte ./start.sh"

# Hodnoty z vlastního běhu: hostname a verzi jádra umíme přečíst přímo,
# takže se porovnávají doslova. Paměť a disk se liší podle nastavení VM
# a locale (5,7Gi vs. 5.7Gi), proto se u nich kontroluje jen tvar.
require_zaznam "$PREHLED" hostname "$JMENO" \
  "v přehledu je správné jméno stanice"
require_zaznam "$PREHLED" jadro "$(uname -r)" \
  "v přehledu je verze jádra této stanice"
# Jednotka se liší podle obrazu i podle locale (5,7Gi i 5.7Gi), proto tvar
# místo hodnoty. Mi a T jsou tu kvůli odchylnému obrazu — u předepsaných
# 6 GB / ~49 G se neuplatní, ale FAIL kvůli jednotce by nikdo nerozklíčoval.
require_zaznam_tvar "$PREHLED" pamet '^[0-9]+([.,][0-9]+)? ?(Mi|MiB|M|MB|Gi|GiB|G|GB|Ti|TiB|T|TB)$' \
  "v přehledu je velikost paměti i s jednotkou (třeba 5,7Gi)"
require_zaznam_tvar "$PREHLED" disk '^[0-9]+([.,][0-9]+)? ?(Mi|MiB|M|MB|Gi|GiB|G|GB|Ti|TiB|T|TB)$' \
  "v přehledu je velikost systémového disku i s jednotkou (třeba 49G)"
require_zaznam "$PREHLED" snapshot "cisty-system-$ZAK2" \
  "v přehledu je jméno snímku cisty-system-$ZAK2"

vypis_souhrn
