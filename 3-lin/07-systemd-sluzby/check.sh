#!/bin/bash
# 3/07 — ověření (běží na stanici, kontroluje kontejner)
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

LAB_KONTEJNER="sluzby-$ZAK2"

# `lxc info` uspěje i u zastaveného serveru — bez tohohle rozlišení by žák
# po ./stop.sh dostal sedm FAILů a myslel si, že o práci přišel.
STAV="$(lxc list "^${LAB_KONTEJNER}$" -c s --format csv 2>/dev/null)"
if [ -z "$STAV" ]; then
  echo; echo "  Server $LAB_KONTEJNER neexistuje. Spusťte ./start.sh"; echo; exit 1
elif [ "$STAV" != "RUNNING" ]; then
  echo; echo "  Server $LAB_KONTEJNER je zastavený — vaše práce na něm zůstala."
  echo "  Nastartujte ho a připojte se znovu:  ./start.sh"; echo; exit 1
fi

krok 1 "Unit soubor"
require_path "/etc/systemd/system/hlidac.service" "unit hlidac.service existuje" "chybí /etc/systemd/system/hlidac.service"
require_unit_valid "hlidac.service"

krok 2 "Služba běží a nastartuje po restartu"
require_service_active  "hlidac"
require_service_enabled "hlidac"

krok 3 "Běží správně"
require_service_user "hlidac" "hlidac$ZAK2"
require_port_listening "$ZAK_PORT"
require_soubor_obsahuje "/var/log/hlidac/hlidac.log" "hlidac bezi" "služba zapisuje do logu"

# měkká kontrola — nezvyšuje jmenovatel, jen pochválí nebo poradí
pouzil_diagnostiku

# Poznámka: negativní kontrolu „neběží pod rootem" nepřidáváme — je obsažená
# v require_service_user výše a jen by nafukovala jmenovatel.

vypis_souhrn
